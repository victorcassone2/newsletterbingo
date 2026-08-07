class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :slug, null: false
      t.string :public_code, null: false
      t.string :timezone, null: false, default: "America/Chicago"
      t.string :primary_color, null: false, default: "#1F2937"
      t.string :accent_color, null: false, default: "#2563EB"
      t.string :background_color, null: false, default: "#F9FAFB"
      t.string :text_color, null: false, default: "#111827"
      t.string :email_merge_tag, null: false, default: "{{email}}"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :publications, :public_code, unique: true
    add_index :publications, [ :account_id, :slug ], unique: true
  end
end
