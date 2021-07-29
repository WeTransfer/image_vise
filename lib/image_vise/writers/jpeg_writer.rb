class ImageVise::JPGWriter < Struct.new(:quality, keyword_init: true)
  JPG_EXT = 'jpg'

  def write_image!(magick_image, _, render_to_path)
    q = self.quality  # to avoid the changing "self" context
    magick_image.format = JPG_EXT
    magick_image.write(render_to_path) { self.quality = q }
  end
end
