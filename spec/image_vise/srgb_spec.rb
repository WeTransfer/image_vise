require 'spec_helper'

describe ImageVise::SRGB do
  it 'applies the profile, creating a perceptible difference with the original' do
    opset = ImageVise::Pipeline.new([
      ImageVise::FitCrop.new(width: 512, height: 512, gravity: 'c'),
      described_class.new,
    ])

    # This test will function only if you have RMagick with LCMS2 support
    # built-in. If you do, the two images will look _very_ much like one
    # another.
    #
    # If you don't, the images will look remarkably different
    # (the AdobeRGB version has color values that match AdobeRGB
    # primaries, and will render diffrently in pretty much any
    # viewer).
    image = Magick::Image.read(test_image_adobergb_path).first
    opset.apply!(image)
    image.strip!
    examine_image(image, "from-adobergb")

    image = Magick::Image.read(test_image_path).first
    opset.apply!(image)
    image.strip!
    examine_image(image, "from-srgb")
  end

  it 'applies the profile for an image with non-matching colorspace and profile' do
    image = Magick::Image.read(test_image_mismatched_colorspace_profile_path).first
    examine_image(image, 'pre-mismatched-colors')
    described_class.new.apply!(image)
    examine_image(image, 'post-mismatched-colors')
  end

  it "strips the image's profile if the profile and colorspace are non-matching" do
    non_matching_image = Magick::Image.read(test_image_mismatched_colorspace_profile_path).first
    expect(non_matching_image).to receive(:strip!).and_call_original
    described_class.new.apply!(non_matching_image)
  end
end
