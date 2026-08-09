require "test_helper"

class PublicationTest < ActiveSupport::TestCase
  test "generates a secure public code on create" do
    publication = accounts(:publisher).publications.create!(name: "New Pub")
    assert_match(/\Apub_[1-9A-HJ-NP-Za-km-z]{20}\z/, publication.public_code)
  end

  test "public codes are unique" do
    publication = accounts(:publisher).publications.new(name: "Dup",
      public_code: publications(:omaha).public_code)
    assert_not publication.valid?
    assert publication.errors[:public_code].any?
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
    publication = accounts(:publisher).publications.create!(name: "Y")
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
