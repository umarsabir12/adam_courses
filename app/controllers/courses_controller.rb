# frozen_string_literal: true

class CoursesController < ApplicationController
  def index
    @courses = Course.all.order(:name)
  end
  
  def sync
    service = WoocommerceApiService.new
    result = service.sync_products_to_database
    
    flash[:notice] = "Synced #{result[:synced]} new courses, updated #{result[:updated]} existing courses. Total processed: #{result[:total_processed]}"
    redirect_to courses_path
  end
  
  def show
    @course = Course.find(params[:id])
  end
end
