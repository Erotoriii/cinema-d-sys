class UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_user, only: [:edit, :update, :destroy]

  # GET /staff
  def index
    @users = User.where(company_id: current_user.company_id).where.not(role: 'admin').order(:email)
  end

  # GET /staff/new
  def new
    @user = User.new
  end

# Create a new user action.
  # 1. Initialize user with user_params.
  # 2. Assign current_user's company_id to the new user.
  # 3. Check the role: if 'admin', use the email from params.
  # 4. If not 'admin', dynamically set the email as: params[:user][:username] + "@" + current_user.company.domain_prefix + ".ua".
  # 5. Save the user. If successful, redirect to users_path with a notice. Else, render :new.
  def create
    @user = User.new(user_params)
    @user.company_id = current_user.company_id

    if @user.role == 'admin'
      @user.email = params[:user][:email]
    else
      @user.email = "#{params[:user][:username]}@#{current_user.company.domain_prefix}.ua"
    end

    if @user.save
      redirect_to users_path, notice: "User was successfully created."
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
    params.require(:user).permit(:password, :password_confirmation, :role, :cinema_id)
  end
end
