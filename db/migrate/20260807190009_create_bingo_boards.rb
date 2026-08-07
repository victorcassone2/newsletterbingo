class CreateBingoBoards < ActiveRecord::Migration[8.1]
  def change
    create_table :bingo_boards, id: :uuid do |t|
      t.references :participant, null: false, foreign_key: true, type: :uuid
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.datetime :bingo_achieved_at
      t.datetime :blackout_achieved_at

      t.timestamps
    end

    add_index :bingo_boards, [ :participant_id, :game_id ], unique: true

    create_table :bingo_squares, id: :uuid do |t|
      t.references :bingo_board, null: false, foreign_key: true, type: :uuid
      t.references :game_word, null: true, foreign_key: true, type: :uuid
      t.integer :position, null: false
      t.datetime :claimed_at

      t.timestamps
    end

    add_index :bingo_squares, [ :bingo_board_id, :position ], unique: true
    add_index :bingo_squares, [ :bingo_board_id, :game_word_id ], unique: true,
      where: "game_word_id IS NOT NULL", name: "index_bingo_squares_on_board_word"
    add_check_constraint :bingo_squares, "position BETWEEN 0 AND 24", name: "bingo_squares_position_range"
    add_check_constraint :bingo_squares, "(position = 12) = (game_word_id IS NULL)",
      name: "bingo_squares_free_center"
  end
end
