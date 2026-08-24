class AddGameFormats < ActiveRecord::Migration[8.1]
  def change
    # The publication-level choice new drafts copy.
    add_column :publications, :board_size, :integer, null: false, default: 5

    # Snapshotted per game at draft time, like word labels: a game's
    # format never changes under a player.
    add_column :games, :board_size, :integer
    add_column :games, :pool_size, :integer
    reversible do |dir|
      dir.up do
        execute "UPDATE games SET board_size = 5, pool_size = 24"
      end
    end
    change_column_null :games, :board_size, false
    change_column_null :games, :pool_size, false
    add_check_constraint :games, "board_size IN (3, 5)", name: "games_board_size_check"
    add_check_constraint :games, "pool_size >= board_size * board_size - 1", name: "games_pool_covers_board"

    # The FREE center is no longer always position 12; it now depends on
    # the game's board size, so the app enforces it instead.
    remove_check_constraint :bingo_squares, '("position" = 12) = (game_word_id IS NULL)',
      name: "bingo_squares_free_center"
  end
end
