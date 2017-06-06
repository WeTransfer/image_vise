require_relative '../spec_helper'

describe ImageVise::BackgroundFill do

  it 'refuses empty parameters' do
    expect { described_class.new(color:"") }.to raise_error(ArgumentError)
  end

  it 'successfully exports a png with a fill' do
    image = Magick::Image.read(test_image_png_transparency)[0]
    expect(image).to be_alpha
    background_fill = described_class.new(color: 'white')
    background_fill.apply!(image)
    expect(image).to_not be_alpha
    examine_image(image, "set-color-to-white")
  end

  it 'can be passed various colors' do
    image = Magick::Image.read(test_image_png_transparency)[0]
    background_fill = described_class.new(color: 'green')
    background_fill.apply!(image)
    examine_image(image, "set-color-to-green")
  end

  it 'can be passed hex colors' do
    image = Magick::Image.read(test_image_png_transparency)[0]
    background_fill = described_class.new(color: '#ffebcd')
    background_fill.apply!(image)
    examine_image(image, "set-color-to-blanched-almond")
  end

end
