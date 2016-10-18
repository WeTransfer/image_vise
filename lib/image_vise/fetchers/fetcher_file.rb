class ImageVise::FetcherFile
  class AccessError < StandardError
    def http_status; 403; end
  end
  def self.fetch_uri(uri)
    tf = Tempfile.new 'imagevise-localfs-copy'
    real_path_on_filesystem = File.expand_path(URI.decode(uri.path))
    verify_filesystem_access! real_path_on_filesystem
    # Do the checks
    File.open(real_path_on_filesystem, 'rb') do |f|
      IO.copy_stream(f, tf)
    end
    tf.rewind; tf
  rescue Exception => e
    ImageVise.close_and_unlink(tf)
    raise e
  end

  def self.verify_filesystem_access!(path_on_filesystem)
    patterns = ImageVise.allowed_filesystem_sources
    matches = patterns.any? { |glob_pattern| File.fnmatch?(glob_pattern, path_on_filesystem) }
    raise AccessError, "filesystem access is disabled" unless patterns.any?
    raise AccessError, "#{src_url} is not on the path whitelist" unless matches
  end

  ImageVise.register_fetcher 'file', self
end
