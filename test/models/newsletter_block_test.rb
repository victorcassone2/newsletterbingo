require "test_helper"

class NewsletterBlockTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
    @call = @game.call_for(@publication.local_date)
    @call.update!(description: "Secret detail for after the click.",
      link_url: "https://example.com/detail", link_text: "See details")
  end

  test "claim URL contains the public code and the configured merge tag, unencoded" do
    html = NewsletterBlock.new(@publication).to_html
    assert_includes html, @publication.public_code
    assert_includes html, "email={{email}}"
  end

  test "a custom merge tag is inserted verbatim" do
    @publication.update!(email_merge_tag: "|EMAIL|")
    html = NewsletterBlock.new(@publication).to_html
    assert_includes html, "email=|EMAIL|"
  end

  test "today's word is present" do
    assert_includes NewsletterBlock.new(@publication).to_html, @call.label
  end

  test "gift icon appears only on prize calls" do
    assert_not_includes NewsletterBlock.new(@publication).to_html, "&#127873;"
    @call.update!(prize_call: true)
    assert_includes NewsletterBlock.new(@publication).to_html, "&#127873;"
  end

  test "sponsor line appears only when a sponsor is set" do
    assert_not_includes NewsletterBlock.new(@publication).to_html, "Sponsored by"
    @call.update!(sponsor: sponsors(:car_wash))
    assert_includes NewsletterBlock.new(@publication).to_html, "Sponsored by Omaha Car Wash"
  end

  test "brought to you by line appears only when the game has a sponsor name" do
    assert_not_includes NewsletterBlock.new(@publication).to_html, "Brought to you by"
    @game.update!(sponsor_name: "Midtown Market")
    assert_includes NewsletterBlock.new(@publication).to_html, "Brought to you by Midtown Market"
  end

  test "the evergreen block carries the game sponsor line" do
    @publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")
    @game.update!(sponsor_name: "Midtown Market")
    assert_includes NewsletterBlock.new(@publication).to_html, "Brought to you by Midtown Market"
  end

  test "description and destination link stay out of the email" do
    html = NewsletterBlock.new(@publication).to_html
    assert_not_includes html, "Secret detail"
    assert_not_includes html, "example.com/detail"
  end

  test "the block is email-safe: no script, iframe, or external CSS" do
    html = NewsletterBlock.new(@publication).to_html
    assert_not_includes html, "<script"
    assert_not_includes html, "<iframe"
    assert_not_includes html, "<link"
    assert_includes html, "<table"
  end

  test "publication branding colors are applied" do
    @publication.update!(accent_color: "#AB12CD")
    assert_includes NewsletterBlock.new(@publication).to_html, "#AB12CD"
  end

  test "sponsor names are HTML-escaped" do
    @call.update!(sponsor: @publication.sponsors.create!(name: "<b>Sneaky</b>"))
    html = NewsletterBlock.new(@publication).to_html
    assert_not_includes html, "<b>Sneaky</b>"
    assert_includes html, "&lt;b&gt;Sneaky&lt;/b&gt;"
  end
end
