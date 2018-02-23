class ImageVise::Pipeline
  def self.operator_by_name(name)
    operator = ImageVise.operator_from(name)  or raise "Unknown operator #{name}"
  end

  def self.from_array_of_operator_params(array_of_operator_names_to_operator_params)
    operators = array_of_operator_names_to_operator_params.map do |(operator_name, operator_params)|
      operator_class = operator_by_name(operator_name)
      if operator_params && operator_params.any? && operator_class.method(:new).arity.nonzero?
        operator_class.new(**operator_params)
      else
        operator_class.new
      end
    end
    new(operators)
  end

  def initialize(operators = [])
    @ops = operators.to_a
  end

  def <<(image_operator)
    @ops << image_operator; self
  end

  def empty?
    @ops.empty?
  end

  def method_missing(method_name, *a, &blk)
    operator_builder = ImageVise.operator_from(method_name)
    self << operator_builder.new(*a)
  end
  
  def respond_to_missing?(method_name, *a)
    ImageVise.defined_operators.include?(method_name.to_s)
  end

  def to_params
    @ops.map do |operator|
      operator_name = ImageVise.operator_name_for(operator)
      operator_params = operator.respond_to?(:to_h) ? operator.to_h : {}
      [operator_name, operator_params]
    end
  end

  def apply!(magick_image, image_metadata)
    @ops.each do |operator|
      apply_operator_passing_metadata(magick_image, operator, image_metadata)
    end
  end

  def apply_operator_passing_metadata(magick_image, operator, image_metadata)
    if operator.method(:apply!).arity == 1
      operator.apply!(magick_image)
    else
      operator.apply!(magick_image, image_metadata)
    end
  end
end
