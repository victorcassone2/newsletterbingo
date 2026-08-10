class RemoveNameFromGames < ActiveRecord::Migration[8.1]
  def change
    remove_column :games, :name, :string, null: false, default: ""
  end
end
