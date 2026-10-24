require "test_helper"
require "timeout"

class LoginResetConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @user = User.create!(kind: "account", last_online_at: Time.current)
    @account = Account.create!(user: @user, email: "#{SecureRandom.uuid}@example.com",
                               password: "foundation-password-123", verified_at: Time.current)
    @token = CredentialToken.issue!(@account, purpose: "reset", lifetime: 30.minutes)
    @login = open_session
    @reset = open_session
    @login_csrf = csrf(@login)
    @reset_csrf = csrf(@reset)
    @ip = "192.0.2.230"
    @bucket_keys = [LoginBucket.bucket_key("login_account", @account.email),
                    LoginBucket.bucket_key("login_ip", @ip)]
  end

  teardown do
    CredentialToken.where(account_id: @account.id).delete_all
    AccessSession.where(user_id: @user.id).delete_all
    Account.where(id: @account.id).delete_all
    User.where(id: @user.id).delete_all
    LoginBucket.where(key: @bucket_keys).delete_all
  end

  def csrf(connection)
    connection.get "/v1/bootstrap"
    assert_equal 200, connection.response.status
    JSON.parse(connection.response.body).fetch("csrf_token")
  end

  def post_json(connection, path, token, body)
    connection.post path, params: body.to_json, headers: {
      "CONTENT_TYPE" => "application/json", "X-CSRF-Token" => token, "REMOTE_ADDR" => @ip
    }
  end

  def login_thread(&hook)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        Thread.current[:login_race_hook] = hook
        post_json(@login, "/v1/login", @login_csrf,
                  email: @account.email, password: "foundation-password-123")
        @login.response.status
      ensure
        Thread.current[:login_race_hook] = nil
      end
    end
  end

  def reset_password
    post_json(@reset, "/v1/password_reset/consume", @reset_csrf,
              token: @token, password: "replacement-password-123")
    @reset.response.status
  end

  test "reset_revokes_login_that_already_compared_the_old_password" do
    compared = Queue.new
    release = Queue.new
    reset_pid = Queue.new
    completed = Queue.new
    original = Account.instance_method(:authenticate)
    Account.define_method(:authenticate) do |password|
      result = original.bind_call(self, password)
      Thread.current[:login_race_hook]&.call
      result
    end
    login = nil
    reset = nil
    begin
      login = login_thread do
        compared << ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()").to_i
        release.pop
      end
      login_pid = Timeout.timeout(10) { compared.pop }
      reset = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          reset_pid << connection.select_value("SELECT pg_backend_pid()").to_i
          status = reset_password
          completed << true
          status
        end
      end
      pid = Timeout.timeout(10) { reset_pid.pop }
      # Release login only after reset has either committed or reached its row lock.
      Timeout.timeout(10) do
        loop do
          blockers = ActiveRecord::Base.connection.select_value(
            "SELECT #{login_pid} = ANY(pg_blocking_pids(#{pid}))"
          )
          break if blockers || !completed.empty?
          Thread.pass
        end
      end
      release << true
      assert_equal 200, Timeout.timeout(10) { login.value }
      assert_equal 200, Timeout.timeout(10) { reset.value }
      sessions = AccessSession.where(user_id: @user.id)
      assert_equal 1, sessions.count
      assert sessions.first.revoked_at, "login validated before reset must not escape reset revocation"
      assert @account.reload.authenticate("replacement-password-123")
    ensure
      release << true
      Timeout.timeout(10) { login&.join; reset&.join }
      Account.define_method(:authenticate, original)
    end
  end

  test "login_reloads_credentials_when_reset_commits_after_account_lookup" do
    loaded = Queue.new
    release = Queue.new
    original = Account.method(:find_by)
    Account.define_singleton_method(:find_by) do |*args, **kwargs|
      result = original.call(*args, **kwargs)
      Thread.current[:login_race_hook]&.call
      result
    end
    login = nil
    begin
      login = login_thread { loaded << true; release.pop }
      Timeout.timeout(10) { loaded.pop }
      assert_equal 200, reset_password
      release << true
      assert_equal 401, Timeout.timeout(10) { login.value }
      assert_equal 0, AccessSession.where(user_id: @user.id, revoked_at: nil).count
      bucket = LoginBucket.find_by!(key: LoginBucket.bucket_key("login_account", @account.email))
      assert_equal 1, bucket.failures.length
    ensure
      release << true
      Timeout.timeout(10) { login&.join }
      Account.define_singleton_method(:find_by, original)
    end
  end
end
