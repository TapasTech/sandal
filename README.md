# Sandal [![Build Status](https://travis-ci.org/gregbeech/sandal.png?branch=master)](https://travis-ci.org/gregbeech/sandal) [![Coverage Status](https://coveralls.io/repos/gregbeech/sandal/badge.png?branch=master)](https://coveralls.io/r/gregbeech/sandal) [![Code Climate](https://codeclimate.com/github/gregbeech/sandal.png)](https://codeclimate.com/github/gregbeech/sandal) [![Dependency Status](https://gemnasium.com/gregbeech/sandal.png)](https://gemnasium.com/gregbeech/sandal)

A Ruby library for creating and reading [JSON Web Tokens (JWT) draft-08](http://tools.ietf.org/html/draft-ietf-oauth-json-web-token-08), supporting [JSON Web Signatures (JWS) draft-11](http://tools.ietf.org/html/draft-ietf-jose-json-web-signature-11) and [JSON Web Encryption (JWE) draft-11](http://tools.ietf.org/html/draft-ietf-jose-json-web-encryption-11). See the [CHANGELOG](CHANGELOG.md) for version history.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sandal'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sandal

## Signed Tokens

All the JWA signature methods are supported:

- ES256, ES384, ES512 (note: not supported on jruby)
- HS256, HS384, HS512
- RS256, RS384, RS512
- none

Signing example:

```ruby
claims = { 
  'iss' => 'example.org',
  'sub' => 'user@example.org',
  'exp' => (Time.now + 3600).to_i
}
signer = Sandal::Sig::ES256.new(File.read('/path/to/ec_private_key.pem'))
jws_token = Sandal.encode_token(claims, signer, { 
  'kid' => 'my ec key'
})
```

Decoding and validating example:

```ruby
claims = Sandal.decode_token(jws_token) do |header|
  if header['kid'] == 'my ec key'
    Sandal::Sig::ES256.new(File.read('/path/to/ec_public_key.pem'))
  end
end
```

Keys for these examples can be generated by executing:

    $ openssl ecparam -out ec_private_key.pem -name prime256v1 -genkey
    $ openssl ec -out ec_public_key.pem -in ec_private_key.pem -pubout

If you need to convert the private and public keys to PKCS#8 and X.509 encoded formats, respectively, for use with other platforms that don't like PEM then use the following commands:

    $ openssl pkcs8 -topk8 -nocrypt -out ec_private_key.key -outform DER -in ec_private_key.pem -inform PEM
    $ openssl ec -out ec_public_key.key -outform DER -in ec_public_key.pem -pubout

## Encrypted Tokens

All the JWA encryption methods are supported:

- A128CBC-HS256, A256CBC-HS512
- A128GCM, A256GCM (note: requires ruby 2.0.0 or later)

Some of the JWA key encryption algorithms are supported at the moment. The key wrap algorithms don't appear to exist in Ruby so they're not likely to be supported in the near future, but these ones are implemented:

- RSA1_5
- RSA-OAEP
- direct

Encrypting example (assumes use of the jws_token from the signing examples, as typically JWE tokens will be used to wrap JWS tokens):

```ruby
alg = Sandal::Enc::Alg::RSA_OAEP.new(File.Read('/path/to/rsa_public_key.pem'))
encrypter = Sandal::Enc::A128GCM.new(alg)
jwe_token = Sandal.encrypt_token(jws_token, encrypter, {
  'kid': 'your rsa key',
  'cty': 'JWT'
})
```

Decrypting example:

```ruby
jws_token = Sandal.decode_token(jwe_token) do |header|
  if header['kid'] == 'your rsa key'
    alg = Sandal::Enc::Alg::RSA_OAEP.new(File.Read('/path/to/rsa_private_key.pem'))
    Sandal::Enc::A128GCM.new(alg)
  end
end
```

Keys for these examples can be generated by executing:

    $ openssl genrsa -out rsa_private_key.pem 2048
    $ openssl rsa -out rsa_public_key.pem -in rsa_private_key.pem -pubout

If you need to convert the private and public keys to PKCS#8 and X.509 encoded formats, respectively, for use with other platforms that don't like PEM then use the following commands:

    $ openssl pkcs8 -topk8 -nocrypt -out rsa_private_key.key -outform DER -in rsa_private_key.pem -inform PEM
    $ openssl rsa -out rsa_public_key.key -outform DER -in rsa_public_key.pem -pubout
    
## Validation Options

You can change the default validation options, for example if you only want to accept tokens from 'example.org' with a maximum clock skew of one minute:

```ruby
Sandal.default! valid_iss: ['example.org'], max_clock_skew: 60
```

Sometimes while developing it can be useful to turn off some validation options just to get things working (don't do this in production!):

```ruby
Sandal.default! ignore_signature: true, ignore_exp: true
```

These options can also be configured on a per-token basis by using a second `options` parameter in the block passed to the `decode` method.

## Contributing

1. Fork it
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new Pull Request



