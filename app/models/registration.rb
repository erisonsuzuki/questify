class Registration < ApplicationRecord
  before_create { self.id ||= SecureRandom.uuid }
  belongs_to :account
  belongs_to :source_user, class_name: "User", optional: true
  attr_readonly :account_id, :source_user_id
end
