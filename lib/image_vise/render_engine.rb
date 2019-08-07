  class ImageVise::RenderEngine
  class UnsupportedInputFormat < StandardError; end
  class EmptyRender < StandardError; end

  class Filetype < Struct.new(:format_parser_format)
    def mime
      Rack::Mime.mime_type(ext)
    end
    
    def ext
      ".#{format_parser_format}"
    end
  end

  DEFAULT_HEADERS = {
    'Allow' => 'GET',
    'X-Content-Type-Options' => 'nosniff',
  }.freeze

  # Headers for error responses that denote an invalid or
  # an unsatisfiable request
  JSON_ERROR_HEADERS_REQUEST = DEFAULT_HEADERS.merge({
    'Content-Type' => 'application/json',
    'Cache-Control' => 'public, max-age=600'
  }).freeze

  # Headers for error responses that denote
  # an intermittent error (that permit retries)
  JSON_ERROR_HEADERS_INTERMITTENT = DEFAULT_HEADERS.merge({
    'Content-Type' => 'application/json',
    'Cache-Control' => 'public, max-age=5'
  }).freeze

  # Cache details:  "public" of course. Add max-age so that there is _some_
  # revalidation after a time (otherwise some proxies treat it
  # as "must-revalidate" always), and "no-transform" so that
  # various deflate schemes are not applied to it (does happen
  # with Rack::Cache and leads Chrome to throw up on content
  # decoding for example).
  IMAGE_CACHE_CONTROL = "public, no-transform, max-age=%d"

  # Which input files we permit (based on format identifiers in format_parser, which are symbols)
  PERMITTED_SOURCE_FORMATS = [:bmp, :tif, :jpg, :psd, :gif, :png]

  # How long should we wait when fetching the image from the external host
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 4

  def bail(status, *errors_array)
    headers = if (300...500).cover?(status)
      JSON_ERROR_HEADERS_REQUEST.dup
    else
      JSON_ERROR_HEADERS_INTERMITTENT.dup
    end
    response = [status.to_i, headers, [JSON.pretty_generate({errors: errors_array})]]
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
    encoded_request, signature = extract_params_from_request(req)

    image_request = ImageVise::ImageRequest.from_params(
      base64_encoded_params: encoded_request,
      given_signature: signature,
      secrets: ImageVise.secret_keys
    )
    render_destination_file, render_file_type, etag, expire_after = process_image_request(image_request)
    image_rack_response(render_destination_file, render_file_type, etag, expire_after)
  rescue *permanent_failures => e
    handle_request_error(e)
    http_status_code = e.respond_to?(:http_status) ? e.http_status : 400
    raise_exception_or_error_response(e, http_status_code)
  rescue => e
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
  # @return [String, String] the Base64-encoded image request and the signature
  def extract_params_from_request(rack_request)
    # Prevent cache bypass DOS attacks by only permitting :sig and :q
    bail(400, 'Query strings are not supported') if rack_request.params.any?

    # Take the last two path components of the request URI.
    # The second-to-last is the Base64-encoded image request, the last is the signature.
    # Slashes within the image request are masked out already, no need to worry about them.
    # Parameters are passed in the path so that ImageVise integrates easier with CDNs and so that
    # it becomes harder to blow the cache by appending spurious query string parameters and/or
    # reordering query string parameters at will.
    *, q_from_path, sig_from_path = rack_request.path_info.split('/')

    # Raise if any of them are empty or blank
    nothing_recovered = [q_from_path, sig_from_path].all?{|v| v.nil? || v.empty? }
    bail(400, 'Need 2 usable path components') if nothing_recovered

    [q_from_path, sig_from_path]
  end

  # Processes the ImageRequest object created from the request parameters,
  # and returns a triplet of the File object containing the rendered image,
  # the MagicBytes::FileType object of the render, and the cache ETag value
  # representing the processing pipeline
  #
  # @param image_request[ImageVise::ImageRequest] the request for the image
  # @return [Array<File, FileType, String]
  def process_image_request(image_request)
    # Recover the source image URL and the pipeline instructions (all the image ops)
    source_image_uri, pipeline = image_request.src_url, image_request.pipeline
    raise 'Image pipeline has no operators' if pipeline.empty?

    # Compute an ETag which describes this image transform + image source location.
    # Assume the image URL contents does _never_ change.
    etag = image_request.cache_etag

    # Download/copy the original into a Tempfile
    fetcher = ImageVise.fetcher_for(source_image_uri.scheme)
    source_file = Measurometer.instrument('image_vise.fetch') do
      fetcher.fetch_uri_to_tempfile(source_image_uri)
    end
    file_format = FormatParser.parse(source_file, natures: [:image]).tap { source_file.rewind }
    raise UnsupportedInputFormat.new("%s has an unknown input file format" % source_image_uri) unless file_format
    raise UnsupportedInputFormat.new("%s does not pass file constraints" % source_image_uri) unless permitted_format?(file_format)

    render_destination_file = Tempfile.new('imagevise-render').tap{|f| f.binmode }

    # Do the actual imaging stuff
    expire_after = Measurometer.instrument('image_vise.render_engine.apply_pipeline') do
      apply_pipeline(source_file.path, pipeline, file_format, render_destination_file.path)
    end

    # Catch this one early
    render_destination_file.rewind
    raise EmptyRender, "The rendered image was empty" if render_destination_file.size.zero?

    render_file_type = detect_file_type(render_destination_file)

    [render_destination_file, render_file_type, etag, expire_after]
  ensure
    ImageVise.close_and_unlink(source_file)
  end

  # Returns a Rack response triplet. Accepts the return value of
  # `process_image_request` unsplatted, and returns a triplet that
  # can be returned as a Rack response. The Rack response will contain
  # an iterable body object that is designed to automatically delete
  # the Tempfile it wraps on close. Sets the cache lifetime to either the default
  # value of 2592000 or the value the user selected using add_custom_cache_max_length.
  #
  # @param render_destination_file[File] the File handle to the rendered image
  # @param render_file_type[MagicBytes::FileType] the rendered file type
  # @param etag[String] the ETag for the response
  def image_rack_response(render_destination_file, render_file_type, etag, expire_after)
    response_headers = DEFAULT_HEADERS.merge({
      'Content-Type' => render_file_type.mime,
      'Content-Length' => '%d' % render_destination_file.size,
      'Cache-Control' => IMAGE_CACHE_CONTROL % expire_after.to_i,
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
  # @return [Symbol] the detected file format symbol that can be used as an extension
  def detect_file_type(tempfile)
    tempfile.rewind
    parser_result = FormatParser.parse(tempfile, natures: :image).tap { tempfile.rewind }
    raise "Rendered file type detection failed" unless parser_result
    Filetype.new(parser_result.format)
  end

  # Tells whether the file described by the given FormatParser result object
  # can be accepted for processing
  #
  # @param format_parser_result[FormatParser::Image] file information descriptor
  # @return [Boolean]
  def permitted_format?(format_parser_result)
    return false unless PERMITTED_SOURCE_FORMATS.include?(format_parser_result.format)
    return false if format_parser_result.has_multiple_frames
    true
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

  # Applies the given {ImageVise::Pipeline} to the image, and writes the render to
  # the given path.
  #
  # @param source_file_path[String] the path to the file containing the source image
  # @param pipeline[#apply!(Magick::Image)] the processing pipeline
  # @param render_to_path[String] the path to write the rendered image to
  # @return [void]
  def apply_pipeline(source_file_path, pipeline, source_format_parser_result, render_to_path)

    # Load the first frame of the animated GIF _or_ the blended compatibility layer from Photoshop
    image_list = Measurometer.instrument('image_vise.load_pixbuf') do
      Magick::Image.read(source_file_path)
    end
      
    magick_image = image_list.first # Picks up the "precomp" PSD layer in compatibility mode, or the first frame of a GIF

    # If any operators want to stash some data for downstream use we use this Hash
    metadata = {format_parser_result: source_format_parser_result}

    # Apply the pipeline (all the image operators)
    pipeline.apply!(magick_image, metadata)

    # Write out the file honoring the possible injected metadata. One of the metadata
    # elements (that an operator might want to alter) is the :writer, we forcibly #fetch
    # it so that we get a KeyError if some operator has deleted it without providing a replacement.
    # If no operators touched the writer we are going to use the automatic format selection
    writer = metadata.fetch(:writer, ImageVise::AutoWriter.new)
    Measurometer.instrument('image_vise.write_image') do
      writer.write_image!(magick_image, metadata, render_to_path)
    end

    # Another metadata element is the expire_after, which we default to an app-wide setting
    metadata.fetch(:expire_after_seconds, ImageVise.cache_lifetime_seconds)
  ensure
    # destroy all the loaded images explicitly
    (image_list || []).map {|img| ImageVise.destroy(img) }
  end

end
