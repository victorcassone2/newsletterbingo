class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words, id: :uuid do |t|
      t.references :publication, null: true, foreign_key: true, type: :uuid
      t.string :label, null: false
      t.datetime :archived_at

      t.timestamps
    end

    add_index :words, "lower(label)", unique: true, where: "publication_id IS NULL",
      name: "index_words_on_system_label"
    add_index :words, "publication_id, lower(label)", unique: true, where: "publication_id IS NOT NULL",
      name: "index_words_on_publication_label"
  end
end
