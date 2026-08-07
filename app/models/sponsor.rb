class Sponsor < ApplicationRecord
  include Archivable

  belongs_to :publication
  has_many :daily_calls, dependent: :nullify
  has_many :prizes, dependent: :nullify
  has_one_attached :logo

  normalizes :name, with: ->(n) { n.strip }

  validates :name, presence: true
  validates :website_url, http_url: true

  def daily_call_usage_count
    daily_calls.count
  end
end
