class ProductInventoryService
  def initialize(cinema:, workday:)
    @cinema = cinema
    @workday = workday
  end

  def bulk_update(products_data)
    ActiveRecord::Base.transaction do
      total_bar_sales = BigDecimal('0')

      products_data.each do |_key, product_data|
        next if product_data.blank?

        product = cinema.products.find(product_data[:id])
        sold_qty = product_data[:sold_qty].to_i
        arrived_qty = product_data[:arrived_qty].to_i
        next if sold_qty.zero? && arrived_qty.zero?

        update_product_inventory(product, sold_qty, arrived_qty)
        total_bar_sales += product.price.to_d * sold_qty
      end

      update_workday_bar_sales(total_bar_sales) if total_bar_sales.positive?
    end

    { success: true, message: "Inventory updated successfully." }
  rescue StandardError => e
    { success: false, message: "Error updating inventory: #{e.message}" }
  end

  private

  attr_reader :cinema, :workday

  def update_product_inventory(product, sold_qty, arrived_qty)
    new_amount = product.amount + arrived_qty - sold_qty
    raise InvalidInventory.new(product) if new_amount.negative?

    new_sold_amount = product.sold_amount + sold_qty

    product.update!(
      amount: new_amount,
      sold_amount: new_sold_amount
    )
  end

  def update_workday_bar_sales(total_bar_sales)
    workday.update!(bar_sales_total: workday.bar_sales_total.to_d + total_bar_sales)
  end

  class InvalidInventory < StandardError
    def initialize(product)
      super("Invalid inventory for product #{product.name}")
    end
  end
end
