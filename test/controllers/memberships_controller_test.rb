require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:publisher)
    @people_path = account_account_profile_path(account_id: @account.id)
  end

  test "an owner can promote a member to owner" do
    sign_in_as users(:one)

    patch account_membership_path(account_id: @account.id, id: memberships(:publisher_member).id),
      params: { membership: { role: "owner" } }

    assert_redirected_to @people_path
    assert memberships(:publisher_member).reload.owner?
  end

  test "an owner can demote a co-owner" do
    memberships(:publisher_member).update!(role: "owner")
    sign_in_as users(:one)

    patch account_membership_path(account_id: @account.id, id: memberships(:publisher_owner).id),
      params: { membership: { role: "member" } }

    assert_not memberships(:publisher_owner).reload.owner?
  end

  test "demoting the last owner is refused" do
    sign_in_as users(:one)

    patch account_membership_path(account_id: @account.id, id: memberships(:publisher_owner).id),
      params: { membership: { role: "member" } }

    assert_redirected_to @people_path
    assert flash[:alert].present?
    assert memberships(:publisher_owner).reload.owner?
  end

  test "a member cannot change roles" do
    sign_in_as users(:three)

    patch account_membership_path(account_id: @account.id, id: memberships(:publisher_member).id),
      params: { membership: { role: "owner" } }

    assert_redirected_to @people_path
    assert_not memberships(:publisher_member).reload.owner?
  end

  test "an owner can remove a member" do
    sign_in_as users(:one)

    assert_difference "Membership.count", -1 do
      delete account_membership_path(account_id: @account.id, id: memberships(:publisher_member).id)
    end

    assert_redirected_to @people_path
    assert_not users(:three).member_of?(@account)
  end

  test "a member cannot remove anyone" do
    sign_in_as users(:three)

    assert_no_difference "Membership.count" do
      delete account_membership_path(account_id: @account.id, id: memberships(:publisher_owner).id)
    end

    assert_redirected_to @people_path
  end

  test "removing the last owner is refused" do
    sign_in_as users(:one)

    assert_no_difference "Membership.count" do
      delete account_membership_path(account_id: @account.id, id: memberships(:publisher_owner).id)
    end

    assert flash[:alert].present?
  end

  test "an owner removing themselves lands on the dashboard" do
    memberships(:publisher_member).update!(role: "owner")
    sign_in_as users(:one)

    delete account_membership_path(account_id: @account.id, id: memberships(:publisher_owner).id)

    assert_redirected_to dashboard_path
    assert_not users(:one).member_of?(@account)
  end

  test "roles cannot be changed across accounts" do
    sign_in_as users(:two)

    patch account_membership_path(account_id: accounts(:rival).id, id: memberships(:publisher_member).id),
      params: { membership: { role: "owner" } }

    assert_response :not_found
    assert_not memberships(:publisher_member).reload.owner?
  end
end
