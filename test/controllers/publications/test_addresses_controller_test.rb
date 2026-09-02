require "test_helper"

class Publications::TestAddressesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)
  end

  test "listing an address" do
    assert_difference "@publication.test_addresses.count", 1 do
      post account_publication_test_addresses_path(account_id: @account_id, publication_id: @publication.id),
        params: { test_address: { email: "designer@studio.test" } }
    end
    assert_redirected_to edit_account_publication_path(account_id: @account_id, id: @publication.id, pane: "connect")
  end

  test "unlisting an address lets it claim again" do
    address = @publication.test_addresses.create!(email: "designer@studio.test")

    assert_difference "@publication.test_addresses.count", -1 do
      delete account_publication_test_address_path(account_id: @account_id, publication_id: @publication.id, id: address.id)
    end
    assert_not @publication.tester?("designer@studio.test")
  end

  test "the connect step lists only addresses that were added" do
    @publication.test_addresses.create!(email: "designer@studio.test")

    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_select "[data-pane=connect] .wchip", text: /designer@studio\.test/
    # A teammate who was never added stays off the list, and off the page.
    assert_no_match(/#{Regexp.escape(users(:three).email_address)}/, response.body)
  end

  test "adding over Turbo refreshes the list and the count" do
    @publication.test_addresses.destroy_all

    post account_publication_test_addresses_path(account_id: @account_id, publication_id: @publication.id),
      params: { test_address: { email: "designer@studio.test" } }, as: :turbo_stream

    assert_response :success
    assert_match "designer@studio.test", response.body
    assert_match "1 of #{TestAddress::LIMIT_PER_PUBLICATION} added", response.body
    assert_no_match(/No addresses listed yet/, response.body)
  end

  test "removing the last address brings the empty state back" do
    @publication.test_addresses.destroy_all
    address = @publication.test_addresses.create!(email: "designer@studio.test")

    delete account_publication_test_address_path(account_id: @account_id, publication_id: @publication.id, id: address.id),
      as: :turbo_stream

    assert_response :success
    assert_match "No addresses listed yet", response.body
    assert_match "0 of #{TestAddress::LIMIT_PER_PUBLICATION} added", response.body
  end

  test "adding sends back an empty form, so the field clears without any JavaScript" do
    post account_publication_test_addresses_path(account_id: @account_id, publication_id: @publication.id),
      params: { test_address: { email: "designer@studio.test" } }, as: :turbo_stream

    assert_match 'target="test-address-form"', response.body
    assert_no_match(/value="designer@studio\.test"/, response.body)
  end

  test "a refused address keeps what was typed so it can be corrected" do
    post account_publication_test_addresses_path(account_id: @account_id, publication_id: @publication.id),
      params: { test_address: { email: "not an address" } }, as: :turbo_stream

    assert_no_match(/target="test-address-form"/, response.body)
    assert_match "is invalid", response.body
  end

  test "a bad address is refused" do
    assert_no_difference "TestAddress.count" do
      post account_publication_test_addresses_path(account_id: @account_id, publication_id: @publication.id),
        params: { test_address: { email: "not an address" } }
    end
  end

  test "another account's publication is out of reach" do
    rival = publications(:rival)
    assert_no_difference "TestAddress.count" do
      post account_publication_test_addresses_path(account_id: @account_id, publication_id: rival.id),
        params: { test_address: { email: "designer@studio.test" } }
    end
    assert_response :not_found
  end
end
