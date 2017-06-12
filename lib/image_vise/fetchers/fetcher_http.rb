class ImageVise::FetcherHTTP
  EXTERNAL_IMAGE_FETCH_TIMEOUT_SECONDS = 5

  # Which raw filetypes we permit (based on compatibility with ImageMagick)
  PERMITTED_RAW_FILE_EXTENSIONS = %w( cr2 nef )

  class AccessError < StandardError; end

  class UpstreamError < StandardError
    attr_accessor :http_status
    def initialize(http_status, message)
      super(message)
      @http_status = http_status
    end
  end

  def self.fetch_uri_to_tempfile(uri)
    extension = uri.to_s[-3,3].downcase
    if PERMITTED_RAW_FILE_EXTENSIONS.include?(extension)
      tf = Tempfile.new(['imagevise-http-download', "." + extension])
      tf.path
    else
      tf = Tempfile.new 'imagevise-http-download'
    end
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

  def self.verify_uri_access!(uri)
    host = uri.host
    return if ImageVise.allowed_hosts.include?(uri.host)
    raise AccessError, "#{uri} is not permitted as source"
  end

  ImageVise.register_fetcher 'http', self
  ImageVise.register_fetcher 'https', self
end
