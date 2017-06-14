require_relative '../spec_helper'

describe ImageVise::FetcherHTTP do
  it 'is a class (can be inherited from)' do
    expect(ImageVise::FetcherHTTP).to be_kind_of(Class)
  end

  it 'is registered as a fetcher for http:// and https://' do
    expect(ImageVise.fetcher_for('http')).to eq(ImageVise::FetcherHTTP)
    expect(ImageVise.fetcher_for('https')).to eq(ImageVise::FetcherHTTP)
  end

  it 'raises an AccessError if the host of the URL is not on the whitelist' do
    uri = URI('https://wrong-origin.com/image.psd')
    extension = ".psd"
    expect {
      ImageVise::FetcherHTTP.fetch_uri_to_tempfile(uri,extension)
    }.to raise_error(ImageVise::FetcherHTTP::AccessError, /is not permitted as source/)
  end

  it 'raises an UpstreamError if the upstream fetch returns an error-ish status code' do
    uri = URI('http://localhost:9001/forbidden')
    extension = ".jpg"
    ImageVise.add_allowed_host! 'localhost'

    expect {
      ImageVise::FetcherHTTP.fetch_uri_to_tempfile(uri,extension)
    }.to raise_error {|e|
      expect(e).to be_kind_of(ImageVise::FetcherHTTP::UpstreamError)
      expect(e.message).to include(uri.to_s)
      expect(e.message).to include('403')
      expect(e.http_status).to eq(403)
    }
  end

  it 'fetches the image into a Tempfile' do
    uri = URI(public_url_psd)
    extension = ".psd"
    ImageVise.add_allowed_host! 'localhost'

    result = ImageVise::FetcherHTTP.fetch_uri_to_tempfile(uri,extension)

    expect(result).to be_kind_of(Tempfile)
    expect(result.size).to be_nonzero
    expect(result.pos).to be_zero
  end
end
