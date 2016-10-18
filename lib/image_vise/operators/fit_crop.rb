# Fits the image based on the smaller-side fit. This means that the image is going to be fit
# into the requested rectangle so that all of the pixels of the rectangle are filled. The
# gravity parameter defines the crop gravity (on corners, sides, or in the middle).
#
# The corresponding Pipeline method is `fit_crop`.
class ImageVise::FitCrop < Ks.strict(:width, :height, :gravity)
  GRAVITY_PARAMS = {
    'nw' => Magick::NorthWestGravity,
    'n' => Magick::NorthGravity,
    'ne' => Magick::NorthEastGravity,
    'w' => Magick::WestGravity,
    'c' => Magick::CenterGravity,
    'e' => Magick::EastGravity,
    'sw' => Magick::SouthWestGravity,
    's' => Magick::SouthGravity,
    'se' => Magick::SouthEastGravity,
  }

  def initialize(*)
    super
    self.width = width.to_i
    self.height = height.to_i
    raise ArgumentError, ":width must positive" unless width > 0
    raise ArgumentError, ":height must positive" unless height > 0
    raise ArgumentError, ":gravity must be within the permitted values" unless GRAVITY_PARAMS.key? gravity
  end

  def apply!(magick_image)
    magick_image.resize_to_fill! width, height, GRAVITY_PARAMS.fetch(gravity)
  end
  
  ImageVise.add_operator 'fit_crop', self
end
