require_relative '../spec_helper'

describe ImageVise::FileResponse do
  it 'reads the file in binary mode, closes and unlinks the tempfile when close() is called' do
    random_data = Random.new.bytes(1024 * 2048)
    f = Tempfile.new("experiment")
    f.binmode
    f << random_data
    
    response = described_class.new(f)
    readback = ''.encode(Encoding::BINARY)
    response.each do | chunk |
      expect(chunk.encoding).to eq(Encoding::BINARY)
      readback << chunk
    end
    
    response.close
    
    expect(readback).to eq(random_data)
    expect(f).to be_closed
    expect(f.path).to be_nil
  end
  
  it 'only asks for the path of the tempfile and uses a separate file descriptor' do
    f = Tempfile.new("experiment")
    f.binmode
    f << Random.new.bytes(2048)
    f.flush
    
    # Use a double so that all the methods except the ones we mock raise an assertion
    double = double(path: f.path)
    expect(double).to receive(:flush)
    
    read_from_response = ''.encode(Encoding::BINARY)
    response = described_class.new(double)
    response.each{|b| read_from_response << b }
    
    f.rewind
    
    expect(f.read).to eq(read_from_response)
    
    f.close
    f.unlink
  end
end
