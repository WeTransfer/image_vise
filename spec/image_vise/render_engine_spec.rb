require_relative '../spec_helper'
require 'rack/test'

describe ImageVise::RenderEngine do
  include Rack::Test::Methods
  
  let(:app) { ImageVise::RenderEngine.new }

  context 'when the subclass is configured to raise exceptions' do
    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end
    
    it 'raises an exception instead of returning an error response' do
      class << app
        def raise_exceptions?
          true
        end
      end
      
      p = ImageVise::Pipeline.new.crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: 'http://unknown.com/image.jpg', pipeline: p)
      expect(app).to receive(:handle_generic_error).and_call_original
      expect {
        get image_request.to_path_params('l33tness')
      }.to raise_error(/No keys set/)
    end
  end

  context 'when requesting an image' do
    before :each do
      parsed_url = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(parsed_url.host)
    end

    after :each do
      ImageVise.reset_allowed_hosts!
      ImageVise.reset_secret_keys!
    end
    
    it 'halts with 422 when the requested image cannot be opened by ImageMagick' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')
      uri.path = '/___nonexistent_image.jpg'
      
      p = ImageVise::Pipeline.new.crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)
      
      expect_any_instance_of(Patron::Session).to receive(:get_file) {|_self, url, path|
        File.open(path, 'wb') {|f| f << 'totally not an image' }
        double(status: 200)
      }
      expect(app).to receive(:handle_request_error).and_call_original
      
      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(422)
      expect(last_response['Cache-Control']).to eq("private, max-age=0, no-cache")
      expect(last_response.body).to include('Unsupported/unknown')
    end

    it 'halts with 422 when a file:// URL is given and filesystem access is not enabled' do
      uri = 'file://' + test_image_path
      ImageVise.deny_filesystem_sources!
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(403)
      expect(last_response.body).to include('filesystem access is disabled')
    end
    
    it 'responds with 403 when upstream returns it, and includes the URL in the error message' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')
      uri.path = '/forbidden'

      p = ImageVise::Pipeline.new.crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(403)
      expect(last_response.headers['Content-Type']).to eq('application/json')
      parsed = JSON.load(last_response.body)
      expect(parsed['errors'].to_s).to include("Unfortunate upstream response")
      expect(parsed['errors'].to_s).to include(uri.to_s)
    end
    
    it 'replays upstream error response codes that are selected to be replayed to the requester' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')
      
      [404, 403, 503, 504, 500].each do | error_code |
        allow_any_instance_of(Patron::Session).to receive(:get_file).and_return(double(status: error_code))
        
        p = ImageVise::Pipeline.new.crop(width: 10, height: 10, gravity: 'c')
        image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)
        
        get image_request.to_path_params('l33tness')

        expect(last_response.status).to eq(error_code)
        expect(last_response.headers).to have_key('Cache-Control')
        expect(last_response.headers['Cache-Control']).to eq("private, max-age=0, no-cache")
        
        expect(last_response.headers['Content-Type']).to eq('application/json')
        parsed = JSON.load(last_response.body)
        expect(parsed['errors'].to_s).to include("Unfortunate upstream response")
      end
    end
    
    it 'sets very far caching headers and an ETag, and returns a 304 if any ETag is set' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')
      
      p = ImageVise::Pipeline.new.fit_crop(width: 10, height: 35, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)
      
      req_path = image_request.to_path_params('l33tness')
      
      get req_path, {}
      expect(last_response).to be_ok
      expect(last_response['ETag']).not_to be_nil
      expect(last_response['Cache-Control']).to match(/public/)
      
      get req_path, {}, {'HTTP_IF_NONE_MATCH' => last_response['ETag']}
      expect(last_response.status).to eq(304)
      
      # Should consider _any_ ETag a request to rerender something
      # that already exists in an upstream cache
      get req_path, {}, {'HTTP_IF_NONE_MATCH' => SecureRandom.hex(4)}
      expect(last_response.status).to eq(304)
    end
    
    it 'when all goes well responds with an image that passes through all the processing steps' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '512x335').fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)

      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
      expect(last_response.headers).to have_key('Content-Length')
      parsed_image = Magick::Image.from_blob(last_response.body)[0]
      expect(parsed_image.columns).to eq(10)
    end

    it 'calls all of the internal methods during execution' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '512x335').fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)
      params = image_request.to_query_string_params('l33tness')

      expect(app).to receive(:parse_env_into_request).and_call_original
      expect(app).to receive(:process_image_request).and_call_original
      expect(app).to receive(:image_rack_response).and_call_original
      expect(app).to receive(:source_file_type_permitted?).and_call_original
      expect(app).to receive(:output_file_type_permitted?).and_call_original
      expect(app).to receive(:enable_forking?).and_call_original

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)
    end
    
    it 'picks the image from the filesystem if that is permitted' do
      uri = 'file://' + test_image_path
      ImageVise.allow_filesystem_source!(File.dirname(test_image_path) + '/*.*')
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
    end

    it 'expands and forbids a path outside of the permitted sources'

    it 'URI-decodes the path in a file:// URL for a file with a Unicode path' do
      utf8_file_path = File.dirname(test_image_path) + '/картинка.jpg'
      FileUtils.cp_r(test_image_path, utf8_file_path)
      uri = 'file://' + URI.encode(utf8_file_path)
      
      ImageVise.allow_filesystem_source!(File.dirname(test_image_path) + '/*.*')
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      File.unlink(utf8_file_path)
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('image/jpeg')
    end

    it 'forbids a request with an extra GET param' do
      uri = 'file://' + URI.encode(test_image_path)

      p = ImageVise::Pipeline.new.fit_crop(width: 10, height: 10, gravity: 'c')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness'), {'extra' => '123'}

      expect(last_response.status).to eq(400)
    end

    it 'returns the processed JPEG image as a PNG if it had to get an alpha channel during processing' do
      uri = Addressable::URI.parse(public_url)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220').ellipse_stencil
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)

      expect(last_response.headers['Content-Type']).to eq('image/png')
      expect(last_response.headers).to have_key('Content-Length')

      examine_image_from_string(last_response.body)
    end

    it 'forbids a PSD file by default' do
      uri = Addressable::URI.parse(public_url_psd)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220').ellipse_stencil
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('unknown input file format .psd')
    end

    it 'permits a PSD file if it is permitted via a method override' do
      uri = Addressable::URI.parse(public_url_psd)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      class << app
        def source_file_type_permitted?(type); true; end
      end

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('image/png')
    end
    
    it 'destroys all the loaded PSD layers' do
      uri = Addressable::URI.parse(public_url_psd_multilayer)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      class << app
        def source_file_type_permitted?(type); true; end
        def raise_exceptions?; true; end
      end

      # For each layer loaded into the ImageList
      expect(ImageVise).to receive(:destroy).and_call_original.exactly(5).times
      
      get image_request.to_path_params('l33tness')
      
      expect(last_response.status).to eq(200)
    end
    
    it 'outputs a converted TIFF file as a PNG' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)

      class << app
        def source_file_type_permitted?(type); true; end
      end

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('image/png')
    end
    
    it 'outputs a converted TIFF file in the TIFF format if it is on the permitted list' do
      uri = Addressable::URI.parse(public_url_tif)
      ImageVise.add_allowed_host!(uri.host)
      ImageVise.add_secret_key!('l33tness')

      p = ImageVise::Pipeline.new.geom(geometry_string: '220x220')
      image_request = ImageVise::ImageRequest.new(src_url: uri.to_s, pipeline: p)
      

      class << app
        def source_file_type_permitted?(type); true; end
        def output_file_type_permitted?(type); true; end
      end

      get image_request.to_path_params('l33tness')
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('image/tiff')
    end
  end
end
