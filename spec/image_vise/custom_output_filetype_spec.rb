require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::CustomOutputFiletype do
  include Rack::Test::Methods

  let(:app) { ImageVise::RenderEngine.new }

  context 'pre export tests' do
    it "adds metadata to the image" do
      image = Magick::Image.read(test_image_path)[0]
      image["image_vise_config_data"] = Hash.new.to_json
      filetype = "jpg"
      described_class.new.apply!(image,filetype)

      config_hash = JSON.parse(image["image_vise_config_data"])
      expect(config_hash["filetype"]).to eq("jpg")
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

    it 'exports a jpg' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('f1letype')

      p = ImageVise::Pipeline.new.custom_output_filetype(filetype: 'jpg').geom(geometry_string: 'x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('f1letype')
      examine_image_from_string(last_response.body)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.status).to eq(200)
    end
  end
end
