class ImageVise::RenderEngine
  class UnsupportedInputFormat < StandardError; end
  class EmptyRender < StandardError; end

  DEFAULT_HEADERS = {
    'Allow' => "GET"
  }.freeze
  
  # To prevent some string allocations
  JSON_ERROR_HEADERS = DEFAULT_HEADERS.merge({
    'Content-Type' => 'application/json',
    'Cache-Control' => 'private, max-age=0, no-cache'
  }).freeze
  
  # "public" of course. Add max-age so that there is _some_
  # revalidation after a time (otherwise some proxies treat it
  # as "must-revalidate" always), and "no-transform" so that
  # various deflate schemes are not applied to it (does happen
  # with Rack::Cache and leads Chrome to throw up on content
  # decoding for example).
  IMAGE_CACHE_CONTROL = 'public, no-transform, max-age=2592000'
  
  # How long is a render (the ImageMagick/write part) is allowed to
  # take before we kill it
  RENDER_TIMEOUT_SECONDS = 10

  # Which input files we permit (based on extensions stored in MagicBytes)
  PERMITTED_SOURCE_FILE_EXTENSIONS = %w( gif png jpg )

  # Which output files are permitted (regardless of the input format
  # the processed images will be converted to one of these types)
  PERMITTED_OUTPUT_FILE_EXTENSIONS = %W( gif png jpg)

  # How long should we wait when fetching the image from the external host
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 4
  
  # The default file type for images with alpha
  PNG_FILE_TYPE = MagicBytes::FileType.new('png','image/png').freeze
  
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

    # Assume that if _any_ ETag is given the image is being requested anew as a refetch,
    # and the client already has it. Just respond with a 304.
    return [304, DEFAULT_HEADERS.dup, []] if env['HTTP_IF_NONE_MATCH']

    req = Rack::Request.new(env)
    bail(405, 'Only GET supported') unless req.get?

    image_request = ImageVise::ImageRequest.to_request(qs_params: req.params, secrets: ImageVise.secret_keys)
    render_destination_file, render_file_type, etag = process_image_request(image_request) 
    image_rack_response(render_destination_file, render_file_type, etag)
  rescue *permanent_failures => e
    handle_request_error(e)
    http_status_code = e.respond_to?(:http_status) ? e.http_status : 422
    raise_exception_or_error_response(e, http_status_code)
  rescue Exception => e
    if http_status_code = (e.respond_to?(:http_status) && e.http_status)
      handle_request_error(e)
      raise_exception_or_error_response(e, http_status_code)
    else
      handle_generic_error(e)
      raise_exception_or_error_response(e, 500)
    end
  end

  def process_image_request(image_request)
    # Recover the source image URL and the pipeline instructions (all the image ops)
    source_image_uri, pipeline = image_request.src_url, image_request.pipeline
    raise 'Image pipeline has no operators' if pipeline.empty?

    # Compute an ETag which describes this image transform + image source location.
    # Assume the image URL contents does _never_ change.
    etag = image_request.cache_etag
    
    # Download/copy the original into a Tempfile
    fetcher = ImageVise.fetcher_for(source_image_uri.scheme)
    source_file = fetcher.fetch_uri_to_tempfile(source_image_uri)
    
    # Make sure we do not try to process something...questionable
    source_file_type = detect_file_type(source_file)
    unless source_file_type_permitted?(source_file_type)
      raise UnsupportedInputFormat.new("Unsupported/unknown input file format .%s" % source_file_type.ext)
    end

    render_destination_file = binary_tempfile

    # Perform the processing
    if enable_forking?
      require 'exceptional_fork'
      ExceptionalFork.fork_and_wait { apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path) }
    else
      apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path)
    end
    
    render_destination_file.rewind

    # Catch this one early
    raise EmptyRender, "The rendered image was empty" if render_destination_file.size.zero?

    render_file_type = detect_file_type(render_destination_file)
    [render_destination_file, render_file_type, etag]
  ensure
    ImageVise.close_and_unlink(source_file)
  end

  def image_rack_response(render_destination_file, render_file_type, etag)
    response_headers = DEFAULT_HEADERS.merge({
      'Content-Type' => render_file_type.mime,
      'Content-Length' => '%d' % render_destination_file.size,
      'Cache-Control' => IMAGE_CACHE_CONTROL,
      'ETag' => etag
    })

    # Wrap the body Tempfile with a self-closing response.
    # Once the response is read in full, the tempfile is going to be closed and unlinked.
    [200, response_headers, ImageVise::FileResponse.new(render_destination_file)]
  end

  def raise_exception_or_error_response(exception, status_code)
    if raise_exceptions? 
      raise exception
    else
      bail status_code, exception.message
    end
  end
  
  def binary_tempfile
    Tempfile.new('imagevise-tmp').tap{|f| f.binmode }
  end
  
  def detect_file_type(tempfile)
    tempfile.rewind
    MagicBytes.read_and_detect(tempfile)
  end

  def source_file_type_permitted?(magick_bytes_file_info)
    PERMITTED_SOURCE_FILE_EXTENSIONS.include?(magick_bytes_file_info.ext)
  end

  def output_file_type_permitted?(magick_bytes_file_info)
    PERMITTED_OUTPUT_FILE_EXTENSIONS.include?(magick_bytes_file_info.ext)
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
    render_file_type = PNG_FILE_TYPE unless output_file_type_permitted?(render_file_type)
    
    magick_image.format = render_file_type.ext
    magick_image.write(render_to_path)
  ensure
    ImageVise.destroy(magick_image)
  end

end
