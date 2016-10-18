# Applies a transformation using an ImageMagick geometry string
#
# The corresponding Pipeline method is `geom`.
class ImageVise::Geom < Ks.strict(:geometry_string)
  def initialize(*)
    super
    self.geometry_string = geometry_string.to_s
    raise ArgumentError, "the :geom parameter must be present and not empty" if self.geometry_string.empty?
  end

  def apply!(image)
    image.change_geometry(geometry_string) { |cols, rows, _| image.resize!(cols,rows) }
  end

  ImageVise.add_operator 'geom', self
end
