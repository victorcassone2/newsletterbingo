require "test_helper"

# Setup ends by telling the publisher what their test link actually
# carried, so a merge tag that was never replaced is visible in seconds
# instead of silently costing every claim.
class SetupFlowTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @account_id = accounts(:publisher).id
    @tester = test_addresses(:omaha_seed).email
    create_running_game(@publication)
  end

  test "setup waits for a test click before it claims anything works" do
    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_response :success
    assert_match "Watching for your test click", response.body
    assert_no_match(/Connected\./, response.body)
  end

  test "a tester's click is reported back on the setup page" do
    get claim_path(@publication.public_code, email: @tester, issue: "2026-09-02")
    assert_redirected_to rehearsal_path(@publication.public_code)

    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_match "Connected.", response.body
    assert_match "2026-09-02", response.body
    assert_match @tester, response.body
  end

  test "a tag that came through as written is named on the setup page" do
    get claim_path(@publication.public_code, email: "{{email}}", issue: "{{campaign_id}}")
    assert_redirected_to board_path(@publication.public_code)

    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_match "came through as written", response.body
    assert_match "{{campaign_id}}", response.body
    assert_no_match(/Connected\./, response.body)
  end

  test "an unreplaced per-send tag is caught even when the address survived" do
    get claim_path(@publication.public_code, email: @tester, issue: "{{campaign_id}}")

    check = @publication.latest_link_check
    assert check.email_replaced?
    assert_not check.token_replaced?
    assert_not check.complete?
  end

  test "the block step says where this platform's block goes" do
    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_select ".paste-steps li", 3
    assert_match "HTML Snippet", response.body, "beehiiv's own words for the block that takes it"
    assert_match "post template, not a single post", response.body
  end

  test "a plain link is offered where there is nowhere to paste HTML" do
    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_select "details.link-fallback input[readonly]" do |fields|
      assert_equal NewsletterBlock.new(@publication).claim_url, fields.first["value"]
    end
  end

  test "Ghost is pointed at the footer, with the link opened for it" do
    sign_in_as users(:one)
    patch account_publication_path(account_id: @account_id, id: @publication.id),
      params: { pane: "connect", quiet: "1", publication: {
        email_merge_tag: "%%{email}%%", campaign_merge_tag: "" } }
    follow_redirect!

    assert_match "edit the footer content", response.body
    assert_select "details.link-fallback[open]", 1, "the link is the route for Ghost, not the consolation"
  end

  test "Kit is pointed at its HTML template, where nothing is per issue" do
    sign_in_as users(:one)
    patch account_publication_path(account_id: @account_id, id: @publication.id),
      params: { pane: "connect", quiet: "1", publication: {
        email_merge_tag: "{{subscriber.email_address|url_encode}}", campaign_merge_tag: "" } }
    follow_redirect!

    assert_match "Open Email Templates", response.body
    assert_match "nothing to do per issue", response.body
    assert_select "details.link-fallback[open]", 0
  end

  test "an unlisted platform still gets told to use a template" do
    @publication.update!(email_merge_tag: "[[email]]", campaign_merge_tag: "[[send]]")
    sign_in_as users(:one)
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)

    assert_nil @publication.platform
    assert_match "Paste it into your email template rather than a single issue", response.body
  end

  test "switching platforms saves without a banner, since the step shows the change itself" do
    sign_in_as users(:one)
    patch account_publication_path(account_id: @account_id, id: @publication.id),
      params: { pane: "connect", quiet: "1", publication: {
        email_merge_tag: "%%{email}%%", campaign_merge_tag: "" } }

    assert_nil flash[:notice]
    follow_redirect!
    assert_match "Sending from Ghost", response.body
  end

  test "a save the publisher pressed still says so" do
    sign_in_as users(:one)
    patch account_publication_path(account_id: @account_id, id: @publication.id),
      params: { pane: "general", publication: { name: "Omaha Daily" } }

    assert_equal "Saved.", flash[:notice]
  end

  test "picking a platform names it on the step and fills its tags" do
    sign_in_as users(:one)
    patch account_publication_path(account_id: @account_id, id: @publication.id),
      params: { pane: "connect", publication: {
        email_merge_tag: "%%{email}%%", campaign_merge_tag: "" } }

    follow_redirect!
    assert_match "Sending from Ghost", response.body
    assert_equal "Ghost", @publication.reload.platform.name
  end
end
