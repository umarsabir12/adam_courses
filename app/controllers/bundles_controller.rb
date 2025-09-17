# frozen_string_literal: true

class BundlesController < ApplicationController
  def builder
    @bundle_flags = Rails.configuration.x.bundle.flags
  end
end



