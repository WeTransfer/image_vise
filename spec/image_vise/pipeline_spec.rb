require 'spec_helper'

describe ImageVise::Pipeline do
  it 'is empty by default' do
    expect(subject).to be_empty
  end
  
  it 'reinstates the pipeline from the operator list parameters' do
    params = [
      ["geom", {:geometry_string=>"10x10"}],
      ["crop", {:width=>5, :height=>5, :gravity=>"se"}],
      ["auto_orient", {}],
      ["fit_crop", {:width=>10, :height=>32, :gravity=>"c"}]
    ]
    pipeline = described_class.from_param(params)
    expect(pipeline).not_to be_empty
  end

  it 'produces a usable operator parameter list that can be roundtripped' do
    operator_list = subject.geom(geometry_string: '10x10').
      crop(width: 5, height: 5, gravity: 'se').
      auto_orient.
      fit_crop(width: 10, height: 32, gravity: 'c').to_params
    
    expect(operator_list).to eq([
      ["geom", {:geometry_string=>"10x10"}],
      ["crop", {:width=>5, :height=>5, :gravity=>"se"}],
      ["auto_orient", {}],
      ["fit_crop", {:width=>10, :height=>32, :gravity=>"c"}]
    ])

    pipeline = described_class.from_param(operator_list)
    expect(pipeline).not_to be_empty
  end
  
  it 'applies itself to the image' do
    pipeline = subject.
      auto_orient.
      fit_crop(width: 48, height: 48, gravity: 'c').
      srgb.
      sharpen(radius: 2, sigma: 0.5).
      ellipse_stencil.
      strip_metadata
    
    image = Magick::Image.read(test_image_path)[0]
    pipeline.apply! image
    examine_image(image, "stenciled")
  end
  
  it 'raises an exception when an attempt is made to serialize an unknown operator' do
    unknown_op_class = Class.new
    subject << unknown_op_class.new
    expect {
      subject.to_params
    }.to raise_error(/not registered/)
  end

  it 'composes parameters even if one of the operators does not support to_h' do
    class AnonOp
    end
    class ParametricOp
      def to_h; {a: 133}; end
    end
    
    ImageVise.add_operator('t_anon', AnonOp)
    ImageVise.add_operator('t_parametric', ParametricOp)
    
    subject << AnonOp.new
    subject << ParametricOp.new
    expect(subject.to_params).to eq([["t_anon", {}], ["t_parametric", {:a=>133}]])
  end
end
