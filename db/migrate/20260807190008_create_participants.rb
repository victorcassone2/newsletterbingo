class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants, id: :uuid do |t|
      t.references :publication, null: false, foreign_key: true, type: :uuid
      t.string :email, null: false
      t.string :public_token, null: false

      t.timestamps
    end

    add_index :participants, [ :publication_id, :email ], unique: true
    add_index :participants, :public_token, unique: true
  end
end
