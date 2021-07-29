# Forces the output format to be JPEG and specifies the quality factor to use when saving
#
# The corresponding Pipeline method is `force_jpg_out`.
class ImageVise::ForceJPGOut < Struct.new(:quality, keyword_init: true)
  def initialize(quality:)
    unless (0..100).cover?(quality)
      raise ArgumentError, "the :quality setting must be within 0..100, but was %d" % quality
    end
    self.quality = quality
  end

  def apply!(_, metadata)
    metadata[:writer] = ImageVise::JPGWriter.new(quality: quality)
  end

  ImageVise.add_operator 'force_jpg_out', self
end
