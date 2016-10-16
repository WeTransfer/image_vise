class ImageVise::RenderEngine
  require_relative 'image_request'
  require_relative 'file_response'
  class UnsupportedInputFormat < StandardError; end
  class EmptyRender < StandardError; end

  # Codes that have to be sent through to the requester
  PASSTHROUGH_STATUS_CODES = [404, 403, 503, 504, 500]
  
  DEFAULT_HEADERS = {
    'Allow' => "GET"
  }.freeze
  
  # To prevent some string allocations
  JSON_ERROR_HEADERS = DEFAULT_HEADERS.merge({
    'Content-Type' => 'application/json',
    'Cache-Control' => 'private, max-age=0, no-cache'
  }).freeze
  
  # How long is a render (the ImageMagick/write part) is allowed to
  # take before we kill it
  RENDER_TIMEOUT_SECONDS = 10
  
  # Which input files we permit (based on extensions stored in MagicBytes)
  PERMITTED_EXTENSIONS = %w( gif png jpg )
  
  # How long should we wait when fetching the image from the external host
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 4
  
  # The default file type for images with alpha
  PNG_FILE_TYPE = Class.new do
    def self.mime; 'image/png'; end
    def self.ext; 'png'; end
  end
  
  # Fetch the given URL into a Tempfile and return the File object
  def fetch_url_into_tempfile(source_image_uri)
    parsed = URI.parse(source_image_uri)
    if parsed.scheme == 'file'
      copy_path_into_tempfile(parsed.path)
    else
      fetch_url(source_image_uri)
    end
  end
  
  def bail(status, *errors_array)
    h = JSON_ERROR_HEADERS.dup # Needed because some upstream middleware migh be modifying headers
    response = [status.to_i, h, [JSON.pretty_generate({errors: errors_array})]]
    throw :__bail, response
  end
  
  # The main entry point URL, at the index so that the Sinatra app can be used
  # in-place of a Rails controller (as opposed to having to mount it at the root
  # of the Rails app or having all the URLs refer to a subpath)
  def call(env)
    catch(:__bail) { handle_request(env) }
  end
  
  def handle_request(env)
    setup_error_handling(env)
    render_destination_file = binary_tempfile
    
    # Assume that if _any_ ETag is given the image is being requested anew as a refetch,
    # and the client already has it. Just respond with a 304.
    return [304, DEFAULT_HEADERS.dup, []] if env['HTTP_IF_NONE_MATCH']

    req = Rack::Request.new(env)
    bail(405, 'Only GET supported') unless req.get?

    # Validate the inputs
    image_request = ImageVise::ImageRequest.to_request(qs_params: req.params, **image_request_options)

    # Recover the source image URL and the pipeline instructions (all the image ops)
    source_image_uri, pipeline = image_request.src_url, image_request.pipeline
    raise 'Image pipeline has no operators' if pipeline.empty?

    # Compute an ETag which describes this image transform + image source location.
    # Assume the image URL contents does _never_ change.
    etag = image_request.cache_etag
    
    # Download the original into a Tempfile
    source_file = fetch_url_into_tempfile(source_image_uri)
    
    # Make sure we do not try to process something...questionable
    source_file_type = detect_file_type(source_file)
    
    # Perform the processing
    if enable_forking?
      require 'exceptional_fork'
      ExceptionalFork.fork_and_wait { apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path) }
    else
      apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path)
    end
    
    # Catch this one early
    raise EmptyRender, "The rendered image was empty" if render_destination_file.size.zero?

    render_destination_file.rewind
    render_file_type = detect_file_type(render_destination_file)

    response_headers = DEFAULT_HEADERS.merge({
      'Content-Type' => render_file_type.mime,
      'Content-Length' => '%d' % render_destination_file.size,
      'Cache-Control' => 'public',
      'ETag' => etag
    })

    # Wrap the body Tempfile with a self-closing response.
    # Once the response is read in full, the tempfile is going to be closed and unlinked.
    [200, response_headers, ImageVise::FileResponse.new(render_destination_file)]
  rescue *permanent_failures => e
    handle_request_error(e)
    raise_exception_or_error_response(e, 422)
  rescue Exception => e
    handle_generic_error(e)
    raise_exception_or_error_response(e, 500)
  ensure
    close_and_unlink(source_file)
  end
  
  def raise_exception_or_error_response(exception, status_code)
    if raise_exceptions? 
      raise exception
    else
      bail status_code, exception.message
    end
  end
  
  def close_and_unlink(f)
    return unless f
    f.close unless f.closed?
    f.unlink
  end
  
  def binary_tempfile
    Tempfile.new('imagevise-tmp').tap{|f| f.binmode }
  end
  
  def detect_file_type(tempfile)
    tempfile.rewind
    
    file_info = MagicBytes.read_and_detect(tempfile)
    return file_info if PERMITTED_EXTENSIONS.include?(file_info.ext)
    raise UnsupportedInputFormat.new("Unsupported/unknown input file format .%s" %
       file_info.ext)
  end
  
  # Lists exceptions that should lead to the request being flagged
  # as invalid (and not 5xx). Decent clients should _not_ retry those requests.
  def permanent_failures
    [
      Magick::ImageMagickError,
      UnsupportedInputFormat,
      ImageVise::ImageRequest::InvalidRequest
    ]
  end
  
  # Is meant to be overridden by subclasses,
  # will be called at the start of each reauest
  def setup_error_handling(rack_env)
  end

  # Is meant to be overridden by subclasses,
  # will be called when a request fails due to a malformed query string,
  # unrecognized signature or other client-induced problems
  def handle_request_error(err)
  end

  # Is meant to be overridden by subclasses,
  # will be called when a request fails due to an error on the server
  # (like an unexpected error in an image operator)
  def handle_generic_error(err)
  end
  
  # Tells whether the engine must raise the exceptions further up the Rack stack,
  # or they should be suppressed and a JSON response must be returned.
  def raise_exceptions?
    false
  end
  
  def enable_forking?
    ENV['IMAGE_VISE_ENABLE_FORK'] == 'yes'
  end
  
  def apply_pipeline(source_file_path, pipeline, source_file_type, render_to_path)
    render_file_type = source_file_type
    magick_image = Magick::Image.read(source_file_path)[0]
    pipeline.apply!(magick_image)
    
    # If processing the image has created an alpha channel, use PNG always.
    # Otherwise, keep the original format for as far as the supported formats list goes.
    render_file_type = PNG_FILE_TYPE if magick_image.alpha?
    
    magick_image.format = render_file_type.ext
    magick_image.write(render_to_path)
  ensure
    ImageVise.destroy(magick_image)
  end

  def image_request_options
    {
      secrets: ImageVise.secret_keys,
      permitted_source_hosts: ImageVise.allowed_hosts,
      allowed_filesystem_patterns: ImageVise.allowed_filesystem_sources,
    }
  end

  def fetch_url(source_image_uri)
    tf = binary_tempfile
    s = Patron::Session.new
    s.automatic_content_encoding = true
    s.timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    s.connect_timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    response = s.get_file(source_image_uri, tf.path)
    if PASSTHROUGH_STATUS_CODES.include?(response.status)
      tf.close; tf.unlink;
      bail response.status, "Unfortunate upstream response: #{response.status}" 
    end
    tf
  rescue Exception => e
    tf.close; tf.unlink;
    raise e
  end

  def copy_path_into_tempfile(path_on_filesystem)
    tf = binary_tempfile
    File.open(path_on_filesystem, 'rb') do |f|
      IO.copy_stream(f, tf)
    end
    tf.rewind; tf
  rescue Errno::ENOENT
    bail 404, "Image file not found" 
  rescue Exception => e
    tf.close; tf.unlink;
    raise e
  end

end
