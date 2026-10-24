require "test_helper"

class CredentialTokenTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    travel_to Time.utc(2026, 11, 1, 12)
    @user = User.create!(kind: "account", last_online_at: Time.current)
    @account = Account.create!(user: @user, email: "#{SecureRandom.uuid}@example.com",
                               password: "foundation-password-123")
  end

  teardown do
    ApplicationRecord.transaction do
      CredentialToken.where(account_id: @account.id).delete_all
      AccessSession.where(user_id: @user.id).delete_all
      Account.where(id: @account.id).delete_all
      User.where(id: @user.id).delete_all
    end
    assert_not User.exists?(@user.id)
    assert_not Account.exists?(@account.id)
    assert_not AccessSession.exists?(user_id: @user.id)
    assert_not CredentialToken.exists?(account_id: @account.id)
  ensure
    travel_back
  end

  test "reset_expires_after_thirty_minutes" do
    raw = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    travel 30.minutes do
      assert_raises(CredentialToken::Invalid) do
        CredentialToken.consume!(raw, purpose: "reset") { flunk "expired token yielded" }
      end
    end
  end

  test "reset_is_single_use_under_concurrency_and_revokes_sessions" do
    access = AccessSession.create!(user: @user, last_seen_at: Time.current,
                                   absolute_expires_at: 30.days.from_now, authenticated_at: Time.current)
    raw = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          begin
            CredentialToken.consume!(raw, purpose: "reset") do |account|
              account.update!(password: "replacement-password-123")
              account.user.access_sessions.where(revoked_at: nil).update_all(revoked_at: Time.current)
              account.credential_tokens.where(purpose: "reset", consumed_at: nil).update_all(consumed_at: Time.current)
            end
            results << :used
          rescue CredentialToken::Invalid
            results << :rejected
          end
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)
    assert_equal [:rejected, :used], 2.times.map { results.pop }.sort
    assert access.reload.revoked_at
    assert @account.reload.authenticate("replacement-password-123")
    assert_not @account.authenticate("foundation-password-123")
  end
end
