require File.dirname(__FILE__) + '/lib/vise'
require 'dotenv'
Dotenv.load

# Add all the secret keys specified in the environment separated by a comma
if ENV['VISE_SECRET_KEYS']
  ENV['VISE_SECRET_KEYS'].split(',').map do | key |
    ImageVise.add_secret_key!(key.strip)
  end
end

# Cover things with caching, even redirects (since we do not want to ask S3 too often)
use Rack::Cache, :metastore => 'file:tmp/cache/rack/meta', :entitystore  => 'file:tmp/cache/rack/entity', 
  :verbose => true, :allow_reload => false, :allow_revalidate => false

# Serve runtime thumbnails, under a specific URL
map '/images'do
  run ImageVise
end
