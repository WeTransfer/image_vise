# A thumbnailing server

`ImageVise` is an image-from-url-as-a-service server for use either standalone or within a larger Rails/Rack
framework. The main uses are:

* Image resizing on request
* Applying image filters

It is implemented as a Rack application that responds to any URL and accepts the following query string parameters:

* `q` - Bese-64 encoded JSON object with `src_url` and `pipeline` properties
* `sig` - the HMAC signature of the hash with `url`, `w` and `h` computed on a query-string encode of them

A request to `ImageVise` might look like this:

    /?q=acbhGyfhyYErghff&sig=acfgheg123

The URL that gets generated is best composed with the included `ImageVise.image_params` method. This method will
take care of genrating the right JSON payload and signing it.

## Using ImageVise within a Rails application

Mount ImageVise in your `routes.rb`:

    mount '/images' => ImageVise

and add an initializer (like `config/initializers/image_vise_config.rb`) to set up the permitted hosts

    ImageVise.add_allowed_host! your_application_hostname
    ImageVise.add_secret_key! ENV.fetch('IMAGE_VISE_SECRET')

You might want to define a helper method for generating signed URLs as well, which will look something like this:

    def thumb_url(source_image_url)
      qs_params = ImageVise.image_params(src_url: source_image_url, secret: ENV.fetch('IMAGE_VISE_SECRET')) do |pipeline|
         # For example, you can also yield `pipeline` to the caller
        pipeline.fit_crop width: 128, height: 128, gravity: 'c'
      end
      '/images?' + Rack::Utils.build_query(qs_params) # or use url_for...
    end

## Using ImageVise within a Rack application

Mount ImageVise under a script name in your `config.ru`:

    map '/images' do
      run ImageVise
    end

and add the initialization code either to `config.ru` proper or to some file in your application:

    ImageVise.add_allowed_host! your_application_hostname
    ImageVise.add_secret_key! ENV.fetch('IMAGE_VISE_SECRET')

You might want to define a helper method for generating signed URLs as well, which will look something like this:

    def thumb_url(source_image_url)
      qs_params = ImageVise.image_params(src_url: source_image_url, secret: ENV.fetch('IMAGE_VISE_SECRET')) do |pipe|
        # For example, you can also yield `pipeline` to the caller
        pipe.fit_crop width: 256, height: 256, gravity: 'c'
        pipe.sharpen sigma: 0.5, radius: 2
        pipe.ellipse_stencil
      end
      # Output a URL to the app
      '/images?' + Rack::Utils.build_query(image_request)
    end

## Operators and pipelining

ImageVise processes an image using _operators_. Each operator is just like an adjustment layer in Photoshop, except
that it can also resize the canvas. If you are familiar with node-based compositing systems like Shake, Nuke or Fusion
the pipeline is a node DAG with only one connection arrow going all the way. The operations are always applied in a
destructive way, so that the additional intermediate versions don't have to be deallocated manually after processing.

Each Operator is described in the pipeline using a tuple (Array) of roughly this structure:

    [<operator_name>, {"<operator_param1>": <operator_param1_value>}]

You can have an unlimited number of such Operators per thumbnail, and they all get encoded in the URL (well,
technically, you _are_ limited - by the URL length supported by your web server).

For example, you can use the pipeline to apply a sharpening operator _after_ resising an image (for the lack
of decent image filtering choices in ImageMagick proper).

Here is an example pipeline, JSON-encoded (this is what is passed in the URL):

    [
      ["auto_orient", {}],
      ["geom", {"geometry_string": "512x512"}],
      ["fit_crop", {"width": 32, "height": 32, "gravity": "se"}],
      ["sharpen", {"radius": 0.75, "sigma": 0.5}],
      ["ellipse_stencil", {}]
    ]

The same pipeline can be created using the `Pipeline` DSL:

    pipe = Pipeline.new.
      auto_orient.
      geom(geometry_string: '512x512').
      fit_crop(width: 32, height: 32, gravity: 'se').
      sharpen(radius: 0.75, sigma: 0.5).
      ellipse_stencil

and can then be applied to a `Magick::Image` object:

     image = Magick::Image.read(my_image_path)[0]
     pipe.apply!(image)

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

## Using forked child processes for RMagick tasks

You can optionally set the `IMAGE_VISE_ENABLE_FORK` environment variable to any value to enable forking. When this
variable is set, ImageVise will fork a child process and perform the image processing task within that process,
killing it afterwards and deallocating all the memory. This can be extremely efficient for dealing with potential
memory bloat issues in ImageMagick/RMagick. However, loading images into RMagick may hang in a forked child. This
will lead to the child being timeout-terminated, and no image is going to be rendered. This issue is known and
also platform-dependent (it does not happen on OSX but does happen on Docker within Ubuntu Trusty for instance).

So, this feature _does_ exist but your mileage may vary with regards to it's use.

## Caching

The app is _designed_ to be run behind a frontline HTTP cache. The easiest is to use `Rack::Cache`, but this might
be instance-local depending on the storage backend used. A much better idea is to run ImageVise behind a long-caching
CDN.

## Shared HMAC keys for signed URLs

To allow `ImageVise` to recognize the signature when the signature is going to be received, add it to the list
of the shared keys on the `ImageVise` server:

    ImageVise.add_secret_key!('ahoy! this is a secret!')

A single `ImageVise` server can maintain multiple signature keys, so that you will be able to generate thumbnails from
multiple applications all using different keys for their signatures. Every request will be validated against
each key and if at least one key generates the same signature for the same given parameters, it is going to be
accepted and the request will be allowed to go through.

When running `ImageVise` as a standalone application you can add set the `VISE_SECRET_KEYS` environment 
variable to a comma-separated list of keys you are willing to accept (no spaces after the commas).

## Hostname validation

By default, `ImageVise` will refuse to process images from URLs on "unknown" hosts. To mark a host as "known"
tell `ImageVise` to

    ImageVise.add_allowed_host!('my-image-store.ourcompany.co.uk')

## State

Except for the HTTP cache for redirects et.al no state is stored (`ImageVise` does not care whether you store
your images using Dragonfly, CarrierWave or some custom handling code). All the app needs is the full URL.

## FAQ

* _Yo dawg, I thought you like URLs so I have put encoded URL in your URL so you can..._ - well, the only alternative
  is also managing image storage, and this something we want to avoid to keep `ImageVise` stateless
* _But the URLs can be exploited_ - this is highly unlikely if you pick strong keys for the HMAC signatures
* _I can load any image into the thumbnailer_ - in fact, no. First you have the URL checks, and then - all the URLs
  are supposed to be coming from the sources you trust since they are signed.

## Running the tests, versioning, contributing

By default, `bundle exec rake` will run RSpec and will also open the generated images using the `$ open` command available
on your CLI. If you want to skip viewing those images, set the `SKIP_INTERACTIVE` environment variable to any value.

The gem version is specified in `image_vise.rb`. When contributing, please follow:

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

### Copyright

Copyright (c) 2016 WeTransfer. See LICENSE.txt for further details.
The licensing terms also apply to the `waterside_magic_hour.jpg` test image.
