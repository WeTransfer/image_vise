class ImageVise::FetcherHTTP
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 5
  MAXIMUM_SOURCE_FILE_SIZE = 20 * 1024 * 1024

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
    s.download_byte_limit = maximum_response_size_bytes
    response = s.get_file(uri.to_s, tf.path)

    if response.status != 200
      raise UpstreamError.new(response.status, "Unfortunate upstream response #{response.status} on #{uri}")
    end

    tf
  rescue Patron::Aborted # File size exceeds permitted size
    ImageVise.close_and_unlink(tf)
    raise UpstreamError.new(400, "Upstream resource at #{uri} is too large to load")
  rescue Exception => e
    ImageVise.close_and_unlink(tf)
    raise e
  end

  def self.maximum_response_size_bytes
    MAXIMUM_SOURCE_FILE_SIZE
  end

  def self.verify_uri_access!(uri)
    host = uri.host
    return if ImageVise.allowed_hosts.include?(uri.host)
    raise AccessError, "#{uri} is not permitted as source"
  end

  ImageVise.register_fetcher 'http', self
  ImageVise.register_fetcher 'https', self
end
