require "test_helper"

class LinkCheckTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "a link is complete when every tag its platform owes came back replaced" do
    check = @publication.link_checks.new(email_value: "reader@example.com", token_value: "2026-09-02")

    assert check.email_replaced?
    assert check.token_replaced?
    assert check.complete?
  end

  test "a merge tag that arrived verbatim is not a replaced value" do
    check = @publication.link_checks.new(email_value: "{{email}}", token_value: "{{current_date_ymd}}")

    assert_not check.email_replaced?
    assert_not check.token_replaced?
    assert_not check.complete?
  end

  test "a publication with no per-send tag owes no token" do
    @publication.update!(campaign_merge_tag: nil)
    check = @publication.link_checks.new(email_value: "reader@example.com", token_value: "")

    assert_not check.token_expected?
    assert check.complete?
  end

  test "the newest click is the only one kept, and a repeat writes nothing" do
    first = @publication.record_link_check(email: "reader@example.com", token: "send-1")
    again = @publication.record_link_check(email: "reader@example.com", token: "send-1")
    assert_equal first, again
    assert_equal 1, @publication.link_checks.count

    latest = @publication.record_link_check(email: "reader@example.com", token: "send-2")
    assert_equal 1, @publication.link_checks.count
    assert_equal latest, @publication.latest_link_check
  end
end
