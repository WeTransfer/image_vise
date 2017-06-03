require 'spec_helper'

describe ImageVise::AutoWriter do
  it 'writes out a file with alpha as a PNG' do
    sample_image = Magick::Image.read(test_image_png_transparency).first
    tf = Tempfile.new 'outt'
    subject.write_image!(sample_image, metadata=nil, tf.path)
    
    tf.rewind
    expect(tf.size).not_to be_zero
    fmt = MagicBytes.read_and_detect(tf)
    expect(fmt.ext).to eq('png')
  end
  
  it 'writes out a file without alpha as JPEG' do
    sample_image = Magick::Image.read(test_image_path_tif).first
    tf = Tempfile.new 'outt'
    subject.write_image!(sample_image, metadata=nil, tf.path)
    
    tf.rewind
    expect(tf.size).not_to be_zero
    fmt = MagicBytes.read_and_detect(tf)
    expect(fmt.ext).to eq('jpg')
  end
end
