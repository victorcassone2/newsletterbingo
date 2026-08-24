require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "a member can be promoted to owner" do
    membership = memberships(:publisher_member)

    assert membership.update(role: "owner")
    assert users(:three).owner_of?(accounts(:publisher))
  end

  test "an owner can be demoted when another owner remains" do
    memberships(:publisher_member).update!(role: "owner")

    assert memberships(:publisher_owner).update(role: "member")
  end

  test "the last owner cannot be demoted" do
    membership = memberships(:publisher_owner)

    assert_not membership.update(role: "member")
    assert_includes membership.errors[:base], "The account needs at least one owner"
  end

  test "the last owner cannot be removed" do
    membership = memberships(:publisher_owner)

    assert_not membership.destroy
    assert Membership.exists?(membership.id)
  end

  test "a member can be removed" do
    assert memberships(:publisher_member).destroy
  end

  test "last_owner? is true only for a sole owner" do
    assert memberships(:publisher_owner).last_owner?
    assert_not memberships(:publisher_member).last_owner?

    memberships(:publisher_member).update!(role: "owner")

    assert_not memberships(:publisher_owner).last_owner?
  end
end
