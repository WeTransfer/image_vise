# Changes the render file type to jpg for smaller sized previews.
# Will also squash transparencies to support png to jpg conversions.
#
# The corresponding Pipeline method is `output_file_as_jpg`.
class ImageVise::OutputFileAsJpg
  def apply!(image)
    config_hash = JSON.parse(image["image_vise_config_data"])
    config_hash = {:filetype => "jpg"}
    image["image_vise_config_data"] = config_hash.to_json
  end

  ImageVise.add_operator 'output_file_as_jpg', self
end
