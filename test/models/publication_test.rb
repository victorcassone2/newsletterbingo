require "test_helper"

class PublicationTest < ActiveSupport::TestCase
  test "generates a secure public code on create" do
    publication = accounts(:publisher).publications.create!(name: "New Pub", slug: "new-pub")
    assert_match(/\Apub_[1-9A-HJ-NP-Za-km-z]{20}\z/, publication.public_code)
  end

  test "public codes are unique" do
    publication = accounts(:publisher).publications.new(name: "Dup", slug: "dup",
      public_code: publications(:omaha).public_code)
    assert_not publication.valid?
    assert publication.errors[:public_code].any?
  end

  test "slug is unique per account but reusable across accounts" do
    duplicate = accounts(:publisher).publications.new(name: "Dup", slug: "omaha-daily")
    assert_not duplicate.valid?

    other_account = accounts(:rival).publications.new(name: "Other", slug: "omaha-daily")
    assert other_account.valid?
  end

  test "slug is normalized" do
    publication = accounts(:publisher).publications.create!(name: "X", slug: "  My Cool Pub!  ")
    assert_equal "my-cool-pub", publication.slug
  end

  test "colors must be hex" do
    publication = publications(:omaha)
    publication.primary_color = "red"
    assert_not publication.valid?
    publication.primary_color = "#AB12CD"
    assert publication.valid?
  end

  test "timezone must be recognized" do
    publication = publications(:omaha)
    publication.timezone = "Mars/Olympus"
    assert_not publication.valid?
    publication.timezone = "America/Denver"
    assert publication.valid?
  end

  test "email merge tag has a sensible default and is required" do
    publication = accounts(:publisher).publications.create!(name: "Y", slug: "y-pub")
    assert_equal "{{email}}", publication.email_merge_tag

    publication.email_merge_tag = ""
    assert_not publication.valid?
  end

  test "local_date follows the publication timezone, not the server" do
    publication = publications(:omaha) # America/Chicago
    travel_to Time.utc(2026, 8, 16, 3, 0) do # 10 PM Aug 15 in Chicago
      assert_equal Date.new(2026, 8, 15), publication.local_date
    end
    travel_to Time.utc(2026, 8, 16, 6, 0) do # 1 AM Aug 16 in Chicago
      assert_equal Date.new(2026, 8, 16), publication.local_date
    end
  end

  test "eligible words include system words and own custom words only" do
    eligible = publications(:omaha).eligible_words
    assert_includes eligible, words(:custom_omaha)
    assert_includes eligible, words(:system_0)
    assert_not_includes eligible, words(:custom_rival)
  end
end
