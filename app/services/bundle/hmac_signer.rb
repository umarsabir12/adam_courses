# frozen_string_literal: true

require 'openssl'

module Bundle
  class HmacSigner
    def initialize(secret:)
      @secret = secret
    end

    # payload: Hash
    def sign(payload)
      data = canonical_string(payload)
      OpenSSL::HMAC.hexdigest('SHA256', @secret, data)
    end

    def valid?(payload, signature)
      expected = sign(payload)
      secure_compare(signature.to_s, expected)
    end

    private

    def canonical_string(obj)
      case obj
      when Hash
        obj.keys.sort.map { |k| "#{k}:#{canonical_string(obj[k])}" }.join('|')
      when Array
        obj.map { |v| canonical_string(v) }.join(',')
      else
        obj.to_s
      end
    end

    # ActiveSupport::SecurityUtils.secure_compare is fine too, but avoid dep here
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize
      l = a.unpack('C*')
      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end



