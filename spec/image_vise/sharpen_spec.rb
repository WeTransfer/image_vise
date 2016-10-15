require 'spec_helper'

describe ImageVise::Sharpen do
  it 'refuses invalid parameters' do
    expect { described_class.new(sigma: 0, radius: -1) }.to raise_error(ArgumentError)
  end
  
  it 'applies the crop with different gravities' do
    [[1, 1], [4, 2], [0.75, 0.5]].each do |(r, s)|
      image = Magick::Image.read(test_image_path)[0]
      expect(ImageVise).to receive(:destroy).with(instance_of(Magick::Image)).and_call_original
      sharpen = described_class.new(radius: r, sigma: s)
      sharpen.apply!(image)
      examine_image(image, "sharpen-rad_%02f-sigma_%02f" % [r, s])
    end
  end
end
