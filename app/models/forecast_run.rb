class ForecastRun < ApplicationRecord
  has_many :forecasts, dependent: :destroy

  attribute :params, :json, default: {}

  validates :run_at, presence: true
  validates :horizon_days, numericality: { greater_than: 0 }
end
