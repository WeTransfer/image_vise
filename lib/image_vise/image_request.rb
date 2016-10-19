class ImageVise::ImageRequest < Ks.strict(:src_url, :pipeline)
  class InvalidRequest < ArgumentError; end
  class SignatureError < InvalidRequest; end
  class URLError < InvalidRequest; end
  class MissingParameter < InvalidRequest; end
  
  # Initializes a new ParamsChecker from given HTTP server framework
  # params. The params can be symbol- or string-keyed, does not matter.
  def self.to_request(qs_params:, secrets:)
    base64_encoded_params = qs_params.fetch(:q) rescue qs_params.fetch('q')
    given_signature = qs_params.fetch(:sig) rescue qs_params.fetch('sig')

    # Decode Base64 first - this gives us a stable serialized form of the request parameters.
    # The encoded parameters might _not_ include ==-padding at the end.
    decoded_json = Base64.decode64(base64_encoded_params)

    # Check the signature before decoding JSON (since we will be creating symbols)
    unless valid_signature?(decoded_json, given_signature, secrets)
      raise SignatureError, "Invalid or missing signature"
    end

    # Decode the JSON
    # (only AFTER the signature has been validated, so we can use symbol keys)
    params = JSON.parse(decoded_json, symbolize_names: true)

    # Pick up the URL and validate it
    source_url_str = params.fetch(:src_url).to_s
    raise URLError, "the :src_url parameter must be non-empty" if source_url_str.empty?
    pipeline_definition = params.fetch(:pipeline)
    new(src_url: URI(source_url_str), pipeline: ImageVise::Pipeline.from_param(pipeline_definition))
  rescue KeyError => e
    raise InvalidRequest.new(e.message)
  end

  def to_query_string_params(signed_with_secret)
    payload = JSON.dump(to_h)
    base64_enc = Base64.strict_encode64(payload).gsub(/\=+$/, '')
    {q: base64_enc, sig: OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, signed_with_secret, payload)}
  end

  def to_h
    {pipeline: pipeline.to_params, src_url: src_url.to_s}
  end
  
  def cache_etag
    Digest::SHA1.hexdigest(JSON.dump(to_h))
  end

  private

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
