class AddFourByFourFormat < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :games, "board_size IN (3, 5)", name: "games_board_size_check"
    add_check_constraint :games, "board_size IN (3, 4, 5)", name: "games_board_size_check"

    # Even boards have no middle square, so every one of their cells
    # carries a word and the pool has to cover one more of them.
    remove_check_constraint :games, "pool_size >= board_size * board_size - 1", name: "games_pool_covers_board"
    add_check_constraint :games, "pool_size >= board_size * board_size - board_size % 2",
      name: "games_pool_covers_board"
  end
end
