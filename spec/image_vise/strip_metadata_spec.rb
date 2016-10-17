require 'spec_helper'

describe ImageVise::StripMetadata do
  it 'applies the strip! method to the image' do
    image = Magick::Image.read(test_image_path).first
    expect(image).to receive(:strip!).and_call_original
    described_class.new.apply!(image)
  end

  it 'is registered with the operator registry' do
    op = ImageVise.operator_from('strip_metadata')
    expect(op).to eq(described_class)
  end
end
