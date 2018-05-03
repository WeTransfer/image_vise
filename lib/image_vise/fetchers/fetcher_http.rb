class ImageVise::FetcherHTTP
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 5

  class AccessError < StandardError; end

  class UpstreamError < StandardError
    attr_accessor :http_status
    def initialize(http_status, message)
      super(message)
      @http_status = http_status
    end
  end
  
  def self.fetch_uri_to_tempfile(uri)
    tf = Tempfile.new 'imagevise-http-download'
    verify_uri_access!(uri)

    s = Patron::Session.new
    s.automatic_content_encoding = true
    s.timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    s.connect_timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    
    response = s.get_file(uri.to_s, tf.path)
    
    if response.status != 200
      raise UpstreamError.new(response.status, "Unfortunate upstream response #{response.status} on #{uri}")
    end
    
    tf
  rescue Exception => e
    ImageVise.close_and_unlink(tf)
    raise e
  end

  def self.format_parser_detect(uri)
    verify_uri_access!(uri)
    FormatParser.parse_http(uri, natures: [:image])
  rescue => e
    code = e.respond_to?(:status_code) ? e.status_code : 400
    raise UpstreamError.new(code, "Format detection failed for #{uri} - #{e.message}")
  end

  def self.verify_uri_access!(uri)
    host = uri.host
    return if ImageVise.allowed_hosts.include?(uri.host)
    raise AccessError, "#{uri} is not permitted as source"
  end

  ImageVise.register_fetcher 'http', self
  ImageVise.register_fetcher 'https', self
end
