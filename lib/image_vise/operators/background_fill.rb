# Applies a background fill color.
# Can handle most 'word' colors and hex color codes but not RGB values.
#
# The corresponding Pipeline method is `background_fill`.
class ImageVise::BackgroundFill < Struct.new(:color, keyword_init: true)
  def initialize(*)
    super
    self.color = color.to_s
    raise ArgumentError, "the :color parameter must be present and not empty" if self.color.empty?
  end

  def apply!(image)
    # Create an image filled with our color, preserving the size, color class and dimensions
    fill_image = image.copy
    fill_image.color_reset!(color)

    # Composite our actual image _on top_ of it, using the standard over composite operator.
    # This way we don't have to look for "UnderCompositeOp" within the bowels of RMagick.
    fill_image.composite!(image, x_off=0, y_off=0, Magick::OverCompositeOp)
    # ..and move the resulting pixels into our original images, replacing everything
    image.composite!(fill_image, x_off=0, y_off=0, Magick::CopyCompositeOp)
    image.alpha(Magick::DeactivateAlphaChannel)
  ensure
    ImageVise.destroy(fill_image)
  end

  ImageVise.add_operator 'background_fill', self
end
