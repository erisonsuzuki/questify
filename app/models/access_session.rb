class AccessSession < ApplicationRecord
  before_create { self.id ||= SecureRandom.uuid }
  belongs_to :user

  def active?(now = Time.current)
    revoked_at.nil? && last_seen_at > now - 14.days && absolute_expires_at > now
  end

  def recent?(now = Time.current)
    authenticated_at.present? && authenticated_at > now - 10.minutes
  end
end
