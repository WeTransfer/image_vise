# Changes the render file type constant to the user's file type of choice
#
# The corresponding Pipeline method is `specify_filetype`.
class ImageVise::SpecifyFiletype < Ks.strict(:render_file_as)
  def initialize(*)
    super
    self.render_file_as = render_file_as.to_s
  end

  def apply!(image)
    image['render_as'] = render_file_as
  end

  ImageVise.add_operator 'specify_filetype', self
end
