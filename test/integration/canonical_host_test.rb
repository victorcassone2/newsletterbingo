require "test_helper"

class CanonicalHostTest < ActionDispatch::IntegrationTest
  # The canonical host comes from APP_HOST at request time, so the redirect can
  # be exercised without the suite's default www.example.com matching it.
  setup { ENV["APP_HOST"] = "newsletterbingo.com" }
  teardown { ENV.delete("APP_HOST") }

  test "www redirects to the apex host" do
    get "https://www.newsletterbingo.com/"
    assert_redirected_to "https://newsletterbingo.com/"
  end

  test "a www redirect keeps the path and the query string" do
    get "https://www.newsletterbingo.com/up?utm_source=email"
    assert_redirected_to "https://newsletterbingo.com/up?utm_source=email"
  end

  test "the apex host is served rather than redirected" do
    get "https://newsletterbingo.com/"
    assert_response :success
  end

  test "an unrelated www host is left alone" do
    get "https://www.example.com/"
    assert_response :success
  end
end
