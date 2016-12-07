# Applies an elliptic stencil around the entire image. The stencil will fit inside the image boundaries,
# with about 1 pixel cushion on each side to provide smooth anti-aliased edges. If the input image to be
# provessed is square, the ellipse will turn into a neat circle.
#
# This adds an alpha channel to the image being processed (and premultiplies the RGB channels by it). This
# will force the RenderEngine to return the processed image as a PNG in all cases, instead of keeping it
# in the original format.
#
# The corresponding Pipeline method is `ellipse_stencil`.
class ImageVise::EllipseStencil
  C_black = 'black'.freeze
  private_constant :C_black

  def apply!(magick_image)
    # http://stackoverflow.com/a/13329959/153886
    width, height = magick_image.columns, magick_image.rows
    
    # Generate a black and white image for the stencil
    circle_img = Magick::Image.new(width, height)
    _draw(circle_img, width, height)
    
    mask = circle_img.negate
    mask.alpha(Magick::DeactivateAlphaChannel)
    
    # Retain the alpha in a separate image
    only_alpha = magick_image.copy
    
    # With this composite op, enabling alpha on the destination image is
    # not required - it will be enabled automatically
    magick_image.composite!(mask, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
  ensure
    [mask, only_alpha, circle_img].each do |maybe_image|
      ImageVise.destroy(maybe_image)
    end
  end
  
  def _draw(into_image, width, height)
    center_x = (width / 2.0)
    center_y = (height / 2.0)
    # Make sure all the edges are anti-aliased
    radius_width = center_x - 1.5
    radius_height = center_y - 1.5

    gc = Magick::Draw.new
    gc.fill C_black
    gc.ellipse(center_x, center_y, radius_width, radius_height, deg_start=0, deg_end=360)
    gc.draw(into_image)
  ensure
    ImageVise.destroy(gc)
  end
  
  ImageVise.add_operator 'ellipse_stencil', self
end
