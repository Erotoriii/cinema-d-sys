class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  belongs_to :company, optional: true
  belongs_to :cinema, optional: true
  has_many :workdays, dependent: :destroy

  enum :role, { staff: "staff", manager: "manager", admin: "admin" }, default: :staff

  validates :role, presence: true
  validates :email, presence: true, uniqueness: true

  def admin_or_manager?
    admin? || manager?
  end
end
