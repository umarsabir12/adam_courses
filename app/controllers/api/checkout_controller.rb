# frozen_string_literal: true

module Api
  class CheckoutController < ApplicationController
    protect_from_forgery with: :null_session

    def session
      body = params.permit(:currency, :locale, payload: {})
      payload = body[:payload] || {}

      signer = Bundle::HmacSigner.new(secret: hmac_secret)
      signature = payload[:signature] || payload['signature']
      audit = payload.except(:signature, 'signature')

      unless signer.valid?(audit, signature)
        return render json: { error: 'Invalid pricing signature' }, status: :unprocessable_entity
      end

      # Revalidate with server pricing to prevent tampering
      config = Rails.configuration.x.bundle.config
      products = Rails.configuration.x.bundle.products
      engine = Bundle::PricingEngine.new(
        config: config, products: products,
        rounding_mode: Rails.configuration.x.bundle.flags['roundingMode']
      )

      items = Array(audit[:items] || audit['items']).reject { |i| i['isGift'] }.map { |i| i['sku'] }
      selected_gifts = Array(audit[:items] || audit['items']).select { |i| i['isGift'] }.map { |i| i['sku'] }
      server_result = engine.price(items: items, selected_gifts: selected_gifts)

      server_audit = server_result.to_h.slice(
        :tier, :scope, :percent_off, :course_count, :gift_count_allowed, :rule_version
      ).merge(items: server_result.line_items, totals: server_result.totals)

      unless audits_match?(audit, server_audit)
        return render json: { error: 'Pricing mismatch on revalidation' }, status: :unprocessable_entity
      end

      # Create a checkout session with external processor here and return redirect URL
      session_id = SecureRandom.uuid
      redirect_url = "/checkout/redirect/#{session_id}"

      render json: { sessionId: session_id, redirectUrl: redirect_url }
    end

    private

    def audits_match?(client, server)
      client.to_json == server.to_json
    end

    def hmac_secret
      ENV['BUNDLE_HMAC_SECRET'] || Rails.application.credentials.dig(:bundle, :hmac_secret) || 'dev-secret-change-me'
    end
  end
end



