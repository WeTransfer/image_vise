# Wrappers a given Tempfile for a Rack response.
# Will close _and_ unlink the Tempfile it contains.
class ImageVise::FileResponse
  ONE_CHUNK_BYTES = 1024 * 1024 * 2
  def initialize(file)
    @file = file
  end
  
  def each
    @file.flush # Make sure all the writes have been synchronized
    # We can easily open another file descriptor
    File.open(@file.path, 'rb') do |my_file_descriptor|
      while data = my_file_descriptor.read(ONE_CHUNK_BYTES)
        yield(data)
      end
    end
  end
  
  def close
    ImageVise.close_and_unlink(@file)
  end
end
