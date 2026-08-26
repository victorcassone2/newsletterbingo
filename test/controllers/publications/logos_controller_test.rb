require "test_helper"

class Publications::LogosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:publisher)
    @publication = publications(:omaha)
    @publication.logo.attach(io: StringIO.new("fake png bytes"),
      filename: "logo.png", content_type: "image/png")
  end

  test "removing the logo detaches it and returns to the branding pane" do
    sign_in_as users(:one)

    delete account_publication_logo_path(account_id: @account.id, publication_id: @publication.id)

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, pane: "branding")
    assert_not @publication.reload.logo.attached?
  end

  test "logos cannot be removed across accounts" do
    sign_in_as users(:two)

    delete account_publication_logo_path(account_id: accounts(:rival).id, publication_id: @publication.id)

    assert_response :not_found
    assert @publication.reload.logo.attached?
  end
end
