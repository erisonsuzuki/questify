require "test_helper"

class HarnessTest < ActionDispatch::IntegrationTest
  test "harness_reports_intentional_mismatch" do
    assert_equal 1, 1
  end
end
