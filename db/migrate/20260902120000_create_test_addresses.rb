class CreateTestAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :test_addresses, id: :uuid do |t|
      t.references :publication, null: false, type: :uuid, index: true
      t.string :email, null: false
      t.timestamps
    end

    add_index :test_addresses, %i[ publication_id email ], unique: true
  end
end
