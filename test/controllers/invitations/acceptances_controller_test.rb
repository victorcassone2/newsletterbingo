require "test_helper"

class Invitations::AcceptancesControllerTest < ActionDispatch::IntegrationTest
  test "show renders a signup form for a brand-new person" do
    get invitation_acceptance_path(invitations(:pending).token)

    assert_response :success
    assert_select "form"
  end

  test "show with an unknown token redirects home" do
    get invitation_acceptance_path("bogus")

    assert_redirected_to root_path
  end

  test "create signs up a new user and joins the team" do
    invitation = invitations(:pending)

    assert_difference [ "User.count", "Membership.count" ], 1 do
      post invitation_acceptance_path(invitation.token),
        params: { user: { password: "secret123", password_confirmation: "secret123" } }
    end

    assert_redirected_to account_path(account_id: accounts(:publisher).id)
    assert_not Invitation.exists?(invitation.id)
    assert User.find_by(email_address: "invited@example.com").member_of?(accounts(:publisher))
    assert cookies[:session_id]
  end

  test "create with mismatched passwords re-renders the form" do
    assert_no_difference [ "User.count", "Membership.count" ] do
      post invitation_acceptance_path(invitations(:pending).token),
        params: { user: { password: "secret123", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end

  test "create while signed in joins immediately" do
    sign_in_as users(:one)
    invitation = invitations(:for_existing_user)

    assert_difference "Membership.count", 1 do
      post invitation_acceptance_path(invitation.token)
    end

    assert_redirected_to account_path(account_id: accounts(:rival).id)
    assert users(:one).member_of?(accounts(:rival))
    assert_not Invitation.exists?(invitation.id)
  end

  test "create for an existing user who is signed out sends them to sign in" do
    invitation = invitations(:for_existing_user)

    assert_no_difference "Membership.count" do
      post invitation_acceptance_path(invitation.token)
    end

    assert_redirected_to new_session_path
    assert Invitation.exists?(invitation.id)
  end

  test "signing in after following an invitation link returns to the acceptance page" do
    invitation = invitations(:for_existing_user)

    get invitation_acceptance_path(invitation.token)
    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to invitation_acceptance_url(invitation.token)
  end
end
