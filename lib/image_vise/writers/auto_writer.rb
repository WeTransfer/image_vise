# Picks the most reasonable "default" output format for web resources. In practice, if the
# image contains transparency (an alpha channel) PNG will be chosen, and if not - JPEG will
# be chosen. Since ImageVise URLs do not contain a file extension we are free to pick
# the suitable format at render time
class ImageVise::AutoWriter
  # The default file type for images with alpha
  PNG_FILE_TYPE = MagicBytes::FileType.new('png','image/png').freeze

  # Renders the file as a jpg if the custom output filetype operator is used
  JPG_FILE_TYPE = MagicBytes::FileType.new('jpg','image/jpeg').freeze
  
  def write_image!(magick_image, _, render_to_path)
    # If processing the image has created an alpha channel, use PNG always.
    # Otherwise, keep the original format for as far as the supported formats list goes.
    render_file_type = if magick_image.alpha?
      PNG_FILE_TYPE
    else
      JPG_FILE_TYPE
    end
    magick_image.format = render_file_type.ext
    magick_image.write(render_to_path)
  end
end
