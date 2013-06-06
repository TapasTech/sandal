require 'helper'
require 'openssl'

include Sandal::Util

describe Sandal::Enc::Alg::RSA1_5 do

  it 'can encrypt and decrypt a content master key' do
    key = OpenSSL::PKey::RSA.new(2048)
    encrypter = Sandal::Enc::Alg::RSA1_5.new(key.public_key)
    decrypter = Sandal::Enc::Alg::RSA1_5.new(key)
    key = 'an encryption key'
    decrypter.decrypt_key(encrypter.encrypt_key(key)).should == key
  end

  context '#name' do

    it 'is "RSA1_5"' do
      alg = Sandal::Enc::Alg::RSA1_5.new(OpenSSL::PKey::RSA.new(2048))
      alg.name.should == 'RSA1_5'
    end

  end

  context '#decrypt_key' do

    it 'can decrypt the encypted content master key from JWE draft-10 section A.2', :jruby_incompatible do
      key = [4, 211, 31, 197, 84, 157, 252, 254, 11, 100, 157, 250, 63, 170, 106, 206, 107, 124, 212, 45, 111, 107, 9, 219, 200, 177, 0, 240, 143, 156, 44, 207].pack('C*')
      encrypted_key = jwt_base64_decode('ZmnlqWgjXyqwjr7cXHys8F79anIUI6J2UWdAyRQEcGBU-KPHsePM910_RoTDGu1IW40Dn0dvcdVEjpJcPPNIbzWcMxDi131Ejeg-b8ViW5YX5oRdYdiR4gMSDDB3mbkInMNUFT-PK5CuZRnHB2rUK5fhPuF6XFqLLZCG5Q_rJm6Evex-XLcNQAJNa1-6CIU12Wj3mPExxw9vbnsQDU7B4BfmhdyiflLA7Ae5ZGoVRl3A__yLPXxRjHFhpOeDp_adx8NyejF5cz9yDKULugNsDMdlHeJQOMGVLYaSZt3KP6aWNSqFA1PHDg-10ceuTEtq_vPE4-Gtev4N4K4Eudlj4Q')
      alg = Sandal::Enc::Alg::RSA1_5.new(SampleKeys.jwe_draft10_a2_rsa)
      alg.decrypt_key(encrypted_key).should == key
    end

    it 'raises an InvalidTokenError when the wrong key is used for decryption' do
      key = [4, 211, 31, 197, 84, 157, 252, 254, 11, 100, 157, 250, 63, 170, 106, 206, 107, 124, 212, 45, 111, 107, 9, 219, 200, 177, 0, 240, 143, 156, 44, 207].pack('C*')
      encrypted_key = jwt_base64_decode('ZmnlqWgjXyqwjr7cXHys8F79anIUI6J2UWdAyRQEcGBU-KPHsePM910_RoTDGu1IW40Dn0dvcdVEjpJcPPNIbzWcMxDi131Ejeg-b8ViW5YX5oRdYdiR4gMSDDB3mbkInMNUFT-PK5CuZRnHB2rUK5fhPuF6XFqLLZCG5Q_rJm6Evex-XLcNQAJNa1-6CIU12Wj3mPExxw9vbnsQDU7B4BfmhdyiflLA7Ae5ZGoVRl3A__yLPXxRjHFhpOeDp_adx8NyejF5cz9yDKULugNsDMdlHeJQOMGVLYaSZt3KP6aWNSqFA1PHDg-10ceuTEtq_vPE4-Gtev4N4K4Eudlj4Q')
      alg = Sandal::Enc::Alg::RSA1_5.new(OpenSSL::PKey::RSA.new(2048))
      expect { alg.decrypt_key(encrypted_key) }.to raise_error Sandal::InvalidTokenError
    end

  end

end