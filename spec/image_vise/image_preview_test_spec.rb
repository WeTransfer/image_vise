require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::RenderEngine do
  include Rack::Test::Methods

  let(:app) { ImageVise::RenderEngine.new }

  context 'preview image file size tests' do

    before :each do
      parsed_url = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(parsed_url.host)
    end

    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end

    it 'processes a 1.5mb psd' do
      uri = Addressable::URI.parse(public_url_psd)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('1337ness')

      p = ImageVise::Pipeline.new.geom(geometry_string: 'x220').force_jpg_out(quality: 85)
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('1337ness')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length'].to_i).to be_within(1000).of(58000)
      expect(last_response.status).to eq(200)
    end

    it 'converts a PNG into a JPG applying a background fill' do
      uri = Addressable::URI.parse(public_url_png_transparency)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('h00ray')

      p = ImageVise::Pipeline.new.background_fill(color: 'white').geom(geometry_string: 'x220').force_jpg_out(quality: 5)
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('h00ray')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length'].to_i).to be_within(100).of(1000)
      expect(last_response.status).to eq(200)
    end

  end

end
