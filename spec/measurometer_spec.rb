require 'spec_helper'

describe ImageVise::Measurometer do
  RSpec::Matchers.define :include_counter_or_measurement_named do |named|
    match do |actual|
      actual.any? do |e|
        e[0] == named && e[1] > 0
      end
    end
  end

  it 'instruments a full cycle FormatParser.parse' do
    driver_class = Class.new do
      attr_accessor :timings, :counters, :distributions
      def initialize
        @timings = []
        @distributions = []
        @counters = []
      end

      def instrument(block_name)
        s = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield.tap do
          delta = Process.clock_gettime(Process::CLOCK_MONOTONIC) - s
          @timings << [block_name, delta * 1000]
        end
      end

      def add_distribution_value(value_path, value)
        @distributions << [value_path, value]
      end

      def increment_counter(value_path, value)
        @counters << [value_path, value]
      end
    end

    instrumenter = driver_class.new
    described_class.drivers << instrumenter

    builder = ImageVise::Pipeline.new
    pipeline = builder.
      auto_orient.
      fit_crop(width: 48, height: 48, gravity: 'c').
      sharpen(radius: 2, sigma: 0.5).
      ellipse_stencil.
      strip_metadata

    image = Magick::Image.read(test_image_path)[0]
    pipeline.apply! image, {}

    described_class.drivers.delete(instrumenter)
    expect(described_class.drivers).not_to include(instrumenter)

    expect(instrumenter.timings).to include_counter_or_measurement_named('image_vise.op.AutoOrient')
    expect(instrumenter.timings).to include_counter_or_measurement_named('image_vise.op.StripMetadata')
  end
end
