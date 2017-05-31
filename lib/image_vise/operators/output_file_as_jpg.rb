# Changes the render file type to jpg for smaller sized previews.
# Will also squash transparencies to support png to jpg conversions.
#
# The corresponding Pipeline method is `output_file_as_jpg`.
class ImageVise::OutputFileAsJpg
  def apply!(image)
    image.alpha(Magick::RemoveAlphaChannel)
    image['render_as'] = 'jpg'
  end

  ImageVise.add_operator 'output_file_as_jpg', self
end
