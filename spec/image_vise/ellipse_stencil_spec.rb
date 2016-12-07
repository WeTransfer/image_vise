require 'spec_helper'

describe ImageVise::EllipseStencil do
  it 'applies the circle stencil' do
    image = Magick::Image.read(test_image_path)[0]
    stencil = described_class.new
    stencil.apply!(image)
    examine_image(image, "circle-stencil")
  end

  it 'applies the circle stencil to a png with transparency' do
    png_transparent_path = File.expand_path(__dir__ + '/../waterside_magic_hour_transp.png')
    image = Magick::Image.read(png_transparent_path)[0]
    stencil = described_class.new
    stencil.apply!(image)
    examine_image(image, "circle-stencil-transparent-bg")
  end

end
