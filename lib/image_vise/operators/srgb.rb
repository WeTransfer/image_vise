# Applies the sRGB profile to the image.
# For this to work, your ImageMagick must be built
# witl LCMS support. On OSX, you need to use the brew install
# command with the following options:
#
#    $brew install imagemagick --with-little-cms --with-little-cms2
#
# You can verify if you do have LittleCMS support by checking the
# delegates list that `$convert --version` outputs:
#
# For instance, if you do not have it, the list will look like this:
#
#    $ convert --version
#    ...
#    Delegates (built-in): bzlib freetype jng jpeg ltdl lzma png tiff xml zlib
#
# whereas if you do, the list will include the "lcms" delegate:
#
#    $ convert --version
#    ...
#    Delegates (built-in): bzlib freetype jng jpeg lcms ltdl lzma png tiff xml zlib
#
# The corresponding Pipeline method is `srgb`.
class ImageVise::SRGB
  PROFILE_PATH = File.expand_path(__dir__ + '/sRGB_v4_ICC_preference_displayclass.icc')
  def apply!(magick_image)
    magick_image = validate_color_profile(magick_image)
    magick_image.add_profile(PROFILE_PATH)
  end

  # def apply!(magick_image)
  #   begin
  #     magick_image.add_profile(PROFILE_PATH)
  #   rescue Magick::ImageMagickError => error
  #     # image.delete_profile('icc')
  #     magick_image = remove_color_profile(magick_image, error.message)
  #     apply!(magick_image)
  #   end
  # end
  #
  # def remove_color_profile(magick_image, error_message)
  #   if error_message.downcase.include?('color profile operates on another colorspace')
  #     magick_image.strip!
  #   end
  # end

  def validate_color_profile(magick_image)
    valid_colorspaces_and_profiles = {
      'sRGBColorspace' => 'RGB', 'CMYKColorspace' => 'CMYK', 'RGBColorspace' => 'RGB'
    }
    color_profile = magick_image.color_profile
    colorspace = magick_image.colorspace.to_s
    if !color_profile.include?(valid_colorspaces_and_profiles.fetch(colorspace))
      magick_image.strip!
    end
    magick_image
  end
  ImageVise.add_operator 'srgb', self
end
