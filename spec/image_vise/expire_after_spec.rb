require_relative '../spec_helper'

describe ImageVise::ExpireAfter do
  it "raises on invalid arguments" do
    expect {
      described_class.new({})
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(seconds: '1')
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(seconds: -1)
    }.to raise_error(ArgumentError)

    expect {
      described_class.new(seconds: 0)
    }.to raise_error(ArgumentError)

    described_class.new(seconds: 25)
  end

  it "sets the :expire_after_seconds metadata key" do
    subject = described_class.new(seconds: 4321)
    
    fake_magick_image = double('Magick::Image')
    metadata = {}

    subject.apply!(fake_magick_image, metadata)

    seconds_value = metadata.fetch(:expire_after_seconds)
    expect(seconds_value).to eq(4321)
  end
end
