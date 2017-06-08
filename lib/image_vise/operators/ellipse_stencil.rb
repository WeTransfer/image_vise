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
  C_white = 'white'.freeze
  private_constant :C_white, :C_black

  def apply!(magick_image)
    width, height = magick_image.columns, magick_image.rows
    
    # This is a bit involved. We need to do a manual composite. Here is what it entails.
    #
    # Given a premultiplied RGB image B, and a grayscale mask A, we need to do the following
    # operation:
    #
    #    BrBgBb / Ba * (Ba * A)
    #
    # Since ImageMagick works with unpremultiplied alphas, it is doable - but special care
    # must be taken not to overmult or overdivide.
    #
    # To begin,generate a black and white image for the stencil
    mask = Magick::Image.new(width, height)
    draw_circle(mask, width, height)
    
    # At this stage the mask contains a B/W image of the circle, black outside, white inside.
    # Retain the alpha of the original in a separate image
    only_alpha = magick_image.copy
    only_alpha.alpha(Magick::ExtractAlphaChannel)
    mask.composite!(only_alpha, Magick::CenterGravity, Magick::MultiplyCompositeOp)
    
    # With this composite op, enabling alpha on the destination image is
    # not required - it will be enabled automatically.
    # The CopyOpacityCompositeOp implies that we copy the grayscale version
    # of the RGB channels as the alpha channel, so for some weird reason we need
    # to disable the alpha on our mask image
    mask.alpha(Magick::DeactivateAlphaChannel)
    # And perform the operation (set gray(RGB) of mask as the A of magick_image)
    magick_image.composite!(mask, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
  ensure
    [mask, only_alpha].each do |maybe_image|
      ImageVise.destroy(maybe_image)
    end
  end
  
  def draw_circle(into_image, width, height)
    center_x = (width / 2.0)
    center_y = (height / 2.0)
    # Make sure all the edges are anti-aliased
    radius_width = center_x - 1.5
    radius_height = center_y - 1.5

    gc = Magick::Draw.new
    gc.fill C_black
    gc.rectangle(0, 0, width, height)
    gc.fill C_white
    gc.ellipse(center_x, center_y, radius_width, radius_height, deg_start=0, deg_end=360)
    gc.draw(into_image)
  ensure
    ImageVise.destroy(gc)
  end
  
  ImageVise.add_operator 'ellipse_stencil', self
end
