require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::JpgQuality do
  include Rack::Test::Methods

  let(:app) { ImageVise::RenderEngine.new }

  context 'pre export tests' do
    it "adds metadata to the image" do
      image = Magick::Image.read(test_image_path)[0]
      image["image_vise_config_data"] = Hash.new.to_json
      custom_filetype = described_class.new(jpg_quality: "80")
      custom_filetype.apply!(image)

      config_hash = JSON.parse(image["image_vise_config_data"])
      expect(config_hash["jpg_quality"]).to eq("80")
    end

    it "rejects invalid extensions" do
      expect { described_class.new(jpg_quality: "-1") }.to raise_error(ArgumentError)
      expect { described_class.new(jpg_quality: "101") }.to raise_error(ArgumentError)
    end

  end

  context 'export tests' do

    before :each do
      parsed_url = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(parsed_url.host)
    end

    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end

    it 'exports a jpg at quality 30' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').jpg_quality(jpg_quality: 30).geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("25000","30000")
      expect(last_response.status).to eq(200)
    end

    it 'exports a jpg at quality 100' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').jpg_quality(jpg_quality: 100).geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("55000","60000")
      expect(last_response.status).to eq(200)
    end

    it 'exports a jpg at quality 1' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').jpg_quality(jpg_quality: 1).geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("25000","26000")
      expect(last_response.status).to eq(200)
    end

    it 'handles and rounds floats' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').jpg_quality(jpg_quality: 48.15162342).geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers['Content-Length']).to be_between("27000","30000")
      expect(last_response.status).to eq(200)
    end
  end
end
