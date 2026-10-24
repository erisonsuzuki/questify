require "test_helper"
require "stringio"

class CredentialDeliveryTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(kind: "account", last_online_at: Time.current)
    @account = Account.create!(user: @user, email: "#{SecureRandom.uuid}@example.com",
                               password: "foundation-password-123", verified_at: Time.current)
    @access = AccessSession.create!(user: @user, last_seen_at: Time.current,
                                    absolute_expires_at: 30.days.from_now, authenticated_at: Time.current)
  end

  def send_json(path, body)
    get "/v1/bootstrap"
    csrf = JSON.parse(response.body).fetch("csrf_token")
    post path, params: body.to_json, headers: {
      "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json", "X-CSRF-Token" => csrf
    }
  end

  test "credential_queue_and_logs_exclude_raw_tokens" do
    raw = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    row = CredentialToken.find_by!(digest: Digest::SHA256.hexdigest(raw))
    assert row.delivery_payload.present?
    assert_not_includes row.delivery_payload, raw
    assert_nil ActionMailer::Base.logger
    assert_not ActiveJob::Base.log_arguments
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    old_rails_logger = Rails.logger
    old_job_logger = ActiveJob::Base.logger
    queued = nil
    begin
      Rails.logger = logger
      ActiveJob::Base.logger = logger
      job = CredentialToken.enqueue_delivery!(raw)
      queued = SolidQueue::Job.find_by!(active_job_id: job.job_id)
      assert_not_includes queued.arguments.to_json, raw
      assert_not_includes queued.arguments.to_json, @account.email
      assert_includes queued.arguments.to_json, row.id
      before = ActionMailer::Base.deliveries.length
      CredentialDeliveryJob.perform_now(row.id)
      assert_equal before + 1, ActionMailer::Base.deliveries.length
      assert_includes ActionMailer::Base.deliveries.last.body.decoded, raw
      assert_nil row.reload.delivery_payload
      assert_not_includes output.string, raw
      assert_not_includes output.string, "#reset="
    ensure
      Rails.logger = old_rails_logger
      ActiveJob::Base.logger = old_job_logger
      queued&.destroy!
    end
  end

  test "invalid_replacement_preserves_token_password_and_sessions" do
    [nil, "", "   ", "short", "x" * 73].each do |replacement|
      raw = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
      row = CredentialToken.find_by!(digest: Digest::SHA256.hexdigest(raw))
      original_digest = @account.reload.password_digest
      original_payload = row.delivery_payload
      send_json("/v1/password_reset/consume", token: raw, password: replacement)
      assert_response :unprocessable_entity
      assert_nil row.reload.consumed_at
      assert_equal original_payload, row.delivery_payload
      assert_equal original_digest, @account.reload.password_digest
      assert_nil @access.reload.revoked_at
      send_json("/v1/password_reset/consume", token: raw, password: "replacement-password-123")
      assert_response :success
      assert @account.reload.authenticate("replacement-password-123")
      @access = AccessSession.create!(user: @user, last_seen_at: Time.current,
                                      absolute_expires_at: 30.days.from_now, authenticated_at: Time.current)
    end
  end

  test "successful_reset_revokes_sessions_and_all_reset_tokens_once" do
    first = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    second = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    send_json("/v1/password_reset/consume", token: first, password: "replacement-password-123")
    assert_response :success
    assert @access.reload.revoked_at
    assert @account.reload.authenticate("replacement-password-123")
    assert_not @account.authenticate("foundation-password-123")
    assert @account.credential_tokens.where(purpose: "reset").all? { |row| row.consumed_at && row.delivery_payload.nil? }
    [first, second].each do |raw|
      send_json("/v1/password_reset/consume", token: raw, password: "another-password-123")
      assert_response :unprocessable_entity
      assert @account.reload.authenticate("replacement-password-123")
    end
  end

  test "password_minimum_is_ten_characters" do
    raw = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    row = CredentialToken.find_by!(digest: Digest::SHA256.hexdigest(raw))
    send_json("/v1/password_reset/consume", token: raw, password: "a" * 9)
    assert_response :unprocessable_entity
    assert_nil row.reload.consumed_at
    assert_nil @access.reload.revoked_at
    send_json("/v1/password_reset/consume", token: raw, password: "a" * 10)
    assert_response :success
    assert @account.reload.authenticate("a" * 10)
    assert @access.reload.revoked_at
  end

  test "new_reset_request_invalidates_previous_link_and_pending_delivery" do
    previous = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    previous_row = CredentialToken.find_by!(digest: Digest::SHA256.hexdigest(previous))
    send_json("/v1/password_reset", email: @account.email)
    assert_response :accepted
    assert previous_row.reload.consumed_at
    assert_nil previous_row.delivery_payload
    send_json("/v1/password_reset/consume", token: previous, password: "replacement-password-123")
    assert_response :unprocessable_entity
    assert @account.reload.authenticate("foundation-password-123")
    assert_nil @access.reload.revoked_at
  end
end
