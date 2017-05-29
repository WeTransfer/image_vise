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
    opset = ImageVise::Pipeline.new([
      described_class.new,
    ])
    image = Magick::Image.read(test_image_mismatched_colorspace_profile_path).first
    examine_image(image, 'pre-mismatched-colors')
    opset.apply!(image)
    examine_image(image, 'post-mismatched-colors')
  end

  describe '#validate_color_profile' do
    let(:opset) { ImageVise::Pipeline.new([described_class.new,]) }

    it 'strips the image\'s profile if the profile and colorspace are non-matching' do
      non_matching_image = Magick::Image.read(test_image_mismatched_colorspace_profile_path).first
      expect(non_matching_image).to receive(:strip!).and_call_original
      opset.apply!(non_matching_image)
    end

    it 'does not strip the image\'s profile if the profile and colorspace are matching' do
      matching_srgb_image = Magick::Image.read(test_image_path).first
      expect(matching_srgb_image).to_not receive(:strip!)
      opset.apply!(matching_srgb_image)
    end

    it 'does not strip the profile for an image with sRGB colorspace and AdobeRGB profile' do
      non_matching_adobergb_image = Magick::Image.read(test_image_adobergb_path).first
      expect(non_matching_adobergb_image).to_not receive(:strip!)
      opset.apply!(non_matching_adobergb_image)
    end
  end
end
