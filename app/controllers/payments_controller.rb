# frozen_string_literal: true

class PaymentsController < ApplicationController
  protect_from_forgery except: :create_session

  def index
    @courses = Course.order(:name)
  end

  def create_session
    price_cents = params[:amount_cents].presence || 1000 # $10 default
    currency = params[:currency].presence || 'usd'

    # If no Stripe API key, simulate checkout and redirect to success URL
    if ENV["STRIPE_SECRET_KEY"].blank?
      simulated_url = params[:success_url].presence || (root_url + '?paid=1')
      return render json: { url: simulated_url, simulated: true }
    end

    session = Stripe::Checkout::Session.create(
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: currency,
            unit_amount: price_cents.to_i,
            product_data: { name: params[:name].presence || 'Test Bundle' }
          },
          quantity: 1
        }
      ],
      success_url: params[:success_url].presence || root_url + '?paid=1',
      cancel_url: params[:cancel_url].presence || root_url + '?canceled=1'
    )

    render json: { url: session.url }
  rescue => e
    render json: { error: e.message }, status: 422
  end
end


