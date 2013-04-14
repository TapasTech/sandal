require 'multi_json'
require 'openssl'
require 'sandal/version'
require 'sandal/claims'
require 'sandal/enc'
require 'sandal/sig'
require 'sandal/util'


# A library for creating and reading JSON Web Tokens (JWT), supporting JSON Web 
# Signatures (JWS) and JSON Web Encryption (JWE).
#
# Currently supports draft-06 of the JWT spec, and draft-08 of the JWS and JWE 
# specs.
module Sandal
  extend Sandal::Util

  # The error that is raised when a token is invalid.
  class TokenError < StandardError; end

  # The error that is raised when a claim within a token is invalid.
  class ClaimError < TokenError; end

  # The default options for token handling.
  #
  # ignore_exp:: 
  #   Whether to ignore the expiry date of the token. This setting is just to
  #   help get things working and should always be false in real apps!
  # ignore_nbf:: 
  #   Whether to ignore the not-before date of the token. This setting is just 
  #   to help get things working and should always be false in real apps!
  # ignore_signature:: 
  #   Whether to ignore the signature of signed (JWS) tokens.  This setting is 
  #   just tohelp get things working and should always be false in real apps!
  # max_clock_skew:: 
  #   The maximum clock skew, in seconds, when validating times. If your server
  #   time is out of sync with the token server then this can be increased to
  #   take that into account. It probably shouldn't be more than about 300.
  # valid_iss:: 
  #   A list of valid token issuers, if validation of the issuer claim is 
  #   required.
  # valid_aud:: 
  #   A list of valid audiences, if validation of the audience claim is
  #   required.
  DEFAULT_OPTIONS = {
    ignore_exp: false,
    ignore_nbf: false,
    ignore_signature: false,
    max_clock_skew: 0,
    valid_iss: [],
    valid_aud: [],
  }

  # Overrides the default options.
  #
  # @param defaults [Hash] The options to override (see {DEFAULT_OPTIONS} for
  #   details).
  # @return [Hash] The new default options.
  def self.default!(defaults)
    DEFAULT_OPTIONS.merge!(defaults)
  end

  # Creates a signed JSON Web Token.
  #
  # @param payload [String or Hash] The payload of the token. Hashes will be 
  #   encoded as JSON.
  # @param signer [#name,#sign] The token signer, which may be nil for an 
  #   unsigned token.
  # @param header_fields [Hash] Header fields for the token (note: do not
  #   include 'alg').
  # @return [String] A signed JSON Web Token.
  def self.encode_token(payload, signer, header_fields = nil)
    signer ||= Sandal::Sig::NONE

    header = {}
    header['alg'] = signer.name if signer.name != Sandal::Sig::NONE.name
    header = header_fields.merge(header) if header_fields
    header = MultiJson.dump(header)

    payload = MultiJson.dump(payload) unless payload.is_a?(String)

    sec_input = [header, payload].map { |p| jwt_base64_encode(p) }.join('.')
    signature = signer.sign(sec_input)
    [sec_input, jwt_base64_encode(signature)].join('.')
  end

  # Decodes and validates a signed JSON Web Token.
  #
  # The block is called with the token header as the first parameter, and should
  # return the appropriate signature method to validate the signature. It can
  # optionally have a second options parameter which can be used to override the
  # {DEFAULT_OPTIONS} on a per-token basis.
  #
  # @param token [String] The encoded JSON Web Token.
  # @yieldparam header [Hash] The JWT header values.
  # @yieldparam options [Hash] (Optional) A hash that can be used to override 
  #   the default options.
  # @yieldreturn [#valid?] The signature validator.
  # @return [Hash or String] The payload of the token as a Hash if it was JSON, 
  #   otherwise as a String.
  # @raise [Sandal::ClaimError] One or more claims in the token is invalid.
  # @raise [Sandal::TokenError] The token format is invalid, or validation of 
  #   the token failed.
  def self.decode_token(token)
    parts = token.split('.')
    header, payload, signature = decode_jws_token_parts(parts)

    options = DEFAULT_OPTIONS.clone
    validator = yield header, options if block_given?
    validator ||= Sandal::Sig::NONE

    unless options[:ignore_signature]
      secured_input = parts.take(2).join('.')
      unless validator.valid?(signature, secured_input)
        raise TokenError, 'Invalid signature.'
      end
    end

    parse_and_validate(payload, header['cty'], options)
  end

  # Creates an encrypted JSON Web Token.
  #
  # @param payload [String] The payload of the token.
  # @param encrypter [#name,#alg,#encrypt] The token encrypter.
  # @param header_fields [Hash] Header fields for the token (note: do not
  #   include 'alg' or 'enc').
  # @return [String] An encrypted JSON Web Token.
  def self.encrypt_token(payload, encrypter, header_fields = nil)
    header = {}
    header['enc'] = encrypter.name
    header['alg'] = encrypter.alg.name
    header = header_fields.merge(header) if header_fields

    encrypter.encrypt(header, payload)
  end

  # Decrypts and validates an encrypted JSON Web Token.
  #
  # The block is called with the token header as the first parameter, and should
  # return the appropriate encryption method to decrypt the token. It can
  # optionally have a second options parameter which can be used to override the
  # {DEFAULT_OPTIONS} on a per-token basis.
  #
  # @param token [String] The encrypted JSON Web Token.
  # @yieldparam header [Hash] The JWT header values.
  # @yieldparam options [Hash] (Optional) A hash that can be used to override
  #   the default options.
  # @yieldreturn [#decrypt] The token decrypter.
  # @return [Hash or String] The payload of the token as a Hash if it was JSON,
  #   otherwise as a String.
  # @raise [Sandal::ClaimError] One or more claims in the token is invalid.
  # @raise [Sandal::TokenError] The token format is invalid, or decryption or
  #   validation of the token failed.
  def self.decrypt_token(token)
    parts = token.split('.')
    decoded_parts = decode_jwe_token_parts(parts)
    header = decoded_parts[0]

    options = DEFAULT_OPTIONS.clone
    decrypter = yield header, options if block_given?

    payload = decrypter.decrypt(parts, decoded_parts)
    parse_and_validate(payload, header['cty'], options)
  end

private

  # Decodes the parts of a JWS token.
  def self.decode_jws_token_parts(parts)
    parts = decode_token_parts(parts)
    parts << '' if parts.length == 2
    raise TokenError, 'Invalid token format.' unless parts.length == 3
    parts
  end

  # Decodes the parts of a JWE token.
  def self.decode_jwe_token_parts(parts)
    parts = decode_token_parts(parts)
    raise TokenError, 'Invalid token format.' unless parts.length == 5
    parts
  end

  # Decodes the parts of a token.
  def self.decode_token_parts(parts)
    parts = parts.map { |part| jwt_base64_decode(part) }
    parts[0] = MultiJson.load(parts[0])
    parts
  rescue
    raise TokenError, 'Invalid token encoding.'
  end

  # Parses the content of a token and validates the claims if is JSON claims.
  def self.parse_and_validate(payload, content_type, options)
    return payload if content_type == 'JWT'

    claims = MultiJson.load(payload) rescue nil
    if claims
      claims.extend(Sandal::Claims).validate_claims(options)
    else
      payload
    end
  end

end