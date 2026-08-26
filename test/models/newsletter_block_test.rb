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

  test "both cadences carry the campaign token that proves a click is from the current send" do
    assert_includes NewsletterBlock.new(@publication).to_html, "issue={{campaign_id}}"

    @publication.update!(cadence: "issues", campaign_merge_tag: "*|CAMPAIGN_UID|*")
    assert_includes NewsletterBlock.new(@publication).to_html, "issue=*|CAMPAIGN_UID|*"
  end

  test "a custom merge tag is inserted verbatim" do
    @publication.update!(email_merge_tag: "|EMAIL|")
    html = NewsletterBlock.new(@publication).to_html
    assert_includes html, "email=|EMAIL|"
  end

  test "the word arrives as a dynamic inline image, never baked into the HTML" do
    html = NewsletterBlock.new(@publication).to_html
    assert_includes html, "/c/#{@publication.public_code}/word.png?variant=inline"
    assert_not_includes html, @call.label
  end

  test "the section header carries the Newsletter Bingo mark, not an emoji" do
    html = NewsletterBlock.new(@publication).to_html
    assert_includes html, "/icon-192x192.png"
  end

  test "the issue-cadence block carries no word image" do
    @publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")
    html = NewsletterBlock.new(@publication).to_html
    assert_not_includes html, "word.png"
    assert_includes html, "A new word drops with this issue"
  end

  test "the block is identical from day to day: no per-call state leaks in" do
    html = NewsletterBlock.new(@publication).to_html
    @call.update!(prize_call: true, prize_description: "Free coffee")
    assert_equal html, NewsletterBlock.new(@publication).to_html
  end

  test "sponsored by line appears only when the publication has a sponsor name" do
    assert_not_includes NewsletterBlock.new(@publication).to_html, "Sponsored by"
    @publication.update!(sponsor_name: "Midtown Market")
    assert_includes NewsletterBlock.new(@publication).to_html, "Sponsored by Midtown Market"
  end

  test "the evergreen block carries the sponsor line" do
    @publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")
    @publication.update!(sponsor_name: "Midtown Market")
    assert_includes NewsletterBlock.new(@publication).to_html, "Sponsored by Midtown Market"
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
    assert_includes NewsletterBlock.new(@publication).to_html, "#ab12cd"
  end

  test "sponsor names are HTML-escaped" do
    @publication.update!(sponsor_name: "<b>Sneaky</b>")
    html = NewsletterBlock.new(@publication).to_html
    assert_not_includes html, "<b>Sneaky</b>"
    assert_includes html, "&lt;b&gt;Sneaky&lt;/b&gt;"
  end
end
