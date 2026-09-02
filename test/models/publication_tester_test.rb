require "test_helper"

class PublicationTesterTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "nothing is a tester until it is listed" do
    assert_not @publication.tester?("reader@example.com")
  end

  test "being on the account earns no exemption" do
    assert_not @publication.tester?(users(:one).email_address)
    assert_not @publication.tester?(users(:three).email_address)
  end

  test "a listed address previews" do
    @publication.test_addresses.create!(email: "seed@example.com")
    assert @publication.tester?("seed@example.com")
  end

  test "sub-addressing folds away, so a seed of a listed address previews too" do
    @publication.test_addresses.create!(email: "seed@example.com")
    assert @publication.tester?("seed+qa@example.com")
    assert @publication.tester?("SEED+one+two@Example.com")
  end

  test "a listed address keeps previewing even after it has claimed" do
    @publication.test_addresses.create!(email: "seed@example.com")
    Participant.locate_or_register(@publication, "seed@example.com")

    assert @publication.tester?("seed@example.com")
  end

  test "unlisting an address lets it claim again" do
    address = @publication.test_addresses.create!(email: "seed@example.com")
    address.destroy

    assert_not @publication.reload.tester?("seed@example.com")
  end

  test "a list belongs to its own publication" do
    @publication.test_addresses.create!(email: "seed@example.com")
    assert_not publications(:lincoln).tester?("seed@example.com")
  end
end
