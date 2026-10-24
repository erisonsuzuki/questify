class CredentialToken < ApplicationRecord
  class Invalid < StandardError; end

  before_create { self.id ||= SecureRandom.uuid }
  belongs_to :account

  def self.issue!(account, purpose:, lifetime:)
    raw = SecureRandom.urlsafe_base64(32)
    create!(account: account, purpose: purpose,
            digest: Digest::SHA256.hexdigest(raw),
            delivery_payload: delivery_encryptor.encrypt_and_sign(raw),
            expires_at: lifetime.from_now)
    raw
  end

  def self.delivery_encryptor
    key = Rails.application.key_generator.generate_key("credential-delivery-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def self.enqueue_delivery!(raw)
    row = find_by!(digest: Digest::SHA256.hexdigest(raw))
    CredentialDeliveryJob.perform_later(row.id)
  end

  def self.consume!(raw, purpose:)
    transaction do
      candidate = find_by(digest: Digest::SHA256.hexdigest(raw.to_s), purpose: purpose)
      raise Invalid unless candidate

      # Account-first locks serialize consumption, reset issuance and delivery.
      candidate.account.lock!
      candidate.lock!
      raise Invalid if candidate.consumed_at || candidate.expires_at <= Time.current

      yield candidate.account
      candidate.update!(consumed_at: Time.current, delivery_payload: nil)
    end
  end
end
