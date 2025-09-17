class CreateCourses < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.integer :woocommerce_id
      t.string :name
      t.text :description
      t.decimal :price
      t.string :status
      t.string :sku
      t.string :image_url
      t.string :permalink

      t.timestamps
    end
  end
end
