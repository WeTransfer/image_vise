# NOTE: Until 1.0.0 ImageVise API is somewhat in flux

## Defining image operators

To add an image operator, define a class roughly like so, and add it to the list of operators.

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

## Defining fetchers

Fetchers are based on the scheme of the image URL. Default fetchers are already defined for `http`, `https`
and `file` schemes. If you need to grab data from a database, for instance, you can define a fetcher and register
it:

    module DatabaseFetcher
      def self.fetch_uri_to_tempfile(uri_object)
        tf = Tempfile.new 'data-fetch'
        
        object_id = uri_object.path[/\d+/]
        data_model = ProfilePictures.find(object_id)
        tf << data_model.body
        
        tf.rewind; tf
      rescue Exception => e
        ImageVise.close_and_unlink(tf) # do not litter Tempfiles
        raise e
      end
    end
    
    ImageVise.register_fetcher 'profilepictures', self

Once done, you can use URLs like `profilepictures:/5674`

## Overriding the render engine

By default, `ImageVise.call` delegates to `ImageVise::RenderEngine.new.call`. You can mount your own subclass
instead, and it will handle everything the same way:

    class MyThumbnailer < ImageVise::RenderEngine
      ...
    end
    
    map '/thumbs' do
      run MyThumbnailer.new
    end

Note that since the API is in flux the methods you can override in `RenderEngine` can change.
So far none of them are private.