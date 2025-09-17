# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class WoocommerceApiService
  BASE_URI = 'https://adamlanesmith.com/wp-json/wc/v3'
  
  def initialize
    @consumer_key = 'ck_66f1fefdac7f7a5581a056178f833f41644f29cb'
    @consumer_secret = 'cs_0db81e1ee98b2372527ced8eeea3d49aab6b8873'
  end
  
  def fetch_products(page: 1, per_page: 100)
    uri = URI.parse("#{BASE_URI}/products")
    params = {
      consumer_key: @consumer_key,
      consumer_secret: @consumer_secret,
      page: page,
      per_page: per_page
    }
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'adam-courses/1.0 (Rails)'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 20
    http.open_timeout = 10

    response = http.request(request)

    # Follow one redirect if present
    if %w[301 302 307 308].include?(response.code)
      redirected_uri = URI.parse(response['location'])
      response = Net::HTTP.get_response(redirected_uri)
    end

    if response.code == '200'
      products = JSON.parse(response.body)
      {
        products: products,
        total_pages: response['x-wp-totalpages']&.to_i || 1,
        total_products: response['x-wp-total']&.to_i || 0
      }
    else
      Rails.logger.error "WooCommerce API Error: #{response.code} - #{response.message}"
      { products: [], total_pages: 0, total_products: 0 }
    end
  rescue => e
    Rails.logger.error "WooCommerce API Error: #{e.class}: #{e.message}"
    { products: [], total_pages: 0, total_products: 0 }
  end
  
  def fetch_all_products
    all_products = []
    page = 1
    
    loop do
      result = fetch_products(page: page)
      all_products.concat(result[:products])
      
      break if page >= result[:total_pages]
      page += 1
    end
    
    all_products
  end
  
  def sync_products_to_database
    products = fetch_all_products
    synced_count = 0
    updated_count = 0
    
    products.each do |product_data|
      course = Course.find_or_initialize_by(woocommerce_id: product_data['id'])
      
      course.assign_attributes(
        name: product_data['name'],
        description: product_data['description'],
        price: product_data['price'].to_f,
        status: product_data['status'],
        sku: product_data['sku'],
        image_url: product_data.dig('images', 0, 'src'),
        permalink: product_data['permalink']
      )
      
      if course.new_record?
        course.save!
        synced_count += 1
      elsif course.changed?
        course.save!
        updated_count += 1
      end
    end
    
    {
      synced: synced_count,
      updated: updated_count,
      total_processed: products.count
    }
  end
end
