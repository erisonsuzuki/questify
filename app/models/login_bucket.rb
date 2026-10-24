class LoginBucket < ApplicationRecord
  before_create { self.id ||= SecureRandom.uuid }

  class InvalidConfiguration < StandardError; end
  class Limited < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("identity rate limit exceeded")
    end
  end

  Rule = Struct.new(:key, :limit, :window, keyword_init: true)

  def self.bucket_key(scope, subject)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{scope}:#{subject}")
  end

  def self.authenticate(email:, ip:, &block)
    with_limits([
      rule("login_account", email, 10, 15.minutes),
      rule("login_ip", ip, 100, 15.minutes)
    ], failures_only: true, &block)
  end

  def self.confirm(account_id:, &block)
    with_limits([rule("recent_auth_account", account_id, 5, 15.minutes)], failures_only: true, &block)
  end

  def self.registration!(email:, ip:)
    with_limits([
      rule("registration_ip", ip, 5, 1.hour),
      rule("mail_account", email, 3, 1.hour),
      rule("mail_ip", ip, 10, 1.hour)
    ], failures_only: false) { true }
  end

  def self.mail_request!(email:, ip:)
    with_limits([
      rule("mail_account", email, 3, 1.hour),
      rule("mail_ip", ip, 10, 1.hour)
    ], failures_only: false) { true }
  end

  def self.rule(scope, subject, default_limit, window)
    limit = Integer(ENV.fetch("#{scope.upcase}_LIMIT", default_limit.to_s), 10)
    raise InvalidConfiguration unless limit.positive?
    Rule.new(key: bucket_key(scope, subject), limit: limit, window: window.to_f)
  rescue ArgumentError, TypeError
    raise InvalidConfiguration
  end
  private_class_method :rule

  def self.with_limits(rules, failures_only:)
    transaction do
      now = Time.current.to_f
      # All scopes share lock order, including initial bucket creation.
      entries = rules.sort_by(&:key).map do |rule|
        row = create_or_find_by!(key: rule.key)
        row.lock!
        stamps = row.failures.select { |stamp| stamp > now - rule.window }.sort
        [rule, row, stamps]
      end
      waits = entries.filter_map do |rule, _row, stamps|
        next if stamps.length < rule.limit
        (stamps.fetch(stamps.length - rule.limit) + rule.window - now).ceil
      end
      raise Limited.new([waits.max, 1].max) unless waits.empty?

      result = yield
      entries.each do |_rule, row, stamps|
        stamps << now if !failures_only || !result
        row.update!(failures: stamps)
      end
      result
    end
  end
  private_class_method :with_limits
end
