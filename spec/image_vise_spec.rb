require_relative 'spec_helper'
require 'rack/test'

describe ImageVise do
  include Rack::Test::Methods

  def app
    described_class.new
  end

  context 'ImageVise.allowed_hosts' do
    it 'returns the allowed hosts and is empty by default' do
      expect(described_class.allowed_hosts).to be_empty
    end

    it 'allows add_allowed_host! and reset_allowed_hosts!' do
      described_class.add_allowed_host!('www.imageboard.im')
      expect(described_class.allowed_hosts).to include('www.imageboard.im')
      described_class.reset_allowed_hosts!
      expect(described_class.allowed_hosts).not_to include('www.imageboard.im')
    end
  end

  context 'ImageVise.secret_keys' do
    it 'raises when asked for a key and no keys has been set' do
      expect {
        described_class.secret_keys
      }.to raise_error("No keys set, add a key using `ImageVise.add_secret_key!(key)'")
    end

    it 'allows add_secret_key!(key) and reset_secret_keys!' do
      described_class.add_secret_key!('l33t')
      expect(described_class.secret_keys).to include('l33t')
      described_class.reset_secret_keys!
      expect {
        expect(described_class.secret_keys)
      }.to raise_error(/add a key using/)
    end
  end

  context 'ImageVise.cache_lifetime_seconds=' do
    it 'raises when given something other than an integer' do
      expect {
        described_class.cache_lifetime_seconds = "Wh0ops!"
      }.to raise_error("The custom cache lifetime value must be an integer")
    end

    it 'succeeds when given an integer' do
      expect {
        described_class.cache_lifetime_seconds=(900)
      }.not_to raise_error
    end
  end

  context 'ImageVise.cache_lifetime_seconds' do
    it 'allows cache_lifetime_seconds to be set' do
      described_class.cache_lifetime_seconds = 100
      expect(described_class.cache_lifetime_seconds).to eq(100)
    end

    it 'allows reset_cache_lifetime_seconds!' do
      described_class.cache_lifetime_seconds = 100
      expect(described_class.cache_lifetime_seconds).to eq(100)
      described_class.reset_cache_lifetime_seconds!
      expect(described_class.cache_lifetime_seconds).to eq(2592000)
    end
  end

  describe 'ImageVise.new.call' do
    it 'instantiates a new app and performs call() on it' do
      expect_any_instance_of(ImageVise::RenderEngine).to receive(:call).with(:mock_env) { :yes }
      ImageVise.new.call(:mock_env)
    end
  end

  describe 'ImageVise.call' do
    it 'instantiates a new app and performs call() on it' do
      expect_any_instance_of(ImageVise::RenderEngine).to receive(:call).with(:mock_env) { :yes }
      ImageVise.call(:mock_env)
    end
  end

  describe 'methods dealing with fetchers' do
    it 'returns the fetchers for the default schemes' do
      http = ImageVise.fetcher_for('http')
      expect(http).to respond_to(:fetch_uri_to_tempfile)
      file = ImageVise.fetcher_for('file')
      expect(http).to respond_to(:fetch_uri_to_tempfile)

      expect {
        ImageVise.fetcher_for('undernet')
      }.to raise_error(/No fetcher registered/)
    end
  end

  describe '.image_path' do
    it 'returns the path to the image within the application' do
      path = ImageVise.image_path(src_url: 'file://tmp/img.jpg', secret: 'a') do |p|
        p.ellipse_stencil
      end
      expect(path).to start_with('/')
    end
  end

  describe '.close_and_unlink' do
    it 'closes and unlinks a Tempfile' do
      tf = Tempfile.new
      tf << "foo"
      expect(tf).to receive(:close).and_call_original
      expect(tf).to receive(:unlink).and_call_original

      ImageVise.close_and_unlink(tf)

      expect(tf).to be_closed
    end

    it 'unlinks a closed Tempfile' do
      tf = Tempfile.new
      tf << "foo"
      tf.close
      expect(tf).to receive(:unlink).and_call_original

      ImageVise.close_and_unlink(tf)
    end

    it 'works on a nil since it gets used in ensure blocks, where the variable might be empty' do
      ImageVise.close_and_unlink(nil) # Should not raise anything
    end

    it 'works for a StringIO which does not have unlink' do
      sio = StringIO.new('some gunk')
      expect(sio).not_to be_closed
      ImageVise.close_and_unlink(sio)
      expect(sio).to be_closed
    end
  end

  describe 'methods dealing with the operator list' do
    it 'have the basic operators already set up' do
      oplist = ImageVise.defined_operator_names
      expect(oplist).to include('sharpen')
      expect(oplist).to include('crop')
    end

    it 'allows an operator to be added and retrieved' do
      class CustomOp; end
      ImageVise.add_operator 'custom_op', CustomOp
      expect(ImageVise.operator_from(:custom_op)).to eq(CustomOp)
      expect(ImageVise.operator_name_for(CustomOp.new)).to eq('custom_op')
      expect(ImageVise.defined_operator_names).to include('custom_op')
    end

    it 'raises an exception when an operator key is requested that does not exist' do
      class UnknownOp; end
      expect {
        ImageVise.operator_name_for(UnknownOp.new)
      }.to raise_error(/not registered using ImageVise/)
    end
  end
end
