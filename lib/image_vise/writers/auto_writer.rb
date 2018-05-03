# Picks the most reasonable "default" output format for web resources. In practice, if the
# image contains transparency (an alpha channel) PNG will be chosen, and if not - JPEG will
# be chosen. Since ImageVise URLs do not contain a file extension we are free to pick
# the suitable format at render time
class ImageVise::AutoWriter
  PNG_EXT = 'png'
  JPG_EXT = 'jpg'
  def write_image!(magick_image, _, render_to_path)
    # If processing the image has created an alpha channel, use PNG always.
    # Otherwise, keep the original format for as far as the supported formats list goes.
    extension = magick_image.alpha? ? PNG_EXT : JPG_EXT
    magick_image.format = extension
    magick_image.write(render_to_path)
  end
end
