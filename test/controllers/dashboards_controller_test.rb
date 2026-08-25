require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get dashboard_path

    assert_redirected_to new_session_path
  end

  test "routes a member into their first accessible account" do
    sign_in_as users(:one)

    get dashboard_path

    assert_redirected_to account_publications_path(account_id: users(:one).accounts.order(:created_at).first.id)
  end
end
