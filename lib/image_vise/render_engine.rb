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
  
  # The main entry point for the Rack app. Wraps a call to {#handle_request} in a `catch{}` block
  # so that any method can abort the request by calling {#bail}
  #
  # @param env[Hash] the Rack env
  # @return [Array] the Rack response
  def call(env)
    catch(:__bail) { handle_request(env) }
  end
  
  # Hadles the Rack request. If one of the steps calls {#bail} the `:__bail` symbol will be
  # thrown and the execution will abort. Any errors will cause either an error response in
  # JSON format or an Exception will be raised (depending on the return value of `raise_exceptions?`)
  #
  # @param env[Hash] the Rack env
  # @return [Array] the Rack response
  def handle_request(env)
    setup_error_handling(env)

    # Assume that if _any_ ETag is given the image is being requested anew as a refetch,
    # and the client already has it. Just respond with a 304.
    return [304, DEFAULT_HEADERS.dup, []] if env['HTTP_IF_NONE_MATCH']

    req = parse_env_into_request(env)
    bail(405, 'Only GET supported') unless req.get?
    params = extract_params_from_request(req)
    
    image_request = ImageVise::ImageRequest.from_params(qs_params: params, secrets: ImageVise.secret_keys)
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
  
  # Parses the Rack environment into a Rack::Reqest. The following methods
  # are going to be called on it: `#get?` and `#params`. You can use this
  # method to override path-to-parameter translation for example.
  #
  # @param rack_env[Hash] the Rack environment
  # @return [#get?, #params] the Rack request or a compatible object
  def parse_env_into_request(rack_env)
    Rack::Request.new(rack_env)
  end

  # Extracts the image params from the Rack::Request
  #
  # @param rack_request[#path_info] an object that has a path info
  # @return [Hash] the params hash with `:q` and `:sig` keys
  def extract_params_from_request(rack_request)
    # Prevent cache bypass DOS attacks by only permitting :sig and :q
    bail(400, 'Query strings are not supported') if rack_request.params.any?
    
    # Extract the tail (signature) and the front (the Base64-encoded request).
    *, q_from_path, sig_from_path = rack_request.path_info.split('/')

    # Raise if any of them are empty or blank
    nothing_recovered = [q_from_path, sig_from_path].all?{|v| v.nil? || v.empty? }
    bail(400, 'Need 2 usable path components') if nothing_recovered

    {q: q_from_path, sig: sig_from_path}
  end

  # Processes the ImageRequest object created from the request parameters,
  # and returns a triplet of the File object containing the rendered image,
  # the MagicBytes::FileType object of the render, and the cache ETag value
  # representing the processing pipeline
  #
  # @param image_request[ImageVise::ImageRequest] the request for the image
  # @return [Array<File, MagicBytes::FileType, String]
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

    render_destination_file = Tempfile.new('imagevise-render').tap{|f| f.binmode }

    # Perform the processing
    if enable_forking?
      require 'exceptional_fork'
      ExceptionalFork.fork_and_wait do
        apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path)
      end
    else
      apply_pipeline(source_file.path, pipeline, source_file_type, render_destination_file.path)
    end

    # Catch this one early
    render_destination_file.rewind
    raise EmptyRender, "The rendered image was empty" if render_destination_file.size.zero?

    render_file_type = detect_file_type(render_destination_file)
    [render_destination_file, render_file_type, etag]
  ensure
    ImageVise.close_and_unlink(source_file)
  end
  
  # Returns a Rack response triplet. Accepts the return value of
  # `process_image_request` unsplatted, and returns a triplet that
  # can be returned as a Rack response. The Rack response will contain
  # an iterable body object that is designed to automatically delete
  # the Tempfile it wraps on close.
  #
  # @param render_destination_file[File] the File handle to the rendered image
  # @param render_file_type[MagicBytes::FileType] the rendered file type
  # @param etag[String] the ETag for the response
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

  # Depending on `raise_exceptions?` will either raise the passed Exception,
  # or force the application to return the error in the Rack response.
  #
  # @param exception[Exception] the error that has to be captured
  # @param status_code[Fixnum] the HTTP status code
  def raise_exception_or_error_response(exception, status_code)
    if raise_exceptions? 
      raise exception
    else
      bail status_code, exception.message
    end
  end
  
  # Detects the file type of the given File and returns
  # a MagicBytes::FileType object that contains the extension and
  # the MIME type.
  #
  # @param tempfile[File] the file to perform detection on
  # @return [MagicBytes::FileType] the detected file type
  def detect_file_type(tempfile)
    tempfile.rewind
    MagicBytes.read_and_detect(tempfile).tap { tempfile.rewind }
  end

  # Tells whether the given file type may be loaded into the image processor.
  #
  # @param magic_bytes_file_info[MagicBytes::FileType] the filetype
  # @return [Boolean]
  def source_file_type_permitted?(magic_bytes_file_info)
    PERMITTED_SOURCE_FILE_EXTENSIONS.include?(magic_bytes_file_info.ext)
  end

  # Tells whether the given file type may be returned
  # as the result of the render
  #
  # @param magic_bytes_file_info[MagicBytes::FileType] the filetype
  # @return [Boolean]
  def output_file_type_permitted?(magic_bytes_file_info)
    PERMITTED_OUTPUT_FILE_EXTENSIONS.include?(magic_bytes_file_info.ext)
  end

  # Lists exceptions that should lead to the request being flagged
  # as invalid (4xx as opposed to 5xx for a generic server error).
  # Decent clients should _not_ retry those requests.
  def permanent_failures
    [
      Magick::ImageMagickError,
      UnsupportedInputFormat,
      ImageVise::ImageRequest::InvalidRequest
    ]
  end
  
  # Is meant to be overridden by subclasses,
  # will be called at the start of each request to set up the error handling
  # library (Appsignal, Honeybadger, Sentry...)
  #
  # @param rack_env[Hash] the Rack env
  # @return [void]
  def setup_error_handling(rack_env)
  end

  # Is meant to be overridden by subclasses,
  # will be called when a request fails due to a malformed query string,
  # unrecognized signature or other client-induced problems. The method
  # should _not_ re-raise the exception.
  #
  # @param exception[Exception] the exception to be handled
  # @return [void]
  def handle_request_error(exception)
  end

  # Is meant to be overridden by subclasses,
  # will be called when a request fails due to an error on the server
  # (like an unexpected error in an image operator). The method
  # should _not_ re-raise the exception.
  #
  # @param exception[Exception] the exception to be handled
  # @return [void]
  def handle_generic_error(exception)
  end
  
  # Tells whether the engine must raise the exceptions further up the Rack stack,
  # or they should be suppressed and a JSON response must be returned.
  #
  # @return [Boolean]
  def raise_exceptions?
    false
  end
  
  # Tells whether image processing in a forked subproces should be turned on
  #
  # @return [Boolean]
  def enable_forking?
    ENV['IMAGE_VISE_ENABLE_FORK'] == 'yes'
  end
  
  # Applies the given {ImageVise::Pipeline} to the image, and writes the render to
  # the given path.
  #
  # @param source_file_path[String] the path to the file containing the source image
  # @param pipeline[#apply!(Magick::Image)] the processing pipeline
  # @param render_to_path[String] the path to write the rendered image to
  # @return [void]
  def apply_pipeline(source_file_path, pipeline, source_file_type, render_to_path)
    render_file_type = source_file_type
    
    # Load the first frame of the animated GIF _or_ the blended compatibility layer from Photoshop
    image_list = Magick::Image.read(source_file_path)
    magick_image = image_list.first

    # Apply the pipeline
    pipeline.apply!(magick_image)

    # If processing the image has created an alpha channel, use PNG always.
    # Otherwise, keep the original format for as far as the supported formats list goes.
    render_file_type = PNG_FILE_TYPE if magick_image.alpha?
    render_file_type = PNG_FILE_TYPE unless output_file_type_permitted?(render_file_type)
    
    magick_image.format = render_file_type.ext
    magick_image.write(render_to_path)
  ensure
    # destroy all the loaded images explicitly
    (image_list || []).map {|img| ImageVise.destroy(img) }
  end

end
