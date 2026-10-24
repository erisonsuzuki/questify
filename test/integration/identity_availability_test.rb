require "test_helper"

class IdentityAvailabilityTest < ActionDispatch::IntegrationTest
  test "bootstrap_endpoint_available_without_identity_helpers" do
    get "/v1/bootstrap"
    assert_response :ok
    value = JSON.parse(response.body)
    assert_nil value.fetch("user")
    assert value.fetch("csrf_token").present?
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
