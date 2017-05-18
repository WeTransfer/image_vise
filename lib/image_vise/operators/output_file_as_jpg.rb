# Changes the render file type constant to the user's file type of choice
#
# The corresponding Pipeline method is `output_file_as_jpg`.
class ImageVise::OutputFileAsJpg
  def apply!(image)
    image['render_as'] = 'jpg'
  end

  ImageVise.add_operator 'output_file_as_jpg', self
end
