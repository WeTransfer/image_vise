require 'spec_helper'

describe ImageVise::ImageRequest do
  it 'accepts a set of params and secrets, and returns a Pipeline' do
    img_params = {src_url: 'http://bucket.s3.aws.com/image.jpg', pipeline: [[:crop, {width: 10, height: 10, gravity: 's'}]]}
    img_params_json = JSON.dump(img_params)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', img_params_json)
    params = {
      q: Base64.encode64(img_params_json),
      sig: signature
    }

    image_request = described_class.to_request(qs_params: params, secrets: ['this is a secret'])
    request_qs_params = image_request.to_query_string_params('this is a secret')
    expect(request_qs_params).to be_kind_of(Hash)

    image_request_roundtrip = described_class.to_request(qs_params: request_qs_params, secrets: ['this is a secret'])
  end

  it 'converts a file:// URL into a URI objectlist' do
    img_params = {src_url: 'file:///etc/passwd', pipeline: [[:auto_orient, {}]]}
    img_params_json = JSON.dump(img_params)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', img_params_json)
    params = {
      q: Base64.encode64(img_params_json),
      sig: signature
    }
    image_request = described_class.to_request(qs_params: params, secrets: ['this is a secret'])
    expect(image_request.src_url).to be_kind_of(URI)
  end

  describe 'fails with an invalid pipeline' do
    it 'when the pipe param is missing'
    it 'when the pipe param is empty'
    it 'when the pipe param cannot be parsed into a Pipeline'
    it 'when the pipe param parses into a Pipeline with zero operators'
  end

  describe 'fails with an invalid URL' do
    it 'when the URL param is missing'
    it 'when the URL param is empty'
  end

  describe 'fails with an invalid signature' do
    it 'when the sig param is missing'
    it 'when the sig param is empty'
    it 'when the sig is invalid' do
      img_params = {src_url: 'http://bucket.s3.aws.com/image.jpg',
          pipeline: [[:crop, {width: 10, height: 10, gravity: 's'}]]}
      img_params_json = JSON.dump(img_params)
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'a', img_params_json)
      params = {
        q: Base64.encode64(img_params_json),
        sig: signature
      }
      
      expect {
        described_class.to_request(qs_params: params, secrets: ['b'])
      }.to raise_error(/Invalid or missing signature/)
    end
  end
end
