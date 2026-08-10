class Publications::Games::Calls::PositionsController < Publications::Games::BaseController
  # Drag-and-drop reordering of the words still waiting to go out.
  def update
    @game.daily_calls.find(params[:call_id]).move_word_to(params[:to].to_i)
    head :no_content
  rescue DailyCall::WordLocked
    head :unprocessable_entity
  end
end
