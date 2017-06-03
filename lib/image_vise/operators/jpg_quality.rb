# Changes the export quality of jpg images.
#
# The corresponding Pipeline method is `jpg_quality`.
class ImageVise::JpgQuality < Ks.strict(:jpg_quality)

  def initialize(*)
    super
    self.jpg_quality = jpg_quality.to_s
    raise ArgumentError, "the :jpg_quality parameter must be present and not empty" if self.jpg_quality.empty?
    raise ArgumentError, "the :jpg_quality parameter must not be negative" if self.jpg_quality.to_i < 0
    raise ArgumentError, "the :jpg_quality parameter must not be over 100" if self.jpg_quality.to_i > 100
  end

  def apply!(image, metadata)
    q = [1, self.jpg_quality.to_i, 100].sort[1]
    metadata[:writer] = ImageVise::JPGWriter.new(jpeg_quality: q)
  end

  ImageVise.add_operator 'jpg_quality', self
end
