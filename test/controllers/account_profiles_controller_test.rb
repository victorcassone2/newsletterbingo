require "test_helper"

class AccountProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { @account = accounts(:publisher) }

  test "owners see people controls and the deactivation card" do
    sign_in_as users(:one)

    get account_account_profile_path(account_id: @account.id)

    assert_response :success
    assert_select "button", text: "Make owner"
    assert_select "button", text: "Remove"
    assert_select "h2", "Deactivate account"
  end

  test "members see the list without owner controls" do
    sign_in_as users(:three)

    get account_account_profile_path(account_id: @account.id)

    assert_response :success
    assert_select "button", text: "Make owner", count: 0
    assert_select "h2", text: "Deactivate account", count: 0
  end
end
