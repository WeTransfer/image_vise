require 'ks'
require 'json'
require 'patron'
require 'rmagick'
require 'magic_bytes'
require 'thread'
require 'base64'
require 'rack'

class ImageVise
  require_relative 'image_vise/version'
  S_MUTEX = Mutex.new
  private_constant :S_MUTEX
  # If no custom cache lifetime is set we'll use this one.
  DEFAULT_CACHE_LIFETIME = 2592000

  @allowed_hosts = Set.new
  @keys = Set.new
  @operators = {}
  @allowed_glob_patterns = Set.new
  @fetchers = {}
  @custom_cache_lifetime = DEFAULT_CACHE_LIFETIME

  class << self
    # Resets all allowed hosts
    def reset_allowed_hosts!
      S_MUTEX.synchronize { @allowed_hosts.clear }
    end

    # Add an allowed host
    def add_allowed_host!(hostname)
      S_MUTEX.synchronize { @allowed_hosts << hostname }
    end

    # Returns both the allowed hosts added at runtime and the ones set in the constant
    def allowed_hosts
      S_MUTEX.synchronize { @allowed_hosts.to_a }
    end

    # Removes all set keys
    def reset_secret_keys!
      S_MUTEX.synchronize { @keys.clear }
    end

    def allow_filesystem_source!(glob_pattern)
      S_MUTEX.synchronize { @allowed_glob_patterns << glob_pattern }
    end

    def allowed_filesystem_sources
      S_MUTEX.synchronize { @allowed_glob_patterns.to_a }
    end

    def deny_filesystem_sources!
      S_MUTEX.synchronize { @allowed_glob_patterns.clear }
    end

    def set_custom_cache_lifetime!(length)
      Integer(length)
      S_MUTEX.synchronize { @custom_cache_lifetime = length }
    rescue => e
      raise ArgumentError, "The custom cache lifetime value must be an integer"
    end

    def cache_lifetime
      S_MUTEX.synchronize { @custom_cache_lifetime }
    end

    # Adds a key against which the parameters are going to be verified.
    # Multiple applications may have their own different keys,
    # so we need to have multiple keys.
    def add_secret_key!(key)
      S_MUTEX.synchronize { @keys << key }
      self
    end

    # Returns the array of defined keys or raises an exception if no keys have been set yet
    def secret_keys
      keys = S_MUTEX.synchronize { @keys.any? && @keys.to_a }
      keys or raise "No keys set, add a key using `ImageVise.add_secret_key!(key)'"
    end

    # Generate a set of querystring params for a resized image. Yields a Pipeline object that
    # will receive method calls for adding image operations to a stack.
    #
    #   ImageVise.image_params(src_url: image_url_on_s3, secret: '...') do |p|
    #      p.center_fit width: 128, height: 128
    #      p.elliptic_stencil
    #   end #=> {q: '...', sig: '...'}
    #
    # The query string elements can be then passed on to RenderEngine for validation and execution.
    #
    # @yield {ImageVise::Pipeline}
    # @return [Hash]
    def image_params(src_url:, secret:)
      p = Pipeline.new
      yield(p)
      raise ArgumentError, "Image pipeline has no steps defined" if p.empty?
      ImageRequest.new(src_url: URI(src_url), pipeline: p).to_query_string_params(secret)
    end

    # Generate a path for a resized image. Yields a Pipeline object that
    # will receive method calls for adding image operations to a stack.
    #
    #   ImageVise.image_path(src_url: image_url_on_s3, secret: '...') do |p|
    #      p.center_fit width: 128, height: 128
    #      p.elliptic_stencil
    #   end #=> "/abcdef/xyz123"
    #
    # The query string elements can be then passed on to RenderEngine for validation and execution.
    #
    # @yield {ImageVise::Pipeline}
    # @return [String]
    def image_path(src_url:, secret:)
      p = Pipeline.new
      yield(p)
      raise ArgumentError, "Image pipeline has no steps defined" if p.empty?
      ImageRequest.new(src_url: URI(src_url), pipeline: p).to_path_params(secret)
    end

    # Adds an operator
    def add_operator(operator_name, object_responding_to_new)
      @operators[operator_name.to_s] = object_responding_to_new
    end

    # Gets an operator by name
    def operator_from(operator_name)
      @operators.fetch(operator_name.to_s)
    end

    def defined_operator_names
      @operators.keys
    end

    def register_fetcher(scheme, fetcher)
      S_MUTEX.synchronize { @fetchers[scheme.to_s] = fetcher }
    end

    def fetcher_for(scheme)
      S_MUTEX.synchronize { @fetchers[scheme.to_s] or raise "No fetcher registered for #{scheme}" }
    end

    def operator_name_for(operator)
      S_MUTEX.synchronize do
        @operators.key(operator.class) or raise "Operator #{operator.inspect} not registered using ImageVise.add_operator"
      end
    end
  end

  # Made available since the object that is used with `mount()` in Rails
  # has to, by itself, to respond to `call`.
  #
  # Thanks to this method you can do this:
  #
  #   mount ImageVise => '/thumbnails'
  #
  # instead of having to do
  #
  #   mount ImageVise.new => '/thumbnails'
  #
  def self.call(rack_env)
    ImageVise::RenderEngine.new.call(rack_env)
  end

  def call(rack_env)
    ImageVise::RenderEngine.new.call(rack_env)
  end

  # Used as a shorthand to force-destroy Magick images in ensure() blocks. Since
  # ensure blocks sometimes deal with variables in inconsistent states (variable
  # in scope but not yet set to an image) we take the possibility of nils into account.
  # We also deal with Magick::Image objects that already have been destroyed in a clean manner.
  def self.destroy(maybe_image)
    return unless maybe_image
    return unless maybe_image.respond_to?(:destroy!)
    return if maybe_image.destroyed?
    maybe_image.destroy!
  end

  # Used as a shorthand to force-dealloc Tempfiles in an ensure() blocks. Since
  # ensure blocks sometimes deal with variables in inconsistent states (variable
  # in scope but not yet set to an image) we take the possibility of nils into account.
  def self.close_and_unlink(maybe_tempfile)
    return unless maybe_tempfile
    maybe_tempfile.close unless maybe_tempfile.closed?
    maybe_tempfile.unlink
  end
end

Dir.glob(__dir__ + '/**/*.rb').sort.each do |f|
  require f unless f == File.expand_path(__FILE__)
end
