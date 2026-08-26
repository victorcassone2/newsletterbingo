# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_26_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_deactivations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_deactivations_on_account_id", unique: true
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.boolean "subscription_cancel_at_period_end", default: false, null: false
    t.datetime "subscription_current_period_end"
    t.string "subscription_status"
    t.datetime "updated_at", null: false
    t.index ["stripe_customer_id"], name: "index_accounts_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_accounts_on_stripe_subscription_id"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bingo_boards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "bingo_achieved_at"
    t.datetime "blackout_achieved_at"
    t.datetime "created_at", null: false
    t.uuid "game_id", null: false
    t.uuid "participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_bingo_boards_on_game_id"
    t.index ["participant_id", "game_id"], name: "index_bingo_boards_on_participant_id_and_game_id", unique: true
    t.index ["participant_id"], name: "index_bingo_boards_on_participant_id"
  end

  create_table "bingo_squares", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "bingo_board_id", null: false
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.uuid "game_word_id"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["bingo_board_id", "game_word_id"], name: "index_bingo_squares_on_board_word", unique: true, where: "(game_word_id IS NOT NULL)"
    t.index ["bingo_board_id", "position"], name: "index_bingo_squares_on_bingo_board_id_and_position", unique: true
    t.index ["bingo_board_id"], name: "index_bingo_squares_on_bingo_board_id"
    t.index ["game_word_id"], name: "index_bingo_squares_on_game_word_id"
    t.check_constraint "\"position\" >= 0 AND \"position\" <= 24", name: "bingo_squares_position_range"
  end

  create_table "daily_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "call_on"
    t.datetime "created_at", null: false
    t.text "description"
    t.uuid "game_id", null: false
    t.uuid "game_word_id", null: false
    t.integer "link_clicks_count", default: 0, null: false
    t.string "link_text"
    t.string "link_url"
    t.integer "position", null: false
    t.boolean "prize_call", default: false, null: false
    t.string "prize_description"
    t.datetime "updated_at", null: false
    t.index ["game_id", "call_on"], name: "index_daily_calls_on_game_id_and_call_on"
    t.index ["game_id", "position"], name: "index_daily_calls_on_game_id_and_position", unique: true
    t.index ["game_id"], name: "index_daily_calls_on_game_id"
    t.index ["game_word_id"], name: "index_daily_calls_on_game_word_id"
    t.unique_constraint ["game_id", "game_word_id"], deferrable: :deferred, name: "daily_calls_game_word_unique"
  end

  create_table "daily_claims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "claimed_at", null: false
    t.datetime "created_at", null: false
    t.uuid "daily_call_id", null: false
    t.uuid "game_id", null: false
    t.uuid "participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_call_id", "claimed_at"], name: "index_daily_claims_on_daily_call_id_and_claimed_at"
    t.index ["daily_call_id"], name: "index_daily_claims_on_daily_call_id"
    t.index ["game_id", "claimed_at"], name: "index_daily_claims_on_game_id_and_claimed_at"
    t.index ["game_id"], name: "index_daily_claims_on_game_id"
    t.index ["participant_id", "daily_call_id"], name: "index_daily_claims_on_participant_id_and_daily_call_id", unique: true
    t.index ["participant_id"], name: "index_daily_claims_on_participant_id"
  end

  create_table "game_words", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "game_id", null: false
    t.string "label", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.uuid "word_id", null: false
    t.index "game_id, lower((label)::text)", name: "index_game_words_on_game_label", unique: true
    t.index ["game_id", "word_id"], name: "index_game_words_on_game_id_and_word_id", unique: true
    t.index ["game_id"], name: "index_game_words_on_game_id"
    t.index ["word_id"], name: "index_game_words_on_word_id"
  end

  create_table "games", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "board_size", null: false
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.integer "pool_size", null: false
    t.uuid "publication_id", null: false
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_id"], name: "index_games_on_publication_id"
    t.index ["publication_id"], name: "index_games_one_active_per_publication", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["publication_id"], name: "index_games_one_draft_per_publication", unique: true, where: "((status)::text = 'draft'::text)"
    t.check_constraint "board_size = ANY (ARRAY[3, 5])", name: "games_board_size_check"
    t.check_constraint "ends_on >= starts_on", name: "games_span_forward"
    t.check_constraint "pool_size >= (board_size * board_size - 1)", name: "games_pool_covers_board"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'completed'::character varying::text])", name: "games_status_check"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email_address"], name: "index_invitations_on_account_id_and_email_address", unique: true
    t.index ["account_id"], name: "index_invitations_on_account_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "issues", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "called_on", null: false
    t.datetime "created_at", null: false
    t.uuid "daily_call_id", null: false
    t.uuid "game_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_call_id"], name: "index_issues_on_daily_call_id"
    t.index ["game_id", "token"], name: "index_issues_on_game_id_and_token", unique: true
    t.index ["game_id"], name: "index_issues_on_game_id"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id", "user_id"], name: "index_memberships_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'member'::character varying::text])", name: "memberships_role_check"
  end

  create_table "participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "public_token", null: false
    t.uuid "publication_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_token"], name: "index_participants_on_public_token", unique: true
    t.index ["publication_id", "email"], name: "index_participants_on_publication_id_and_email", unique: true
    t.index ["publication_id"], name: "index_participants_on_publication_id"
  end

  create_table "prize_awards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "awarded_at", null: false
    t.datetime "created_at", null: false
    t.uuid "game_id", null: false
    t.string "kind", null: false
    t.uuid "participant_id", null: false
    t.uuid "prize_id", null: false
    t.string "prize_name"
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_prize_awards_on_game_id"
    t.index ["participant_id", "game_id", "kind"], name: "index_prize_awards_on_participant_id_and_game_id_and_kind", unique: true
    t.index ["participant_id"], name: "index_prize_awards_on_participant_id"
    t.index ["prize_id"], name: "index_prize_awards_on_prize_id"
    t.check_constraint "kind::text = ANY (ARRAY['line'::character varying::text, 'blackout'::character varying::text])", name: "prize_awards_kind_check"
  end

  create_table "prizes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "enabled", default: false, null: false
    t.string "instructions"
    t.string "kind", null: false
    t.integer "link_clicks_count", default: 0, null: false
    t.string "link_text"
    t.string "link_url"
    t.string "name"
    t.uuid "publication_id", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_id", "kind"], name: "index_prizes_on_publication_id_and_kind", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['line'::character varying::text, 'blackout'::character varying::text])", name: "prizes_kind_check"
  end

  create_table "processed_webhook_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_processed_webhook_events_on_event_id", unique: true
  end

  create_table "publications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "accent_color", default: "#f59e0b", null: false
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "background_color", default: "#fcfcfc", null: false
    t.integer "board_size", default: 5, null: false
    t.string "cadence", default: "issues", null: false
    t.string "campaign_merge_tag", default: "{{campaign_id}}", null: false
    t.boolean "complimentary", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_merge_tag", default: "{{email}}", null: false
    t.string "name", null: false
    t.string "primary_color", default: "#b45309", null: false
    t.string "public_code", null: false
    t.integer "send_days", default: [0, 1, 2, 3, 4, 5, 6], null: false, array: true
    t.string "sponsor_name"
    t.string "text_color", default: "#2a2118", null: false
    t.string "timezone", default: "America/Chicago", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_publications_on_account_id"
    t.index ["public_code"], name: "index_publications_on_public_code", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "words", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.uuid "publication_id"
    t.datetime "updated_at", null: false
    t.index "lower((label)::text)", name: "index_words_on_system_label", unique: true, where: "(publication_id IS NULL)"
    t.index "publication_id, lower((label)::text)", name: "index_words_on_publication_label", unique: true, where: "(publication_id IS NOT NULL)"
    t.index ["publication_id"], name: "index_words_on_publication_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bingo_boards", "games"
  add_foreign_key "bingo_boards", "participants"
  add_foreign_key "bingo_squares", "bingo_boards"
  add_foreign_key "bingo_squares", "game_words"
  add_foreign_key "daily_calls", "game_words"
  add_foreign_key "daily_calls", "games"
  add_foreign_key "daily_claims", "daily_calls"
  add_foreign_key "daily_claims", "games"
  add_foreign_key "daily_claims", "participants"
  add_foreign_key "game_words", "games"
  add_foreign_key "game_words", "words"
  add_foreign_key "games", "publications"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "participants", "publications"
  add_foreign_key "prize_awards", "games"
  add_foreign_key "prize_awards", "participants"
  add_foreign_key "prize_awards", "prizes"
  add_foreign_key "prizes", "publications"
  add_foreign_key "publications", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "words", "publications"
end
