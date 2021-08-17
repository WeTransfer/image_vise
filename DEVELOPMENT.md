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

Once done, you can use URLs like `profilepictures:/5674`. A very simple Fetcher would just
override the standard filesystem one (be mindful that the filesystem fetcher still checks
path access using the glob whitelist)

    class PicFetcher < ImageVise::FetcherFile
      def self.fetch_uri_to_tempfile(uri_object)
        # Convert an internal "pic://sites/uploads/abcdef.jpg" to a full path URL
        partial_path = decode_file_uri_path(uri_object.path)
        full_filesystem_path = File.join(Mappe::ROOT, 'sites', partial_path)
        full_path_uri = URI(file_url_for(full_filesystem_path))
        super(full_path_uri)
      end
      ImageVise.register_fetcher 'pic', self
    end

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

## Performance and memory

ImageVise uses ImageMagick and RMagick. It _does not_ shell out to `convert` or `mogrify`, because shelling out
is _expensive_ in terms of wall clock. It _does_ do it's best to deallocate (`#destroy!`) the image it works on,
but it is not 100% bullet proof.

Additionally, in contrast to `convert` and `mogrify` ImageVise supports _stackable_ operations, and these operations
might be repeated with different parameters. Unfortunately, `convert` is _not_ Shake, so we cannot pass a DAG of
image operators to it and just expect it to work. If we want to do processing of multiple steps that `convert` is
unable to execute in one call, we have to do

     [fork+exec read + convert + write] -> [fork+exec read + convert + write] + ...

for each operator we want to apply in a consistent fashion. We cannot stuff all the operators into one `convert`
command because the order the operators get applied within `convert` is not clear, whereas we need a reproducible
deterministic order of operations (as set in the pipeline). A much better solution is - load the image into memory
**once**, do all the transformations, save. Additionally, if you use things like OpenCL with ImageMagick, the overhead
of loading the library and compiling the compute kernels will outweigh _any_ performance gains you might get when
actually using them. If you are using a library it is a one-time cost, with very fast processing afterwards.

Also note that image operators are not per definition Imagemagick-specific - it's completely possible to not only use
a different library for processing them, but even to use a different image processing server complying to the
same protocol (a signed JSON-encodded waybill of HTTP(S) source-URL + pipeline instructions).
