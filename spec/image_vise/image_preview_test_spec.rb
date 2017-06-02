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

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('1337ness')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("60000","75000").inclusive
      expect(last_response.status).to eq(200)
    end

    it 'safely converts a png into a jpg' do
      uri = Addressable::URI.parse(public_url_png_transparency)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('h00ray')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').background_fill(color: 'white').geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('h00ray')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("10000","11000").inclusive
      expect(last_response.status).to eq(200)
    end

  end

end
