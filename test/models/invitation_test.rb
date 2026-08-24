require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "normalizes email address" do
    invitation = accounts(:publisher).invitations.create!(email_address: "  New.Person@Example.COM ")

    assert_equal "new.person@example.com", invitation.email_address
  end

  test "generates a token" do
    invitation = accounts(:publisher).invitations.create!(email_address: "someone@example.com")

    assert invitation.token.present?
  end

  test "rejects duplicate invitations within an account" do
    invitation = accounts(:publisher).invitations.new(email_address: "invited@example.com")

    assert_not invitation.valid?
  end

  test "allows the same email to be invited to a different account" do
    invitation = accounts(:rival).invitations.new(email_address: "invited@example.com")

    assert invitation.valid?
  end

  test "rejects inviting an existing member" do
    invitation = accounts(:publisher).invitations.new(email_address: users(:one).email_address)

    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "already belongs to this team"
  end

  test "accept_for creates a membership and destroys the invitation" do
    invitation = invitations(:for_existing_user)
    user = users(:one)

    invitation.accept_for(user)

    assert user.member_of?(accounts(:rival))
    assert_not Invitation.exists?(invitation.id)
  end

  test "accept_for is a no-op for someone already on the team" do
    invitation = invitations(:pending)

    assert_no_difference "Membership.count" do
      invitation.accept_for(users(:one))
    end
    assert_not Invitation.exists?(invitation.id)
  end
end
