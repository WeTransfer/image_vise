require 'spec_helper'

describe ImageVise::ImageRequest do
  it 'accepts a set of params and secrets, and returns a Pipeline' do
    img_params = {src_url: 'http://bucket.s3.aws.com/image.jpg', pipeline: [[:crop, {width: 10, height: 10, gravity: 's'}]], extension: ".jpg"}
    img_params_json = JSON.dump(img_params)

    q = Base64.encode64(img_params_json)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', q)
    params = {q: q, sig: signature}

    image_request = described_class.from_params(qs_params: params, secrets: ['this is a secret'])
    request_qs_params = image_request.to_query_string_params('this is a secret')
    expect(request_qs_params).to be_kind_of(Hash)

    image_request_roundtrip = described_class.from_params(qs_params: request_qs_params, secrets: ['this is a secret'])
  end

  it 'converts a file:// URL into a URI objectlist' do
    img_params = {src_url: 'file:///etc/passwd', pipeline: [[:auto_orient, {}]], extension: ".foo"}
    img_params_json = JSON.dump(img_params)
    q = Base64.encode64(img_params_json)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, 'this is a secret', q)
    params = {q: q, sig: signature}
    image_request = described_class.from_params(qs_params: params, secrets: ['this is a secret'])
    expect(image_request.src_url).to be_kind_of(URI)
  end

  it 'composes path parameters' do
    parametrized = double(to_params: {foo: 'bar'})
    uri = URI('http://example.com/image.psd')
    image_request = described_class.new(src_url: uri, pipeline: parametrized, extension: ".psd")
    path = image_request.to_path_params('password')
    expect(path).to start_with('/eyJwaXB')
    expect(path).to end_with('1cfb9')
  end

  it 'never apppends "="-padding to the Base64-encoded "q"' do
    parametrized = double(to_params: {foo: 'bar'})
    (1..12).each do |num_chars_in_url|
      uri = URI('http://ex.com/%s'  % ('i' * num_chars_in_url))
      image_request = described_class.new(src_url: uri, pipeline: parametrized, extension: ".bar")
      q = image_request.to_query_string_params('password').fetch(:q)
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
      params = {q: enc, sig: signature}

      expect {
        described_class.from_params(qs_params: params, secrets: ['b'])
      }.to raise_error(/Invalid or missing signature/)
    end
  end
end
