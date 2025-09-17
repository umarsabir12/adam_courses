# frozen_string_literal: true

module Bundle
  class PricingEngine
    LineItem = Struct.new(
      :sku,
      :title,
      :type,
      :msrp,
      :price,
      :discount,
      :net,
      :is_gift,
      :badges,
      keyword_init: true
    )

    Result = Struct.new(
      :line_items,
      :totals,
      :tier,
      :scope,
      :percent_off,
      :course_count,
      :gift_count_allowed,
      :gift_pool_skus,
      :rule_version,
      keyword_init: true
    )

    def initialize(config:, products:, rounding_mode: nil)
      @config = config
      @products_by_sku = products.index_by { |p| p['sku'] }
      @rounding_mode = rounding_mode || config.dig('flags', 'roundingMode') || 'half_up'
    end

    # items: array of skus
    # selected_gifts: array of gift skus explicitly selected (optional)
    def price(items:, selected_gifts: [])
      products = items.map { |sku| @products_by_sku[sku] }.compact
      course_count = products.count { |p| course_counts_toward_threshold?(p) }

      tier = applicable_tier(course_count)
      scope = tier&.fetch('scope', nil)
      percent_off = tier&.fetch('percentOff', 0).to_i
      gift_count_allowed = tier&.fetch('giftCount', 0).to_i
      gift_pool_skus = tier&.fetch('giftPoolSkus', []) || []
      rule_version = @config['ruleVersion']

      # Validate selected gifts against pool and allowed count
      valid_selected_gifts = (selected_gifts & gift_pool_skus).first(gift_count_allowed)

      line_items = []

      # Paid items
      products.each do |prod|
        msrp = to_bd(prod['msrp'])
        price = msrp
        discount = BigDecimal('0')
        net = msrp
        badges = [badge_for_type(prod['type'])]

        if tier
          if scope == 'entire_cart' || (scope == 'courses_only' && prod['type'] == 'course')
            discount = apply_percent(msrp, percent_off)
            net = msrp - discount
          end
        end

        line_items << LineItem.new(
          sku: prod['sku'],
          title: prod['title'],
          type: prod['type'],
          msrp: format_money(msrp),
          price: format_money(price),
          discount: format_money(discount),
          net: format_money(net),
          is_gift: false,
          badges: badges
        )
      end

      # Gifts (zero-priced)
      valid_selected_gifts.each do |gift_sku|
        prod = @products_by_sku[gift_sku]
        next unless prod

        msrp = to_bd(prod['msrp'])
        line_items << LineItem.new(
          sku: prod['sku'],
          title: prod['title'],
          type: 'gift',
          msrp: format_money(msrp),
          price: format_money(BigDecimal('0')),
          discount: format_money(msrp),
          net: format_money(BigDecimal('0')),
          is_gift: true,
          badges: ['Gift']
        )
      end

      # Sort: paid courses, paid add-ons, gifts last
      line_items.sort_by! do |li|
        [li.is_gift ? 2 : 0, li.type == 'addon' ? 1 : 0, sort_order_for(li.sku)]
      end

      subtotal = sum_bd(line_items.reject(&:is_gift).map { |li| li.price })
      discount_total = sum_bd(line_items.map { |li| li.discount })
      total = subtotal - discount_total

      Result.new(
        line_items: line_items.map { |li| serialize_line_item(li) },
        totals: serialize_totals(subtotal, discount_total, total),
        tier: tier ? @config['tiers'].index(tier) + 1 : 0,
        scope: scope,
        percent_off: percent_off,
        course_count: course_count,
        gift_count_allowed: gift_count_allowed,
        gift_pool_skus: gift_pool_skus,
        rule_version: rule_version
      )
    end

    private

    def course_counts_toward_threshold?(product)
      product['type'] == 'course' && product.fetch('countsTowardThreshold', true)
    end

    def applicable_tier(course_count)
      tiers = @config['tiers'] || []
      tiers.select { |t| course_count >= t['minCourses'].to_i }.max_by { |t| t['minCourses'].to_i }
    end

    def badge_for_type(type)
      case type
      when 'course' then 'Course'
      when 'addon' then 'Add-on'
      when 'gift' then 'Gift'
      else 'Item'
      end
    end

    def sort_order_for(sku)
      prod = @products_by_sku[sku]
      prod ? prod['sortOrder'].to_i : 9999
    end

    def to_bd(num)
      BigDecimal(num.to_s)
    end

    def apply_percent(amount, percent)
      discount = amount * BigDecimal(percent.to_s) / BigDecimal('100')
      round_money(discount)
    end

    def round_money(amount)
      # Default: half_up; supported: half_up, half_even
      mode = @rounding_mode.to_s
      if mode == 'half_even'
        amount.round(2, BigDecimal::ROUND_HALF_EVEN)
      else
        amount.round(2, BigDecimal::ROUND_HALF_UP)
      end
    end

    def format_money(amount)
      round_money(to_bd(amount)).to_s('F')
    end

    def sum_bd(amount_strings)
      amount_strings.reduce(BigDecimal('0')) { |acc, s| acc + to_bd(s) }
    end

    def serialize_line_item(li)
      {
        sku: li.sku,
        title: li.title,
        type: li.type,
        msrp: li.msrp.to_f,
        price: li.price.to_f,
        discount: li.discount.to_f,
        net: li.net.to_f,
        isGift: li.is_gift,
        badges: li.badges
      }
    end

    def serialize_totals(subtotal, discount_total, total)
      {
        subtotal: round_money(subtotal).to_f,
        discount: round_money(discount_total).to_f,
        total: round_money(total).to_f
      }
    end
  end
end



