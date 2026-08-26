require "test_helper"

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:publisher)
    @publication = publications(:omaha)
  end

  test "the branding editor pairs every color picker with a hex field" do
    sign_in_as users(:one)

    get edit_account_publication_path(account_id: @account.id, id: @publication.id, pane: "branding")

    assert_response :success
    assert_select ".swatch-pair", 4
    assert_select ".swatch-pair input[type=color][value=?]", @publication.primary_color.downcase
    assert_select ".swatch-pair input.hex-field[value=?]", @publication.primary_color.downcase
  end

  test "colors are stored lowercase however they were typed" do
    sign_in_as users(:one)

    patch account_publication_path(account_id: @account.id, id: @publication.id),
      params: { pane: "branding", publication: { accent_color: "#5CACCF" } }

    assert_equal "#5caccf", @publication.reload.accent_color
  end

  test "branding saves the colors typed into the hex fields" do
    sign_in_as users(:one)

    patch account_publication_path(account_id: @account.id, id: @publication.id),
      params: { pane: "branding", publication: {
        primary_color: "#666baa", accent_color: "#5caccf",
        background_color: "#c7fde5", text_color: "#2a2118" } }

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, pane: "branding")
    @publication.reload
    assert_equal "#666baa", @publication.primary_color
    assert_equal "#c7fde5", @publication.background_color
  end
end
