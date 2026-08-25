require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors see the marketing landing page" do
    get root_path

    assert_response :success
    assert_select "h1", /one square at a time/
    assert_select "a[href=?]", new_registration_path, minimum: 1
  end

  test "signed-in users see the marketing page with a dashboard link" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "h1", /one square at a time/
    assert_select "a[href=?]", dashboard_path, text: "Go to dashboard"
  end
end
