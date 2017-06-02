# Changes the render file type to jpg for smaller sized previews.
# Will also squash transparencies to support png to jpg conversions.
#
# The corresponding Pipeline method is `custom_output_filetype`.
class ImageVise::CustomOutputFiletype < Ks.strict(:filetype)

  PERMITTED_OUTPUT_FILE_EXTENSIONS = %W( gif png jpg)

  def initialize(*)
    super
    self.filetype = filetype.to_s
    raise ArgumentError, "the :filetype parameter must be present and not empty" if self.filetype.empty?
    raise ArgumentError, "the requested filetype is not permitted" if !output_file_type_permitted?(self.filetype)
  end

  def apply!(image)
    config_hash = JSON.parse(image["image_vise_config_data"])
    config_hash = {:filetype => filetype}
    image["image_vise_config_data"] = config_hash.to_json
  end

  def output_file_type_permitted?(magic_bytes_file_info)
    PERMITTED_OUTPUT_FILE_EXTENSIONS.include?(magic_bytes_file_info)
  end

  ImageVise.add_operator 'custom_output_filetype', self
end
