class AddSponsorNameToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :sponsor_name, :string
  end
end
