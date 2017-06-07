require_relative '../spec_helper'

describe ImageVise::ForceJPGOut do
  it "raises on invalid arguments" do
    expect {
      described_class.new({})
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(quality: '1')
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(quality: -1)
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(quality: 'very very low')
    }.to raise_error(ArgumentError)

    described_class.new(quality: 25)
  end

  it "sets the :writer metadata key to a JPGWriter" do
    subject = described_class.new(quality: 25)
    
    fake_magick_image = double('Magick::Image')
    metadata = {}

    subject.apply!(fake_magick_image, metadata)

    w = metadata.fetch(:writer)
    expect(w).to be_kind_of(ImageVise::JPGWriter)
    expect(w.quality).to eq(25)
  end
end
