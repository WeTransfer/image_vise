class ImageVise::JPGWriter < Ks.strict(:quality)
  JPG_FILE_TYPE = MagicBytes::FileType.new('jpg','image/jpeg').freeze

  def write_image!(magick_image, _, render_to_path)
    q = self.quality  # to avoid the changing "self" context
    magick_image.format = JPG_FILE_TYPE.ext
    magick_image.write(render_to_path) { self.quality = q }
  end
end
