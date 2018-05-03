class ImageVise::FetcherFile
  class AccessError < StandardError
    def http_status; 403; end
  end

  def self.fetch_uri_to_tempfile(uri)
    tf = Tempfile.new 'imagevise-localfs-copy'
    real_path_on_filesystem = uri_to_path(uri)
    verify_filesystem_access!(real_path_on_filesystem)
    File.open(real_path_on_filesystem, 'rb') do |f|
      IO.copy_stream(f, tf)
    end
    tf.rewind; tf
  rescue Exception => e
    ImageVise.close_and_unlink(tf)
    raise e
  end

  def self.uri_to_path(uri)
    File.expand_path(URI.decode(uri.path))
  end

  def self.verify_filesystem_access!(path_on_filesystem)
    patterns = ImageVise.allowed_filesystem_sources
    matches = patterns.any? { |glob_pattern| File.fnmatch?(glob_pattern, path_on_filesystem) }
    raise AccessError, "filesystem access is disabled" unless patterns.any?
    raise AccessError, "#{path_on_filesystem} is not on the path whitelist" unless matches
  end

  ImageVise.register_fetcher 'file', self
end
