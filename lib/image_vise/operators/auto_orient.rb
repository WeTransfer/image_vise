# Applies ImageMagick auto_orient to the image, so that i.e. mobile photos
# can be oriented correctly. The operation is applied destructively (changes actual pixel data)
#
# The corresponding Pipeline method is `auto_orient`.
class ImageVise::AutoOrient
  def apply!(magick_image)
    magick_image.auto_orient!
  end
  ImageVise.add_operator 'auto_orient', self
end
