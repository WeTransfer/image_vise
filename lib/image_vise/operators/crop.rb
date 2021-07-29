# Crops the image to the given dimensions with a given gravity. Gravities are shorthand versions
# of ImageMagick gravity parameters (see GRAVITY_PARAMS)
#
# The corresponding Pipeline method is `crop`.
class ImageVise::Crop < Struct.new(:width, :height, :gravity, keyword_init: true)
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
  
  def apply!(image)
    image.crop!(GRAVITY_PARAMS.fetch(gravity), width, height, remove_padding_data_outside_window = true)
  end

  ImageVise.add_operator 'crop', self
end
