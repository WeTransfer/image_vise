require 'spec_helper'

describe ImageVise::AutoOrient do
  it 'applies auto orient to the image' do
    image = Magick::Image.read(test_image_path)[0]
    orient = described_class.new
    expect(image).to receive(:auto_orient!).and_call_original
    orient.apply!(image)
  end
end
