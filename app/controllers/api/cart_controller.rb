# frozen_string_literal: true

module Api
  class CartController < ApplicationController
    protect_from_forgery with: :null_session

    def price
      body = params.permit(items: [], context: {}, selectedGifts: [])
      items = Array(body[:items]).map(&:to_s)
      selected_gifts = Array(body[:selectedGifts]).map(&:to_s)

      config = Rails.configuration.x.bundle.config
      products = Rails.configuration.x.bundle.products

      engine = Bundle::PricingEngine.new(
        config: config,
        products: products,
        rounding_mode: Rails.configuration.x.bundle.flags['roundingMode']
      )
      result = engine.price(items: items, selected_gifts: selected_gifts)

      audit_payload = result.to_h.slice(
        :tier, :scope, :percent_off, :course_count, :gift_count_allowed, :rule_version
      ).merge(items: result.line_items, totals: result.totals)

      signer = Bundle::HmacSigner.new(secret: hmac_secret)
      signature = signer.sign(audit_payload)

      render json: audit_payload.merge(signature: signature)
    end

    def gifts
      body = params.permit(items: [], selectedGifts: [])
      items = Array(body[:items]).map(&:to_s)
      selected_gifts = Array(body[:selectedGifts]).map(&:to_s)

      config = Rails.configuration.x.bundle.config
      products = Rails.configuration.x.bundle.products

      engine = Bundle::PricingEngine.new(
        config: config,
        products: products,
        rounding_mode: Rails.configuration.x.bundle.flags['roundingMode']
      )
      result = engine.price(items: items, selected_gifts: selected_gifts)

      render json: {
        selectedGifts: result.gift_pool_skus & selected_gifts,
        giftCountAllowed: result.gift_count_allowed,
        giftPoolSkus: result.gift_pool_skus
      }
    end

    private

    def hmac_secret
      ENV['BUNDLE_HMAC_SECRET'] || Rails.application.credentials.dig(:bundle, :hmac_secret) || 'dev-secret-change-me'
    end
  end
end



