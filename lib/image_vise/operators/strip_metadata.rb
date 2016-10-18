# Strips metadata from the image (EXIF, IPTC etc.) using the
# RMagick `strip!` method
#
# The corresponding Pipeline method is `strip_metadata`.
class ImageVise::StripMetadata
  def apply!(magick_image)
    magick_image.strip!
  end
  ImageVise.add_operator 'strip_metadata', self
end
