require "test_helper"

class Publications::PreviewLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)
  end

  test "regenerating replaces the token" do
    was = @publication.preview_token

    patch account_publication_preview_link_path(account_id: @account_id, publication_id: @publication.id)

    assert_redirected_to edit_account_publication_path(account_id: @account_id, id: @publication.id, pane: "testing")
    assert_not_equal was, @publication.reload.preview_token
  end

  test "the Testing tab shows the link to copy" do
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_select "[data-pane=testing] input[value=?]",
      "#{NewsletterBingo.public_host}/p/#{@publication.public_code}/preview/#{@publication.preview_token}"
  end

  test "another account's publication is out of reach" do
    was = publications(:rival).preview_token

    patch account_publication_preview_link_path(account_id: @account_id, publication_id: publications(:rival).id)

    assert_response :not_found
    assert_equal was, publications(:rival).reload.preview_token
  end
end
