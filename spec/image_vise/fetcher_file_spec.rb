require_relative '../spec_helper'

describe ImageVise::FetcherFile do
  it 'is a class (can be inherited from)' do
    expect(ImageVise::FetcherFile).to be_kind_of(Class)
  end
  
  it 'returns a Tempfile containing this test suite' do
    path = File.expand_path(__FILE__)
    ruby_files_in_this_directory = __dir__ + '/*.rb'
    ImageVise.allow_filesystem_source! ruby_files_in_this_directory
    
    uri = URI('file://' + URI.encode(path))
    fetched = ImageVise::FetcherFile.fetch_uri_to_tempfile(uri)

    expect(fetched).to be_kind_of(Tempfile)
    expect(fetched.size).to eq(File.size(__FILE__))
    expect(fetched.pos).to be_zero
  end

  it 'raises a meaningful exception if no file sources are permitted' do
    path = File.expand_path(__FILE__)

    ImageVise.deny_filesystem_sources!

    uri = URI('file://' + URI.encode(path))
    expect {
      ImageVise::FetcherFile.fetch_uri_to_tempfile(uri)
    }.to raise_error(ImageVise::FetcherFile::AccessError)
  end
  
  it 'raises a meaningful exception if this file is not permitted as source' do
    path = File.expand_path(__FILE__)

    text_files_in_this_directory = __dir__ + '/*.txt'
    ImageVise.deny_filesystem_sources!
    ImageVise.allow_filesystem_source! text_files_in_this_directory

    uri = URI('file://' + URI.encode(path))
    expect {
      ImageVise::FetcherFile.fetch_uri_to_tempfile(uri)
    }.to raise_error(ImageVise::FetcherFile::AccessError)
  end
end
