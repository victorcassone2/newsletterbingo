require "test_helper"

class TenancyTest < ActionDispatch::IntegrationTest
  setup do
    @omaha = publications(:omaha)
    @rival = publications(:rival)
  end

  test "admin pages require authentication" do
    get account_publications_path(account_id: accounts(:publisher).id)
    assert_redirected_to new_session_path
  end

  test "a user cannot enter an account they don't belong to" do
    sign_in_as users(:two)
    get account_publications_path(account_id: accounts(:publisher).id)
    assert_redirected_to dashboard_path
  end

  test "a publication cannot be read through the wrong account" do
    sign_in_as users(:two)
    get account_publication_today_path(account_id: accounts(:rival).id, publication_id: @omaha.id)
    assert_response :not_found
  end

  test "a publication cannot be mutated through the wrong account" do
    sign_in_as users(:two)
    original_name = @omaha.name
    patch account_publication_path(account_id: accounts(:rival).id, id: @omaha.id),
      params: { publication: { name: "Hijacked" } }
    assert_response :not_found
    assert_equal original_name, @omaha.reload.name
  end

  test "words are scoped to the publication" do
    sign_in_as users(:one)
    get account_publication_words_path(account_id: accounts(:publisher).id, publication_id: @omaha.id)
    assert_response :success
    assert_match(/FARMERS MARKET/, response.body)
    assert_no_match(/RIVALWORD/, response.body)
  end

  test "another publication's prize cannot be edited through my publication" do
    sign_in_as users(:one)
    rival_prize = publications(:rival).line_prize
    patch account_publication_prize_path(account_id: accounts(:publisher).id,
      publication_id: @omaha.id, id: rival_prize.id),
      params: { prize: { enabled: "1", name: "Hijacked" } }
    assert_response :not_found
    assert_not rival_prize.reload.enabled?
  end

  test "games are scoped to the publication" do
    rival_game = create_running_game(@rival)
    sign_in_as users(:one)
    get account_publication_game_path(account_id: accounts(:publisher).id,
      publication_id: @omaha.id, id: rival_game.id)
    assert_response :not_found
  end

  test "participant data does not leak across publications" do
    omaha_reader = Participant.locate_or_register(@omaha, "reader@example.com")
    lincoln_reader = Participant.locate_or_register(publications(:lincoln), "reader@example.com")

    omaha_game = create_running_game(@omaha)
    omaha_game.current_call.claim_by(omaha_reader)

    assert_equal 1, omaha_reader.daily_claims.count
    assert_equal 0, lincoln_reader.daily_claims.count
    assert_equal 0, lincoln_reader.bingo_boards.count
  end
end
