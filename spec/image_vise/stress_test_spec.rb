require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::RenderEngine do
  include Rack::Test::Methods

  let(:app) { ImageVise::RenderEngine.new }

  context 'large file size stress test' do

    before :each do
      parsed_url = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(parsed_url.host)
    end

    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end

    it 'processes a 53mb psd' do
      uri = Addressable::URI.parse(public_url_large_psd)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('showmewhatyougot')

      p = ImageVise::Pipeline.new.geom(geometry_string: '1920x1080')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('showmewhatyougot')
      expect(last_response.status).to eq(200)
    end

  end

end
