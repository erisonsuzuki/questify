require "test_helper"

class LoginBucketTest < ActiveSupport::TestCase
  setup do
    @prefix = SecureRandom.uuid
    @names = %w[LOGIN_ACCOUNT_LIMIT LOGIN_IP_LIMIT RECENT_AUTH_ACCOUNT_LIMIT
                REGISTRATION_IP_LIMIT MAIL_ACCOUNT_LIMIT MAIL_IP_LIMIT]
    @saved = @names.to_h { |name| [name, ENV[name]] }
    @names.each { |name| ENV.delete(name) }
  end

  teardown do
    @saved.each { |name, value| value ? ENV[name] = value : ENV.delete(name) }
  end

  test "account_failures_span_ips_and_expire_at_fifteen_minutes" do
    travel_to Time.utc(2026, 11, 1, 12) do
      email = "#{@prefix}@example.com"
      10.times do |i|
        assert_equal false, LoginBucket.authenticate(email: email, ip: "192.0.2.#{i + 1}") { false }
      end
      error = assert_raises(LoginBucket::Limited) do
        LoginBucket.authenticate(email: email, ip: "198.51.100.1") { true }
      end
      assert_equal 900, error.retry_after
      travel 15.minutes
      assert_equal true, LoginBucket.authenticate(email: email, ip: "198.51.100.1") { true }
    end
  end

  test "ip_failure_budget_is_shared_across_account_identifiers" do
    100.times do |i|
      LoginBucket.authenticate(email: "#{@prefix}-#{i}@example.com", ip: "192.0.2.1") { false }
    end
    assert_raises(LoginBucket::Limited) do
      LoginBucket.authenticate(email: "#{@prefix}-new@example.com", ip: "192.0.2.1") { true }
    end
  end

  test "successful_login_does_not_erase_rolling_failures" do
    email = "#{@prefix}@example.com"
    9.times { LoginBucket.authenticate(email: email, ip: "192.0.2.1") { false } }
    assert LoginBucket.authenticate(email: email, ip: "192.0.2.1") { true }
    LoginBucket.authenticate(email: email, ip: "192.0.2.1") { false }
    assert_raises(LoginBucket::Limited) do
      LoginBucket.authenticate(email: email, ip: "192.0.2.1") { true }
    end
  end

  test "registration_ip_allows_five_requests_per_rolling_hour" do
    travel_to Time.utc(2026, 11, 1, 12) do
      5.times { |i| LoginBucket.registration!(email: "#{@prefix}-#{i}@example.com", ip: "192.0.2.1") }
      error = assert_raises(LoginBucket::Limited) do
        LoginBucket.registration!(email: "#{@prefix}-six@example.com", ip: "192.0.2.1")
      end
      assert_equal 3600, error.retry_after
      travel 1.hour
      assert LoginBucket.registration!(email: "#{@prefix}-six@example.com", ip: "192.0.2.1")
    end
  end

  test "verification_and_reset_share_the_identifier_mail_budget" do
    email = "#{@prefix}@example.com"
    LoginBucket.registration!(email: email, ip: "192.0.2.1")
    2.times { LoginBucket.mail_request!(email: email, ip: "192.0.2.1") }
    assert_raises(LoginBucket::Limited) do
      LoginBucket.mail_request!(email: email, ip: "198.51.100.1")
    end
  end

  test "mail_ip_budget_is_shared_across_identifiers" do
    10.times { |i| LoginBucket.mail_request!(email: "#{@prefix}-#{i}@example.com", ip: "192.0.2.1") }
    assert_raises(LoginBucket::Limited) do
      LoginBucket.mail_request!(email: "#{@prefix}-eleven@example.com", ip: "192.0.2.1")
    end
  end

  test "invalid_configuration_fails_closed" do
    ENV["LOGIN_IP_LIMIT"] = "0"
    assert_raises(LoginBucket::InvalidConfiguration) do
      LoginBucket.authenticate(email: "#{@prefix}@example.com", ip: "192.0.2.1") { flunk }
    end
  end
end
