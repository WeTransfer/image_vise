require 'spec_helper'

describe ImageVise::JPGWriter do
  it 'writes out a file with alpha as a JPEG regardless' do
    sample_image = Magick::Image.read(test_image_png_transparency).first
    tf = Tempfile.new 'outt'
    
    described_class.new(quality: 75).write_image!(sample_image, metadata=nil, tf.path)
    
    tf.rewind
    expect(tf.size).not_to be_zero
    fmt = MagicBytes.read_and_detect(tf)
    expect(fmt.ext).to eq('jpg')
  end
  
  it 'honors the JPEG compression quality setting, producing a smaller file with smaller quality' do
    sample_image = Magick::Image.read(test_image_path_tif).first
    
    tf_hi = Tempfile.new 'hi'
    tf_lo = Tempfile.new 'lo'
    
    described_class.new(quality: 50).write_image!(sample_image, metadata=nil, tf_hi.path)
    described_class.new(quality: 10).write_image!(sample_image, metadata=nil, tf_lo.path)
    
    tf_hi.rewind
    tf_lo.rewind
    
    expect(tf_hi.size).not_to be_zero
    expect(tf_lo.size).not_to be_zero
    expect(tf_lo.size).to be < tf_hi.size
  end
end
