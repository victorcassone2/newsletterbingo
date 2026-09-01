require "test_helper"

class BillingsControllerTest < ActionDispatch::IntegrationTest
  setup { @account = accounts(:publisher) }

  test "an owner can see billing" do
    sign_in_as users(:one)

    get account_billing_path(account_id: @account.id)

    assert_response :success
  end

  test "a member cannot see billing" do
    sign_in_as users(:three)

    get account_billing_path(account_id: @account.id)

    assert_redirected_to account_account_profile_path(account_id: @account.id)
    assert flash[:alert].present?
  end

  # Every write path is owner-only too, so a member can't start, cancel, or
  # restart what the account pays for.
  test "a member cannot reach any billing write path" do
    sign_in_as users(:three)

    [
      [ :post, account_billing_subscription_path(account_id: @account.id) ],
      [ :post, account_billing_portal_path(account_id: @account.id) ],
      [ :post, account_billing_subscription_cancellation_path(account_id: @account.id) ],
      [ :delete, account_billing_subscription_cancellation_path(account_id: @account.id) ],
      [ :get, account_billing_subscription_return_path(account_id: @account.id) ]
    ].each do |method, path|
      send method, path

      assert_redirected_to account_account_profile_path(account_id: @account.id),
        "#{method.to_s.upcase} #{path} should be owner-only"
    end
  end

  test "the billing link is hidden from members" do
    sign_in_as users(:three)

    get account_publications_path(account_id: @account.id)

    assert_select "a[href=?]", account_billing_path(account_id: @account.id), count: 0
  end

  test "the billing link is shown to owners" do
    sign_in_as users(:one)

    get account_publications_path(account_id: @account.id)

    assert_select "a[href=?]", account_billing_path(account_id: @account.id)
  end
end
