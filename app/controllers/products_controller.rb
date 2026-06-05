class ProductsController < ApplicationController
  before_action :ensure_cinema_assigned, except: [:index]
  before_action :ensure_active_workday, only: [:destroy, :bulk_update]
  before_action :set_product, only: [:destroy]

  def index
    @cinema_assigned = inventory_cinema.present?
    @active_workday = current_workday
    @products = @cinema_assigned ? inventory_cinema.products.order(:created_at) : Product.none
    @new_product = Product.new
  end

  def create
    @new_product = Product.new(product_params)
    @new_product.cinema_id = inventory_cinema&.id
    if @new_product.save
      redirect_to products_path, notice: "Product was successfully created."
    else
      @cinema_assigned = inventory_cinema.present?
      @active_workday = current_workday
      @products = @cinema_assigned ? inventory_cinema.products.order(:created_at) : Product.none
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: "Product was successfully deleted."
  end

  def bulk_update
    ActiveRecord::Base.transaction do
      total_bar_sales = BigDecimal('0')

      params.fetch(:products, {}).values.each do |product_data|
        next if product_data.blank?

        product = inventory_cinema.products.find(product_data[:id])
        sold_qty = product_data[:sold_qty].to_i
        arrived_qty = product_data[:arrived_qty].to_i
        next if sold_qty.zero? && arrived_qty.zero?

        new_amount = product.amount + arrived_qty - sold_qty
        raise ActiveRecord::RecordInvalid.new(product) if new_amount.negative?

        new_sold_amount = product.sold_amount + sold_qty

        product.update!(
          amount: new_amount,
          sold_amount: new_sold_amount
        )

        total_bar_sales += product.price.to_d * sold_qty
      end

      if total_bar_sales.positive?
        current_workday.update!(bar_sales_total: current_workday.bar_sales_total.to_d + total_bar_sales)
      end
    end
    redirect_to products_path, notice: "Inventory updated successfully."
  rescue => e
    redirect_to products_path, alert: "Error updating inventory: #{e.message}"
  end

  private

  def ensure_cinema_assigned
    redirect_to root_path, alert: "You must be assigned to a cinema to access inventory." unless inventory_cinema
  end

  def ensure_active_workday
    redirect_to root_path, alert: "You must start an active shift before managing products." unless current_workday
  end

  def set_product
    @product = inventory_cinema.products.find(params[:id])
  end

  def inventory_cinema
    current_workday&.cinema || current_user.cinema
  end

  def product_params
    params.require(:product).permit(:name, :price, :amount, :sold_amount)
  end
end
