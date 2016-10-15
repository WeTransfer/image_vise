require 'spec_helper'

describe ImageVise::Crop do
  it 'refuses invalid parameters' do
    expect { described_class.new(width: 0, height: -1, gravity: '') }.to raise_error(ArgumentError)
  end
  
  it 'applies the crop with different gravities' do
    %w( s sw se n ne nw c).each do |gravity|
      image = Magick::Image.read(test_image_path)[0]
      crop = described_class.new(width: 120, height: 220, gravity: gravity)

      crop.apply!(image)

      expect(image.columns).to eq(120)
      expect(image.rows).to eq(220)
      examine_image(image, "gravity-%s-" % gravity)
    end
  end
end
