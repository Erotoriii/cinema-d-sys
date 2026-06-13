class ProductsController < ApplicationController
  before_action :ensure_cinema_assigned, except: [:index]
  before_action :ensure_active_workday, only: [:destroy, :bulk_update]
  before_action :set_product, only: [:destroy, :edit, :update]
  before_action :authorize_manager_or_admin!, only: [:edit, :update]

  def index
    @cinema_assigned = inventory_cinema.present?
    @active_workday = current_workday
    @products = @cinema_assigned ? inventory_cinema.products.order(created_at: :desc) : Product.none
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

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: "Product was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def bulk_update
    result = ProductInventoryService.new(
      cinema: inventory_cinema,
      workday: current_workday
    ).bulk_update(params.fetch(:products, {}))

    if result[:success]
      redirect_to products_path, notice: result[:message]
    else
      redirect_to products_path, alert: result[:message]
    end
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
    @inventory_cinema ||= (current_workday&.cinema || current_user.cinema)
  end

  def product_params
    params.require(:product).permit(:name, :price, :amount, :sold_amount)
  end

  def authorize_manager_or_admin!
    redirect_to products_path, alert: "You are not authorized to edit products." unless current_user.admin_or_manager?
  end
end
