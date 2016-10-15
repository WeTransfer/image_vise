require 'spec_helper'

describe ImageVise::EllipseStencil do
  it 'applies the circle stencil' do
    image = Magick::Image.read(test_image_path)[0]
    stencil = described_class.new
    stencil.apply!(image)
    examine_image(image, "circle-stencil")
  end
end