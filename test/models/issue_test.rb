require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "plausible tokens are replaced values, not merge-tag leftovers" do
    assert Issue.plausible_token?("abc123")
    assert Issue.plausible_token?("f47ac10b-58cc-4372-a567-0e02b2c3d479")
    assert Issue.plausible_token?("2026-09-02")

    assert_not Issue.plausible_token?("")
    assert_not Issue.plausible_token?(nil)
    assert_not Issue.plausible_token?("{{current_date_ymd}}")
    assert_not Issue.plausible_token?("*|CAMPAIGN_UID|*")
    assert_not Issue.plausible_token?("%recipient.id%")
    assert_not Issue.plausible_token?("two words")
    assert_not Issue.plausible_token?("x" * 121)
  end
end
