# Applies a sharpening filter to the image.
#
# The corresponding Pipeline method is `sharpen`.
class ImageVise::Sharpen < Struct.new(:radius, :sigma, keyword_init: true)
  def initialize(*)
    super
    self.radius = radius.to_f
    self.sigma = sigma.to_f
    raise ArgumentError, ":radius must positive" unless sigma > 0
    raise ArgumentError, ":sigma must positive" unless sigma > 0
  end
  
  def apply!(magick_image)
    sharpened_image = magick_image.sharpen(radius, sigma)
    magick_image.composite!(sharpened_image, Magick::CenterGravity, Magick::CopyCompositeOp)
  ensure
    ImageVise.destroy(sharpened_image)
  end
end

ImageVise.add_operator 'sharpen', ImageVise::Sharpen