require "test_helper"

class FoundationPrerequisiteTest < ActiveSupport::TestCase
  test "identity_models_support_request_prerequisites" do
    user = User.create!(kind: "account", last_online_at: Time.current)
    account = Account.create!(user: user, email: "prerequisite@example.com",
                              password: "foundation-password-123")
    assert_equal "user:#{user.id}", user.namespace
    assert account.authenticate("foundation-password-123")
    row = AccessSession.create!(user: user, last_seen_at: Time.current,
                                absolute_expires_at: 30.days.from_now)
    assert row.active?
    assert_not row.recent?
    assert_equal 0, Registration.where(account: account).count
    assert LoginBucket.table_exists?
    assert CredentialToken.table_exists?
  end
end
