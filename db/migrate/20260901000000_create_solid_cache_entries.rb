class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    # Bigint keys, not the app-wide UUID default: these rows are cache
    # bookkeeping written on every request, never referenced by domain code.
    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false

      t.index :byte_size
      t.index [ :key_hash, :byte_size ]
      t.index :key_hash, unique: true
    end
  end
end
