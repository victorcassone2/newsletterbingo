class CreateAccountDeactivations < ActiveRecord::Migration[8.1]
  def change
    create_table :account_deactivations, id: :uuid do |t|
      t.uuid :account_id, null: false

      t.timestamps

      t.index :account_id, unique: true
    end
  end
end
