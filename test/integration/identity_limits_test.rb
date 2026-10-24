require "test_helper"

class IdentityLimitsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 1, 12)
    @user = User.create!(kind: "account", last_online_at: Time.current)
    @account = Account.create!(user: @user, email: "#{SecureRandom.uuid}@example.com",
                               password: "foundation-password-123", verified_at: Time.current)
  end

  teardown do
    travel_back
  end

  def send_json(path, body)
    get "/v1/bootstrap"
    csrf = JSON.parse(response.body).fetch("csrf_token")
    post path, params: body.to_json, headers: {
      "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json", "X-CSRF-Token" => csrf
    }
  end

  test "recent_auth_five_failures_block_until_window_expiry" do
    send_json("/v1/login", email: @account.email, password: "foundation-password-123")
    assert_response :success
    row = @user.access_sessions.order(:created_at).last
    original = row.authenticated_at
    5.times do
      send_json("/v1/recent_auth", password: "incorrect")
      assert_response :unauthorized
    end
    send_json("/v1/recent_auth", password: "foundation-password-123")
    assert_response :too_many_requests
    assert response.headers.fetch("Retry-After").to_i.positive?
    assert_equal original, row.reload.authenticated_at
    travel 15.minutes
    send_json("/v1/recent_auth", password: "foundation-password-123")
    assert_response :success
    assert row.reload.authenticated_at > original
  end

  test "mail_responses_are_generic_and_throttling_has_no_side_effects" do
    send_json("/v1/password_reset", email: @account.email)
    assert_response :accepted
    existing_body = response.body
    send_json("/v1/password_reset", email: "#{SecureRandom.uuid}@example.com")
    assert_response :accepted
    assert_equal existing_body, response.body
    2.times do
      send_json("/v1/password_reset", email: @account.email)
      assert_response :accepted
    end
    token_count = @account.credential_tokens.count
    queue_count = SolidQueue::Job.count
    send_json("/v1/password_reset", email: @account.email)
    assert_response :too_many_requests
    assert response.headers.fetch("Retry-After").to_i.positive?
    assert_equal token_count, @account.credential_tokens.count
    assert_equal queue_count, SolidQueue::Job.count
  end

  test "invalid_registration_counts_without_disclosing_existing_email" do
    [@account.email, "#{SecureRandom.uuid}@example.com"].each do |email|
      send_json("/v1/register", email: email, password: "short")
      assert_response :unprocessable_entity
      assert_equal "invalid_input", JSON.parse(response.body).dig("error", "code")
    end
    3.times do
      send_json("/v1/register", email: "#{SecureRandom.uuid}@example.com", password: "short")
      assert_response :unprocessable_entity
    end
    account_count = Account.count
    send_json("/v1/register", email: "#{SecureRandom.uuid}@example.com", password: "foundation-password-123")
    assert_response :too_many_requests
    assert response.headers.fetch("Retry-After").to_i.positive?
    assert_equal account_count, Account.count
  end
end
