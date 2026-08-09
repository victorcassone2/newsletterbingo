class RemoveSlugFromPublications < ActiveRecord::Migration[8.1]
  def change
    remove_column :publications, :slug, :string, null: false
  end
end
