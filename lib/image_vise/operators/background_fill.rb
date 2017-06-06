# Applies a background fill color.
# Can handle most 'word' colors and hex color codes but not RGB values.
#
# The corresponding Pipeline method is `background_fill`.
class ImageVise::BackgroundFill < Ks.strict(:color)
  def initialize(*)
    super
    self.color = color.to_s
    raise ArgumentError, "the :color parameter must be present and not empty" if self.color.empty?
  end

  def apply!(image)
    image.border!(0, 0, color)
    image.alpha(Magick::DeactivateAlphaChannel)
  end

  ImageVise.add_operator 'background_fill', self
end
