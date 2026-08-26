require "test_helper"

class IssueCadenceTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @publication.update!(cadence: "issues")
    @game = @publication.games.create!(starts_on: @publication.local_date)
    @game.assign_words(Game.random_word_selection(@publication, count: @game.pool_size))
    @game.launch
  end

  test "launching an issue-cadence game leaves all calls undated" do
    assert_equal @game.pool_size, @game.daily_calls.count
    assert_equal 0, @game.issued_calls.count
    assert_nil @game.current_call
  end

  test "the first click of a new send advances the word and claims it" do
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "camp-001")

    assert_redirected_to board_path(@publication.public_code)
    call = @game.reload.current_call
    assert_equal 1, call.position
    assert_equal @publication.local_date, call.call_on
    assert_equal "camp-001", @game.issues.sole.token
    assert_equal 1, call.daily_claims.count
  end

  test "a repeated token never advances twice" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    get claim_path(@publication.public_code, email: "b@example.com", issue: "camp-001")

    assert_equal 1, @game.issues.count
    assert_equal 2, @game.current_call.daily_claims.count
  end

  test "a new token within the interval floor neither advances nor claims" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    get claim_path(@publication.public_code, email: "b@example.com", issue: "forged-immediately")

    assert_equal 1, @game.issues.count
    assert_equal 1, @game.current_call.daily_claims.count
    assert_equal 0, @publication.participants.find_by(email: "b@example.com").daily_claims.count
  end

  test "a new token after the interval floor advances to the next word" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    travel 13.hours do
      get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-002")
    end

    assert_equal 2, @game.issues.count
    assert_equal 2, @game.reload.current_call.position
  end

  test "an unreplaced merge tag token never advances" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "{{campaign_id}}")
    assert_equal 0, @game.issues.count

    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    travel 13.hours do
      get claim_path(@publication.public_code, email: "b@example.com", issue: "*|CAMPAIGN_UID|*")
    end
    assert_equal 1, @game.issues.count
  end

  test "before the first send, a tokenless click explains the game hasn't started" do
    get claim_path(@publication.public_code, email: "a@example.com")
    assert_redirected_to board_path(@publication.public_code)
    follow_redirect!
    assert_match(/next newsletter/, response.body)
  end

  test "clicking an old issue's email reaches the board but claims nothing" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    travel 13.hours do
      get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-002")

      get claim_path(@publication.public_code, email: "late@example.com", issue: "camp-001")
      assert_redirected_to board_path(@publication.public_code)
    end

    assert_equal 2, @game.issues.count
    late = @publication.participants.find_by(email: "late@example.com")
    assert_equal 0, late.daily_claims.count
  end

  test "an unissued call's edit page frames its timing in sends" do
    sign_in_as users(:one)
    unissued = @game.daily_calls.find_by(call_on: nil)

    get edit_account_publication_game_call_path(account_id: accounts(:publisher).id,
      publication_id: @publication.id, game_id: @game.id, id: unissued.id)

    assert_response :success
    assert_match "Goes out with your next send", response.body
  end

  test "a spurious advance can be rolled back until someone claims" do
    sign_in_as users(:one)
    call = @game.claimable_call_for("test-send-oops")
    issue = @game.issues.sole
    assert issue.rollbackable?

    delete account_publication_game_issue_path(account_id: accounts(:publisher).id,
      publication_id: @publication.id, game_id: @game.id, id: issue.id)

    assert_redirected_to account_publication_today_path(account_id: accounts(:publisher).id,
      publication_id: @publication.id)
    assert_equal 0, @game.issues.count
    assert_nil call.reload.call_on
  end

  test "a claimed advance can't be rolled back" do
    get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-001")
    issue = @game.issues.sole
    assert_not issue.rollbackable?

    sign_in_as users(:one)
    delete account_publication_game_issue_path(account_id: accounts(:publisher).id,
      publication_id: @publication.id, game_id: @game.id, id: issue.id)

    assert_equal 1, @game.issues.count
    assert @game.current_call.issued?
  end

  test "the next send after the last word rolls into a new game and claims its first square" do
    issue_every_word

    travel (@game.pool_size * 13).hours do
      get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-next")
      assert_redirected_to board_path(@publication.public_code)
    end

    assert @game.reload.completed?, "the old game's tail is cut short at rollover"
    successor = @publication.active_game
    assert successor.present?
    assert_not_equal @game.id, successor.id
    assert_equal "camp-next", successor.issues.sole.token
    assert_equal 1, successor.current_call.position
    assert_equal 1, successor.current_call.daily_claims.count
  end

  test "an old game's token after rollover reaches the board but claims nothing" do
    issue_every_word
    travel (@game.pool_size * 13).hours do
      get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-next")

      get claim_path(@publication.public_code, email: "late@example.com", issue: "camp-3")
      assert_redirected_to board_path(@publication.public_code)
    end

    successor = @publication.active_game
    assert_equal 1, successor.issues.count
    late = @publication.participants.find_by(email: "late@example.com")
    assert_equal 0, late.daily_claims.count
  end

  test "the game completes after the last word's grace period and the next send starts fresh" do
    issue_every_word
    assert @game.reload.active?

    last_issued_on = @game.issued_calls.last.call_on
    travel_to @publication.tz.local(last_issued_on.year, last_issued_on.month, last_issued_on.day, 12) + (Game::LAST_ISSUE_OPEN_FOR + 1).days do
      get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-final")
      assert_redirected_to board_path(@publication.public_code)
    end

    assert @game.reload.completed?
    successor = @publication.active_game
    assert_equal "camp-final", successor.issues.sole.token
    assert_equal 1, successor.current_call.position
  end

  private
    def issue_every_word
      @game.pool_size.times do |index|
        travel((index * 13).hours) do
          get claim_path(@publication.public_code, email: "a@example.com", issue: "camp-#{index}")
        end
      end
      assert_equal @game.pool_size, @game.issues.count
    end
end
