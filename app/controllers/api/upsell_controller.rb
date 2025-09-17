# frozen_string_literal: true

module Api
  class UpsellController < ApplicationController
    protect_from_forgery with: :null_session

    def show
      upsell = (Rails.configuration.x.bundle.config || {})['upsell'] || {}
      enabled = upsell['enabled'] && feature_flag?(:otoEnabled)
      if enabled && eligible_once?
        render json: {
          status: 'eligible',
          sku: upsell['sku'],
          price: upsell['price'],
          timerMinutes: upsell['timerMinutes']
        }
      else
        render json: { status: 'not_eligible' }
      end
    end

    def add
      body = params.permit(:sessionId)
      # This is where we'd attach the OTO SKU to an existing external checkout session.
      render json: { status: 'added', sessionId: body[:sessionId] }
    end

    private

    def feature_flag?(name)
      Rails.configuration.x.bundle.flags[name.to_s]
    end

    def eligible_once?
      # TODO: Replace with server-side store keyed to user/session/email
      session[:upsell_shown] ||= false
      return false if session[:upsell_shown]
      session[:upsell_shown] = true
      true
    end
  end
end



