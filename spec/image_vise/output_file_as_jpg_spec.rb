require 'spec_helper'

describe ImageVise::OutputFileAsJpg do
  it "adds metadata to the image" do
    image = Magick::Image.read(test_image_path)[0]
    described_class.new.apply!(image)

    expect(image["render_as"]).to eq("jpg")
  end
end
