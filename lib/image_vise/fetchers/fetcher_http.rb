class ImageVise::FetcherHTTP
  PASSTHROUGH_STATUS_CODES = [404, 403, 503, 504, 500]
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 5

  class AccessError < StandardError; end

  class UpstreamError < StandardError
    attr_accessor :http_status
    def initialize(http_status, message)
      super(message)
      @http_status = http_status
    end
  end
  
  def self.fetch_uri(uri)
    tf = Tempfile.new 'imagevise-http-download'
    verify_uri_access!(uri)
    s = Patron::Session.new
    s.automatic_content_encoding = true
    s.timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    s.connect_timeout = EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS
    
    response = s.get_file(uri.to_s, tf.path)
    
    if PASSTHROUGH_STATUS_CODES.include?(response.status)
      ImageVise.close_and_unlink(tf)
      raise UpstreamError.new(response.status, "Unfortunate upstream response #{response.status}")
    end
    
    tf
  rescue Exception => e
    ImageVise.close_and_unlink(tf)
    raise e
  end
  
  def self.verify_uri_access!(uri)
    host = uri.host
    unless ImageVise.allowed_hosts.include?(uri.host)
      raise AccessError, "#{uri} is not permitted as source"
    end
  end

  ImageVise.register_fetcher 'http', self
  ImageVise.register_fetcher 'https', self
end
