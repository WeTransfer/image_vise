# Security implications for ImageVise

This lists out the implementation details of security-sensitive parts of ImageVise.

## Protection of the URLs

URLs are passed as Base64-encoded JSON. The HMAC signature is computed over the Base-64 encoded string,
so altering the string (with the intention to bust the cache) will invalidate the signature.

For checking HMAC values `Rack::Utils.secure_compare` constant-time comparison is used.

## Throttling still recommended

Throttling between the caching CDN/proxy is recommended.

## Cache bypass protection for fuzzed paths

ImageVise accepts exactly 2 path components, and will return early if there are more

## Cache bypass protection for randomized query string params

ImageVise defaults to using paths. If you have a way to forbid query strings on the fronting CDN
or proxy server we suggest you to do so, to prevent randomized URLs from filling up your cache
and extreme amounts of processing from happening.

* `/image/<pipeline>/<sig>?&random=123`
* `/image/<pipeline>/<sig>?&random=456`

These URLs would in fact resolve to the same source image and pipeline, but would not be stored in an upstream
CDN cache because the query string params contain extra data.

## Protection for remote URLs from HTTP(s) origins

Only URLs on whitelisted hosts are going to be fetched. If there are no hosts added,
any remote URL is going to cause an exception. No special verification for whether the upstream must be HTTP
or HTTPS is performed at this time, but HTTPS upstreams' SSL certificats _will_ be verified.

## Protection for "file:/" URLs

The file URLs are going to be decoded, and the path component will be matched against permitted _glob patterns._
The matching takes links (hard and soft) into account, and uses Ruby's `File.fnmatch?` under the hood. The path
is always expanded first using `File.expand_path`. The data is not read into ImageMagick from the original location,
but gets copied into a tempfile first.

The path in to the file gets encoded in the image processing request and may be examined by the user, that will
disclose where the source image is stored on the server's filesystem. This might be an issue - if it is,
a customised version with a custom URL scheme should be used for the source URL.

## ImageMagick memory constraints

ImageVise does not set RMagick limits by itself. You should
[set them according to the RMagick documentation.](https://rmagick.github.io/magick.html#limit_resource)

## Processing time constraints

If you are using forking, there will be a timeout used for how long the forked child process may run,
which is the default timeout used in ExceptionalFork.
