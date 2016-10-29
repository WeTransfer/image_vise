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
      }.to raise_error
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
  
  describe '.image_params' do
    it 'generates a Hash with paremeters for processing the resized image' do
      params = ImageVise.image_params(src_url: 'http://host.com/image.jpg', secret: 'l33t') do |pipe|
        pipe.fit_crop width: 128, height: 256, gravity: 'c'
      end
      expect(params).to be_kind_of(Hash)
      expect(params[:q]).not_to be_empty
      expect(params[:sig]).not_to be_empty
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
