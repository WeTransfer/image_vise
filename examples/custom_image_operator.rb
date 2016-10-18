class MyBlur
  # The constructor must accept keyword arguments if your operator accepts them
  def initialize(radius:, sigma:)
    @radius = radius.to_f
    @sigma = sigma.to_f
  end
  
  # Needed for the operator to be serialized to parameters
  def to_h
    {radius: @radius, sigma: @sigma}
  end
  
  def apply!(magick_image) # The argument is a Magick::Image
    # Apply the method to the function argument
    blurred_image = magick_image.blur_image(@radius, @sigma)
    
    # Some methods (without !) return a new Magick::Image.
    # That image has to be composited back into the original.
    magick_image.composite!(blurred_image, Magick::CenterGravity, Magick::CopyCompositeOp)
  ensure
    # Make sure to explicitly destroy() all the intermediate images
    ImageVise.destroy(blurred_image)
  end
end

# This will also make `ImageVise::Pipeline` respond to `blur(radius:.., sigma:..)`
ImageVise.add_operator 'my_blur', MyBlur
