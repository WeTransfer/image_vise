# A thumbnailing server

`ImageVise` is an image-from-url-as-a-service server for use either standalone or within a larger Rails/Rack
framework. The main uses are:

* Image resizing on request
* Applying image filters

It is implemented as a Rack application that responds to any URL and accepts the following two _last_ path
compnents, internally named `q` and `sig`:

* `q` - Base64 encoded JSON object with `src_url` and `pipeline` properties
    (the source URL of the image and processing steps to apply)
* `sig` - the HMAC signature, computed over the JSON in `q` before it gets Base64-encoded

A request to `ImageVise` might look like this:

    /acbhGyfhyYErghff/acfgheg123

The URL that gets generated is best composed with the included `ImageVise.image_params` method. This method will
take care of encoding the source URL and the commands in the right way, as well as signing.

## Using ImageVise within a Rails application

Mount ImageVise in your `routes.rb`:

```ruby
mount '/images' => ImageVise
```

and add an initializer (like `config/initializers/image_vise_config.rb`) to set up the permitted hosts

```ruby
ImageVise.add_allowed_host! your_application_hostname
ImageVise.add_secret_key! ENV.fetch('IMAGE_VISE_SECRET')
```

You might want to define a helper method for generating signed URLs as well, which will look something like this:

```ruby
def thumb_url(source_image_url)
  path = ImageVise.image_path(src_url: source_image_url, secret: ENV.fetch('IMAGE_VISE_SECRET')) do |pipeline|
     # For example, you can also yield `pipeline` to the caller
    pipeline.fit_crop width: 128, height: 128, gravity: 'c'
  end
  '/images' + path
end
```

To preserve your sanity, make the route to the ImageVise engine terminal and do _not_ perform rewrites
on it in your webserver configuration - for instance, Base64 permits slashes.

## Using ImageVise within a Rack application

Mount ImageVise under a script name in your `config.ru`:

```ruby
map '/images' do
  run ImageVise
end
```

and add the initialization code either to `config.ru` proper or to some file in your application:

    ImageVise.add_allowed_host! your_application_hostname
    ImageVise.add_secret_key! ENV.fetch('IMAGE_VISE_SECRET')

You might want to define a helper method for generating signed URLs as well, which will look something like this:

```ruby
def thumb_url(source_image_url)
  path_param = ImageVise.image_path(src_url: source_image_url, secret: ENV.fetch('IMAGE_VISE_SECRET')) do |pipe|
    pipe.fit_crop width: 256, height: 256, gravity: 'c'
    pipe.sharpen sigma: 0.5, radius: 2
    pipe.ellipse_stencil
  end
  # Output a URL to the app
  '/images' + path
end
```
## Path decoding and SCRIPT_NAME

`ImageVise::RenderEngine` _must_ be mounted under a `SCRIPT_NAME` (using either `mount` in Rails
or using `map` in Rack). That is so since we may have more than 1 path component that we have to
decode (when the Base64 payload contains slashes).

## Processing files on the local filesystem instead of remote ones

If you want to grab a local file, compose a `file://` URL (mind the endcoding!)

    src_url = 'file://' + URI.encode(File.expand_path(my_pic))

Note that you need to permit certain glob patterns as sources before this will work, see below.

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

```json
[
  ["auto_orient", {}],
  ["geom", {"geometry_string": "512x512"}],
  ["fit_crop", {"width": 32, "height": 32, "gravity": "se"}],
  ["sharpen", {"radius": 0.75, "sigma": 0.5}],
  ["ellipse_stencil", {}]
]
```

The same pipeline can be created using the `Pipeline` DSL:

```ruby
pipe = Pipeline.new.
  auto_orient.
  geom(geometry_string: '512x512').
  fit_crop(width: 32, height: 32, gravity: 'se').
  sharpen(radius: 0.75, sigma: 0.5).
  ellipse_stencil
```
and can then be applied to a `Magick::Image` object:

```ruby
image = Magick::Image.read(my_image_path)[0]
pipe.apply!(image)
```


## Caching

The app is _designed_ to be run behind a frontline HTTP cache. The easiest is to use `Rack::Cache`, but this might
be instance-local depending on the storage backend used. A much better idea is to run ImageVise behind a long-caching
CDN.

## Shared HMAC keys for signed URLs

To allow `ImageVise` to recognize the signature when the signature is going to be received, add it to the list
of the shared keys on the `ImageVise` server:

```ruby
ImageVise.add_secret_key!('ahoy! this is a secret!')
```

A single `ImageVise` server can maintain multiple signature keys, so that you will be able to generate thumbnails from
multiple applications all using different keys for their signatures. Every request will be validated against
each key and if at least one key generates the same signature for the same given parameters, it is going to be
accepted and the request will be allowed to go through.

## Hostname and filesystem validation

By default, `ImageVise` will refuse to process images from URLs on "unknown" hosts. To mark a host as "known"
tell `ImageVise` to

```ruby
ImageVise.add_allowed_host!('my-image-store.ourcompany.co.uk')
```

If you want to permit images from the local server filesystem to be accessed, add the glob pattern
to the set of allowed filesystem patterns:

```ruby
ImageVise.allow_filesystem_source!(Rails.root + '/public/*.jpg')
```

Note that these are _glob_ patterns. The image path will be checked against them using `File.fnmatch`.

## Handling errors within the rendering Rack app

By default, the Rack app within ImageVise swallows all exceptions and returns the error message
within a machine-readable JSON payload. If that doesn't work for you, or you want to add error
handling using some error tracking provider, either subclass `ImageVise::RenderEngine` or prepend
a module into it that will intercept the errors. See error handling in `examples/` for more.

## State

Except for the HTTP cache no state is stored (`ImageVise` does not care whether you store
your images using Dragonfly, CarrierWave or some custom handling code). All the app needs is the full URL.

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
The `worker_in_tube.jpg` is used with permission from Arcadis Nederland B.V.

The sRGB color profiles are [downloaded from the ICC](http://www.color.org/srgbprofiles.xalter) and it's
use is governed by the terms present in the LICENSE.txt