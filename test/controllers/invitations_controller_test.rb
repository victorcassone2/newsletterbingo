require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:publisher)
    sign_in_as users(:one)
  end

  test "create sends an invitation" do
    assert_difference "@account.invitations.count", 1 do
      assert_enqueued_emails 1 do
        post account_invitations_path(account_id: @account.id),
          params: { invitation: { email_address: "teammate@example.com" } }
      end
    end

    assert_redirected_to account_account_profile_path(account_id: @account.id)
  end

  test "create with an invalid email re-surfaces the error" do
    assert_no_difference "Invitation.count" do
      post account_invitations_path(account_id: @account.id),
        params: { invitation: { email_address: "not-an-email" } }
    end

    assert_redirected_to account_account_profile_path(account_id: @account.id)
    assert flash[:alert].present?
  end

  test "create is scoped to accounts the user belongs to" do
    assert_no_difference "Invitation.count" do
      post account_invitations_path(account_id: accounts(:rival).id),
        params: { invitation: { email_address: "teammate@example.com" } }
    end

    assert_redirected_to root_path
  end

  test "destroy cancels a pending invitation" do
    assert_difference "Invitation.count", -1 do
      delete account_invitation_path(account_id: @account.id, id: invitations(:pending).id)
    end

    assert_redirected_to account_account_profile_path(account_id: @account.id)
  end

  test "destroy cannot reach another account's invitation" do
    assert_no_difference "Invitation.count" do
      delete account_invitation_path(account_id: @account.id, id: invitations(:for_existing_user).id)
    end

    assert_response :not_found
  end
end
