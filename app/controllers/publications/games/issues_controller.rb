class Publications::Games::IssuesController < Publications::Games::BaseController
  # Undo a spurious advance (test send, forged token): the word goes back
  # in the queue. Only the latest issue, and only before anyone claims.
  def destroy
    issue = @game.issues.find(params[:id])
    if issue.rollbackable?
      label = issue.daily_call.label
      issue.rollback
      back_to_game notice: "#{label} is back in the queue."
    else
      back_to_game alert: "That word can't be re-queued — readers have already claimed it."
    end
  end
end
