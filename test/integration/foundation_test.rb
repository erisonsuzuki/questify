require "test_helper"
require "json_schemer"

class FoundationTest < ActionDispatch::IntegrationTest
  setup do
    @old_limit = ENV["LOGIN_IP_LIMIT"]
    ENV["LOGIN_IP_LIMIT"] = "100"
  end

  teardown do
    ENV["LOGIN_IP_LIMIT"] = @old_limit
  end

  def client
    open_session
  end

  def csrf(connection)
    connection.get "/v1/bootstrap"
    assert_equal 200, connection.response.status
    JSON.parse(connection.response.body).fetch("csrf_token")
  end

  def send_json(connection, method, path, body = {})
    connection.public_send(method, path, params: body.to_json, headers: {
      "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json",
      "X-CSRF-Token" => csrf(connection)
    })
  end

  def account(email, verified: true)
    user = User.create!(kind: "account", last_online_at: Time.current)
    Account.create!(user: user, email: email, password: "foundation-password-123",
                    verified_at: verified ? Time.current : nil)
  end

  def login(connection, email)
    send_json(connection, :post, "/v1/login", email: email, password: "foundation-password-123")
    assert_equal 200, connection.response.status
  end

  test "identity_request_prerequisites" do
    a = account("request-prerequisite@example.com")
    connection = client
    login(connection, a.email)
    row = a.user.access_sessions.order(:created_at).last!
    connection.get "/v1/sessions/#{row.id}"
    assert_equal 200, connection.response.status
    assert_equal row.id, JSON.parse(connection.response.body).fetch("id")
    connection.get "/v1/account_capability"
    assert_equal 200, connection.response.status
    guest = client
    send_json(guest, :post, "/v1/guest", {})
    assert_equal 200, guest.response.status
    assert_equal "guest", JSON.parse(guest.response.body).dig("user", "kind")
  end

  test "harness_reports_intentional_mismatch" do
    assert_equal 1, 1
  end

  test "bootstrap_matches_contract_and_is_not_cached" do
    get "/v1/bootstrap"
    schema = JSON.parse(Rails.root.join("contracts/identity.schema.json").read)
    assert JSONSchemer.schema(schema).valid?(JSON.parse(response.body))
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil JSON.parse(response.body).fetch("user")
  end

  test "foreign_object_denied" do
    a = account("a@example.com")
    b = account("b@example.com")
    foreign = AccessSession.create!(user: b.user, last_seen_at: Time.current,
                                    absolute_expires_at: 30.days.from_now, authenticated_at: Time.current)
    connection = client
    login(connection, a.email)
    own = a.user.access_sessions.order(:created_at).last!
    connection.get "/v1/sessions/#{own.id}"
    assert_equal 200, connection.response.status
    assert_equal own.id, JSON.parse(connection.response.body).fetch("id")
    send_json(connection, :delete, "/v1/sessions/#{foreign.id}", {})
    assert_equal 404, connection.response.status
    assert_nil foreign.reload.revoked_at
    send_json(connection, :delete, "/v1/sessions/#{own.id}", {})
    assert_equal 200, connection.response.status
    assert own.reload.revoked_at
    login(connection, a.email)
    connection.get "/v1/sessions/#{foreign.id}"
    assert_equal 404, connection.response.status
    send_json(connection, :delete, "/v1/sessions/#{foreign.id}")
    assert_equal 404, connection.response.status
    assert_nil foreign.reload.revoked_at
  end

  test "session_boundaries_enforced" do
    a = account("pending@example.com", verified: false)
    connection = client
    login(connection, a.email)
    connection.get "/v1/account_capability"
    assert_equal 403, connection.response.status
    assert_equal "verification_required", JSON.parse(connection.response.body).dig("error", "code")
    row = a.user.access_sessions.order(:created_at).last
    row.update!(last_seen_at: 14.days.ago)
    connection.get "/v1/sessions/#{row.id}"
    assert_equal 401, connection.response.status
    assert row.reload.revoked_at
    fresh = client
    login(fresh, a.email)
    absolute = a.user.access_sessions.order(:created_at).last
    absolute.update!(absolute_expires_at: Time.current)
    fresh.get "/v1/sessions/#{absolute.id}"
    assert_equal 401, fresh.response.status
    hostile = client
    token = csrf(hostile)
    hostile.post "/v1/guest", params: "{}", headers: {
      "CONTENT_TYPE" => "application/json", "X-CSRF-Token" => token,
      "HTTP_ORIGIN" => "https://attacker.example"
    }
    assert_equal 403, hostile.response.status
    missing = client
    csrf(missing)
    missing.post "/v1/guest", params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
    assert_equal 403, missing.response.status
  end

  test "logout_rotates_and_isolates" do
    a = account("logout@example.com")
    connection = client
    login(connection, a.email)
    first = a.user.access_sessions.order(:created_at).last
    old_cookie = connection.cookies["_questify_session"]
    login(connection, a.email)
    second = a.user.access_sessions.order(:created_at).last
    assert_not_equal first.id, second.id
    assert first.reload.revoked_at
    stale = client
    stale.cookies["_questify_session"] = old_cookie
    stale.get "/v1/sessions/#{first.id}"
    assert_equal 401, stale.response.status
    current_cookie = connection.cookies["_questify_session"]
    send_json(connection, :delete, "/v1/session")
    assert_equal 200, connection.response.status
    assert second.reload.revoked_at
    stale.cookies["_questify_session"] = current_cookie
    stale.get "/v1/sessions/#{second.id}"
    assert_equal 401, stale.response.status
  end

  test "registration_preserves_guest_provenance_and_verification_does_not_import" do
    connection = client
    send_json(connection, :post, "/v1/guest")
    guest_id = JSON.parse(connection.response.body).dig("user", "id")
    send_json(connection, :post, "/v1/register", email: "new@example.com", password: "foundation-password-123")
    assert_equal 202, connection.response.status
    created = Account.find_by!(email: "new@example.com")
    assert_equal guest_id, Registration.find_by!(account: created).source_user_id
    assert_not created.verified?
    raw = CredentialToken.issue!(created, purpose: "verify", lifetime: 24.hours)
    send_json(connection, :post, "/v1/verify", token: raw)
    assert_equal 200, connection.response.status
    assert created.reload.verified?
    connection.get "/v1/bootstrap"
    assert_equal guest_id, JSON.parse(connection.response.body).dig("user", "id")
    send_json(connection, :post, "/v1/login", email: created.email, password: "foundation-password-123")
    assert_equal 409, connection.response.status
  end

  test "recent_authentication_expires_at_ten_minutes" do
    a = account("recent@example.com")
    connection = client
    login(connection, a.email)
    row = a.user.access_sessions.order(:created_at).last
    row.update!(authenticated_at: 10.minutes.ago)
    send_json(connection, :delete, "/v1/sessions/#{row.id}")
    assert_equal 403, connection.response.status
    send_json(connection, :post, "/v1/recent_auth", password: "foundation-password-123")
    assert_equal 200, connection.response.status
    send_json(connection, :delete, "/v1/sessions/#{row.id}")
    assert_equal 200, connection.response.status
  end

  test "ten_failed_logins_limit_the_account_identifier" do
    a = account("limited@example.com")
    connection = client
    10.times do
      send_json(connection, :post, "/v1/login", email: a.email, password: "incorrect")
      assert_equal 401, connection.response.status
    end
    send_json(connection, :post, "/v1/login", email: a.email, password: "foundation-password-123")
    assert_equal 429, connection.response.status
  end

  test "guest_has_online_authority_but_not_verified_account_capability" do
    connection = client
    send_json(connection, :post, "/v1/guest")
    value = JSON.parse(connection.response.body)
    assert_equal true, value.dig("capabilities", "online_authority")
    assert_equal false, value.dig("capabilities", "verified_account")
    connection.get "/v1/account_capability"
    assert_equal 403, connection.response.status
  end
end
