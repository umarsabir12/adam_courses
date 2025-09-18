# frozen_string_literal: true

class CheckoutsController < ApplicationController
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:create]

  def show
    @payload = session[:checkout_payload]
    unless @payload
      redirect_to root_path, alert: 'Cart is empty.'
      return
    end
  end

  def create
    @payload = params.require(:payload).permit!
    session[:checkout_payload] = @payload
    redirect_to checkout_path
  end
end


