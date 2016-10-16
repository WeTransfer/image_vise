require 'spec_helper'

describe ImageVise::Geom do
  it 'refuses invalid parameters' do
    expect { described_class.new(geometry_string: nil) }.to raise_error(ArgumentError)
  end

  it 'fits to height' do
    image = Magick::Image.read(test_image_path)[0]
    crop = described_class.new(geometry_string: 'x200')
    crop.apply!(image)
    expect(image.rows).to eq(200)
    examine_image(image, 'fit-height-200')
  end

  it 'fits to width' do
    image = Magick::Image.read(test_image_path)[0]
    crop = described_class.new(geometry_string: '100x')
    crop.apply!(image)
    expect(image.columns).to eq(100)
    examine_image(image, 'fit-width-100')
  end

  it 'applies various geometry strings' do
    %w( ^220x110 !20x20 !10x100 ).each do |geom_string|
      image = Magick::Image.read(test_image_path)[0]
      crop = described_class.new(geometry_string: geom_string)

      crop.apply!(image)
      examine_image(image, 'geom-%s' % geom_string)
    end
  end
end
