class User < ApplicationRecord
  before_create { self.id ||= SecureRandom.uuid }
  has_one :account, dependent: :restrict_with_exception
  has_many :access_sessions, dependent: :restrict_with_exception
  validates :kind, inclusion: { in: %w[guest account] }

  def namespace
    "user:#{id}"
  end
end
