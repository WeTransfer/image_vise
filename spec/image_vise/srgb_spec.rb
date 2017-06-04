require 'spec_helper'

describe ImageVise::SRGB do
  it 'applies the profile, creating a perceptible difference with the original' do
    # This test will function only if you have RMagick with LCMS2 support
    # built-in. If you do, the two images will look _very_ much like one
    # another.
    #
    # If you don't, the images will look remarkably different
    # (the AdobeRGB version has color values that match AdobeRGB
    # primaries, and will render diffrently in pretty much any
    # viewer).
    image = Magick::Image.read(test_image_adobergb_path).first
    subject.apply!(image)
    image.strip!
    examine_image(image, "from-adobergb-SHOULD-LOOK-IDENTICAL")

    image = Magick::Image.read(test_image_path).first
    subject.apply!(image)
    image.strip!
    examine_image(image, "from-srgb-SHOULD-LOOK-IDENTICAL")
  end
end
