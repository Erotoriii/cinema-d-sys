class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Role-based access control
  enum :role, { staff: "staff", manager: "manager", admin: "admin" }, default: :staff

  # Validations
  validates :role, presence: true

  # Custom methods
  def admin_or_manager?
    admin? || manager?
  end
end
