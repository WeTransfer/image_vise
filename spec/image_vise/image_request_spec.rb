require 'spec_helper'

describe ImageVise::ImageRequest do
  it 'accepts a set of params and secrets, and returns a Pipeline' do
    img_params = {src_url: 'http://bucket.s3.aws.com/image.jpg', pipeline: [[:crop, {width: 10, height: 10, gravity: 's'}]]}
    img_params_json = JSON.dump(img_params)
    
    q = Base64.encode64(img_params_json)
    sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', q)

    image_request = described_class.from_params(
      base64_encoded_params: q,
      given_signature: sig,
      secrets: ['this is a secret']
    )
    expect(image_request).to be_kind_of(described_class)
  end

  it 'converts a file:// URL into a URI object' do
    img_params = {src_url: 'file:///etc/passwd', pipeline: [[:auto_orient, {}]]}
    img_params_json = JSON.dump(img_params)
    q = Base64.encode64(img_params_json)
    sig = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', q)
    image_request = described_class.from_params(
      base64_encoded_params: q,
      given_signature: sig,
      secrets: ['this is a secret']
    )
    expect(image_request.src_url).to be_kind_of(URI)
  end

  it 'composes path parameters' do
    parametrized = double(to_params: {foo: 'bar'})
    uri = URI('http://example.com/image.psd')
    image_request = described_class.new(src_url: uri, pipeline: parametrized)
    path = image_request.to_path_params('password')
    expect(path).to start_with('/eyJwaXB')
    expect(path).to end_with('f207b')
  end

  it 'never apppends "="-padding to the Base64-encoded "q"' do
    parametrized = double(to_params: {foo: 'bar'})
    (1..12).each do |num_chars_in_url|
      uri = URI('http://ex.com/%s'  % ('i' * num_chars_in_url))
      image_request = described_class.new(src_url: uri, pipeline: parametrized)
      q = image_request.to_path_params('password')
      expect(q).not_to include('=')
    end
  end

  describe 'fails with an invalid signature' do
    it 'when the sig is invalid' do
      img_params = {src_url: 'http://bucket.s3.aws.com/image.jpg',
          pipeline: [[:crop, {width: 10, height: 10, gravity: 's'}]]}
      img_params_json = JSON.dump(img_params)
      enc = Base64.encode64(img_params_json)
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'a', enc)
      
      expect {
        described_class.from_params(base64_encoded_params: enc, given_signature: signature, secrets: ['b'])
      }.to raise_error(/Invalid or missing signature/)
    end
  end
end
