module GamesHelper
  # Games have no names; they're identified by when they ran.
  def game_label(game)
    if game.draft?
      "Next game"
    elsif game.publication.issue_cadence?
      first_called = game.issued_calls.first&.call_on || game.starts_on
      last_called = game.issued_calls.last&.call_on
      if game.completed?
        "#{first_called.strftime("%b %-d")} – #{(last_called || first_called).strftime("%b %-d, %Y")}"
      else
        "Started #{first_called.strftime("%b %-d, %Y")}"
      end
    else
      "#{game.starts_on.strftime("%b %-d")} – #{game.ends_on.strftime("%b %-d, %Y")}"
    end
  end
end
