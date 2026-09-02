class AddPreviewTokenToPublications < ActiveRecord::Migration[8.1]
  def up
    add_column :publications, :preview_token, :string
    Publication.reset_column_information
    Publication.where(preview_token: nil).find_each do |publication|
      publication.update_columns(preview_token: Publication.generate_unique_secure_token(length: 24))
    end
    change_column_null :publications, :preview_token, false
    add_index :publications, :preview_token, unique: true
  end

  def down
    remove_column :publications, :preview_token
  end
end
