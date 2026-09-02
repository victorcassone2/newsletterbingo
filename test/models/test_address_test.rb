require "test_helper"

class TestAddressTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "an address is normalized the way a participant's is" do
    address = @publication.test_addresses.create!(email: "  Seed+QA@Example.COM ")
    assert_equal "seed+qa@example.com", address.email
  end

  test "the same address can't be listed twice" do
    @publication.test_addresses.create!(email: "dupe@example.com")
    assert_no_difference "TestAddress.count" do
      assert_not @publication.test_addresses.create(email: "DUPE@example.com").persisted?
    end
  end

  test "two publications keep their own lists" do
    @publication.test_addresses.create!(email: "shared@example.com")
    assert publications(:lincoln).test_addresses.create(email: "shared@example.com").persisted?
  end

  test "the list stops at the limit" do
    @publication.test_addresses.destroy_all
    TestAddress::LIMIT_PER_PUBLICATION.times { |i| @publication.test_addresses.create!(email: "seed#{i}@example.com") }
    over = @publication.test_addresses.create(email: "one-too-many@example.com")
    assert_not over.persisted?
    assert_match(/up to #{TestAddress::LIMIT_PER_PUBLICATION}/, over.errors.full_messages.to_sentence)
  end
end
