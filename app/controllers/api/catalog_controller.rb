# frozen_string_literal: true

module Api
  class CatalogController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      products = Rails.configuration.x.bundle.products || []
      visible = products.select { |p| p['visible'] }
      config = Rails.configuration.x.bundle.config || {}

      render json: {
        products: visible.sort_by { |p| p['sortOrder'].to_i },
        config: config.slice('tiers', 'upsell', 'flags', 'ruleVersion')
      }
    end
  end
end



