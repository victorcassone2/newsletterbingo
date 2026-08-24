require "test_helper"

class DeactivationsControllerTest < ActionDispatch::IntegrationTest
  setup { @account = accounts(:publisher) }

  test "an owner can deactivate the account" do
    sign_in_as users(:one)

    post account_deactivation_path(account_id: @account.id)

    assert @account.reload.deactivated?
  end

  test "a member cannot deactivate the account" do
    sign_in_as users(:three)

    post account_deactivation_path(account_id: @account.id)

    assert_not @account.reload.deactivated?
    assert flash[:alert].present?
  end

  test "an owner can reactivate the account" do
    @account.create_deactivation!
    sign_in_as users(:one)

    delete account_deactivation_path(account_id: @account.id)

    assert_not @account.reload.deactivated?
  end

  test "members are locked out of a deactivated account" do
    @account.create_deactivation!
    sign_in_as users(:three)

    get account_publications_path(account_id: @account.id)

    assert_redirected_to root_path
    assert flash[:alert].present?
  end

  test "owners keep access to a deactivated account" do
    @account.create_deactivation!
    sign_in_as users(:one)

    get account_publications_path(account_id: @account.id)

    assert_response :success
  end

  test "home shows the deactivated notice when a member has no accessible account" do
    @account.create_deactivation!
    sign_in_as users(:three)

    get root_path

    assert_response :success
    assert_select "h1", "Account deactivated"
  end

  test "home still routes owners into their deactivated account" do
    @account.create_deactivation!
    sign_in_as users(:one)

    get root_path

    assert_redirected_to account_publications_path(account_id: @account.id)
  end
end
