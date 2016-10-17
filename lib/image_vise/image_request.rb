class ImageVise::ImageRequest < Ks.strict(:src_url, :pipeline)
  class InvalidRequest < ArgumentError; end
  class SignatureError < InvalidRequest; end
  class URLError < InvalidRequest; end
  class MissingParameter < InvalidRequest; end
  
  # Initializes a new ParamsChecker from given HTTP server framework
  # params. The params can be symbol- or string-keyed, does not matter.
  def self.to_request(qs_params:, secrets:, permitted_source_hosts:, allowed_filesystem_patterns:)
    base64_encoded_params = qs_params.fetch(:q) rescue qs_params.fetch('q')
    given_signature = qs_params.fetch(:sig) rescue qs_params.fetch('sig')
    
    # Decode Base64 first - this gives us a stable serialized form of the request parameters
    decoded_json = Base64.decode64(base64_encoded_params)

    # Check the signature before decoding JSON (since we will be creating symbols and stuff)
    raise SignatureError, "Invalid or missing signature" unless valid_signature?(decoded_json, given_signature, secrets)

    # Decode the JSON
    params = JSON.parse(decoded_json, symbolize_names: true)

    # Pick up the URL and validate it
    src_url = params.fetch(:src_url).to_s
    raise URLError, "the :src_url parameter must be non-empty" if src_url.empty?

    src_url = URI.parse(src_url)
    if src_url.scheme == 'file'
      raise URLError, "#{src_url} not permitted since filesystem access is disabled" if allowed_filesystem_patterns.empty?
      raise URLError, "#{src_url} is not on the path whitelist" unless allowed_path?(allowed_filesystem_patterns, src_url.path)
    elsif src_url.scheme != 'file'
      raise URLError, "#{src_url} is not permitted as source" unless permitted_source_hosts.include?(src_url.host)
    end
    
    # Build out the processing pipeline
    pipeline_definition = params.fetch(:pipeline)

    new(src_url: src_url.to_s, pipeline: ImageVise::Pipeline.from_param(pipeline_definition))
  rescue KeyError => e
    raise InvalidRequest.new(e.message)
  end

  def to_query_string_params(signed_with_secret)
    payload = JSON.dump(to_h)
    {q: Base64.strict_encode64(payload), sig: OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, signed_with_secret, payload)}
  end

  def to_h
    {pipeline: pipeline.to_params, src_url: src_url}
  end
  
  def cache_etag
    Digest::SHA1.hexdigest(JSON.dump(to_h))
  end

  private

  def self.allowed_path?(filesystem_glob_patterns, path_to_check)
    expanded_path = File.realpath(File.expand_path(path_to_check))
    filesystem_glob_patterns.any? {|pattern| File.fnmatch?(pattern, expanded_path) }
  end

  def self.valid_signature?(for_payload, given_signature, secrets)
    # Check the signature against every key that we have,
    # since different apps might be using different keys
    seen_valid_signature = false
    secrets.each do | stored_secret |
      expected_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, stored_secret, for_payload)
      result_for_this_key = Rack::Utils.secure_compare(expected_signature, given_signature)
      seen_valid_signature ||= result_for_this_key
    end
    seen_valid_signature
  end
end
