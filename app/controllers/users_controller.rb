class UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_user, only: [:edit, :update, :destroy]

  # GET /staff
  def index
    @users = User.where.not(role: 'admin').order(:email)
  end

  # GET /staff/new
  def new
    @user = User.new
  end

  # POST /staff
  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_url, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /staff/:id/edit
  def edit
  end

  # PATCH/PUT /staff/:id
  def update
    if @user.update(user_params)
      redirect_to users_url, notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /staff/:id
  def destroy
    @user.destroy
    redirect_to users_url, notice: "User was successfully deleted."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role)
  end
end
