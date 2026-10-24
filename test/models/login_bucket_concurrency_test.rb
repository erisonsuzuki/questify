require "test_helper"

class LoginBucketConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "competing_requests_cannot_exceed_shared_postgresql_budget" do
    previous = ENV["REGISTRATION_IP_LIMIT"]
    ENV["REGISTRATION_IP_LIMIT"] = "1"
    nonce = SecureRandom.uuid
    email = "#{nonce}@example.com"
    ip = "test-ip-#{nonce}"
    keys = [LoginBucket.bucket_key("registration_ip", ip),
            LoginBucket.bucket_key("mail_account", email), LoginBucket.bucket_key("mail_ip", ip)]
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    begin
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            begin
              LoginBucket.registration!(email: email, ip: ip)
              outcomes << :accepted
            rescue LoginBucket::Limited
              outcomes << :limited
            end
          end
        end
      end
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:value)
      assert_equal [:accepted, :limited], 2.times.map { outcomes.pop }.sort
    ensure
      LoginBucket.where(key: keys).delete_all
      previous ? ENV["REGISTRATION_IP_LIMIT"] = previous : ENV.delete("REGISTRATION_IP_LIMIT")
    end
  end
end
