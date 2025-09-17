Rails.application.configure do
  config.x.bundle = ActiveSupport::OrderedOptions.new
  config_dir = Rails.root.join('config', 'bundle')

  config_file = config_dir.join('config.json')
  products_file = config_dir.join('products.json')

  config.x.bundle.enabled = true
  config.x.bundle.config = JSON.parse(File.read(config_file)) if File.exist?(config_file)
  config.x.bundle.products = JSON.parse(File.read(products_file)) if File.exist?(products_file)

  flags = config.x.bundle.config && config.x.bundle.config['flags'] || {}
  config.x.bundle.flags = {
    'bundlePromoEnabled' => flags.fetch('bundlePromoEnabled', true),
    'otoEnabled' => flags.fetch('otoEnabled', true),
    'roundingMode' => flags.fetch('roundingMode', 'half_up')
  }
end


