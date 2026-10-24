class Account < ApplicationRecord
  before_create { self.id ||= SecureRandom.uuid }
  belongs_to :user
  has_many :credential_tokens, dependent: :delete_all
  has_secure_password reset_token: false
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }, allow_nil: true
  validate :bcrypt_byte_limit

  def verified?
    verified_at.present?
  end

  private

  def bcrypt_byte_limit
    if password && password.bytesize > 72
      errors.add(:password, "deve ter no máximo 72 bytes")
    end
  end
end
