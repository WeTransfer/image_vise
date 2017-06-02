require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::BackgroundFill do
  include Rack::Test::Methods

  let(:app) { ImageVise::RenderEngine.new }

  context 'export tests' do

    before :each do
      parsed_url = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(parsed_url.host)
    end

    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end

    it 'successfully exports a png as a jpg' do
      uri = Addressable::URI.parse(public_url_png_transparency)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.background_fill(color: 'white').geom(geometry_string: 'x600').output_file_as_jpg
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.status).to eq(200)
    end

    it 'can be passed various colors' do
      uri = Addressable::URI.parse(public_url_png_transparency)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('gr33n')

      p = ImageVise::Pipeline.new.background_fill(color: 'green').geom(geometry_string: 'x600').output_file_as_jpg
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('gr33n')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.status).to eq(200)
    end

    it 'can be passed hex colors' do
      uri = Addressable::URI.parse(public_url_png_transparency)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('blanchedalm0nd')

      p = ImageVise::Pipeline.new.background_fill(color: '#ffebcd').geom(geometry_string: 'x600').output_file_as_jpg
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('blanchedalm0nd')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.status).to eq(200)
    end

  end
end
