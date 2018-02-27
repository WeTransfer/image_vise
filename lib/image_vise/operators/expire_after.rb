# Overrides the cache lifetime set in the output headers of the RenderEngine.
# Can be used to permit the requester to set the caching lifetime, instead
# of it being a configuration variable in the service performing the rendering
class ImageVise::ExpireAfter < Ks.strict(:seconds)
  def initialize(seconds:)
    unless seconds.is_a?(Integer) && seconds > 0
      raise ArgumentError, "the :seconds parameter must be an Integer and must be above 0, but was %s" % seconds.inspect
    end
    super
  end

  def apply!(_, metadata)
    metadata[:expire_after_seconds] = seconds
  end

  ImageVise.add_operator 'expire_after', self
end
