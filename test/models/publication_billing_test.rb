require "test_helper"
require "ostruct"
require "minitest/mock"

class PublicationBillingTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "a new publication starts a 30-day trial automatically" do
    publication = accounts(:publisher).publications.create!(name: "Fresh Daily")
    assert_in_delta 30.days.from_now, publication.trial_ends_at, 1.minute
    assert publication.in_trial?
    assert publication.billing_active?
    assert_equal :trialing, publication.billing_state
  end

  test "billing_state walks the whole ladder" do
    assert_equal :trialing, @publication.billing_state

    @publication.update!(trial_ends_at: 1.day.ago)
    assert_equal :trial_expired, @publication.billing_state
    assert_not @publication.billing_active?

    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "active")
    assert_equal :subscribed, @publication.billing_state

    @publication.update!(subscription_status: "past_due")
    assert_equal :past_due, @publication.billing_state
    assert @publication.subscribed?, "past_due rides Stripe's retry window"
    assert @publication.billing_active?

    @publication.update!(subscription_status: "canceled")
    assert_equal :canceled, @publication.billing_state
    assert_not @publication.billing_active?

    @publication.update!(complimentary: true)
    assert_equal :complimentary, @publication.billing_state
    assert @publication.billing_active?
  end

  test "a canceled subscription coasts on whatever trial time remains" do
    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "canceled",
      trial_ends_at: 5.days.from_now)
    assert @publication.in_trial?
    assert @publication.billing_active?
  end

  test "an in-trial publication rotates into new games" do
    game = create_running_game(@publication)
    game.update_columns(starts_on: @publication.local_date - 40, ends_on: @publication.local_date - 17)

    @publication.rotate_games

    assert game.reload.completed?
    assert @publication.active_game.present?
  end

  test "a lapsed publication's game plays out but no successor launches" do
    game = create_running_game(@publication)
    game.update_columns(starts_on: @publication.local_date - 40, ends_on: @publication.local_date - 17)
    @publication.update!(trial_ends_at: 1.day.ago)

    @publication.rotate_games

    assert game.reload.completed?, "the running game still completes"
    assert_nil @publication.active_game, "no successor launches while lapsed"
    assert @publication.on_deck_game.present?, "drafting continues so resubscribing resumes instantly"
  end

  test "past_due keeps games rotating through Stripe's retry window" do
    game = create_running_game(@publication)
    game.update_columns(starts_on: @publication.local_date - 40, ends_on: @publication.local_date - 17)
    @publication.update!(trial_ends_at: 1.day.ago,
      stripe_subscription_id: "sub_1", subscription_status: "past_due")

    @publication.rotate_games

    assert @publication.active_game.present?
  end

  test "complimentary bypasses billing entirely" do
    game = create_running_game(@publication)
    game.update_columns(starts_on: @publication.local_date - 40, ends_on: @publication.local_date - 17)
    @publication.update!(trial_ends_at: 1.day.ago, complimentary: true)

    @publication.rotate_games

    assert @publication.active_game.present?
  end

  test "sync copies status, takes period end from items, and writes the customer up to the account" do
    period_end = 30.days.from_now.to_i
    subscription = OpenStruct.new(
      id: "sub_9", status: "active",
      customer: OpenStruct.new(id: "cus_expanded"),
      items: OpenStruct.new(data: [ OpenStruct.new(current_period_end: period_end) ])
    )

    @publication.sync_stripe_subscription!(subscription)

    @publication.reload
    assert_equal "sub_9", @publication.stripe_subscription_id
    assert_equal "active", @publication.subscription_status
    assert_in_delta Time.zone.at(period_end), @publication.subscription_current_period_end, 1.second
    assert_equal "cus_expanded", @publication.account.reload.stripe_customer_id,
      "an expanded customer object still lands as an id on the account"
  end

  test "sync accepts a top-level current_period_end and never clobbers an existing account customer" do
    @publication.account.update!(stripe_customer_id: "cus_original")
    period_end = 10.days.from_now.to_i
    subscription = OpenStruct.new(id: "sub_9", status: "active", customer: "cus_other",
      current_period_end: period_end)

    @publication.sync_stripe_subscription!(subscription)

    assert_in_delta Time.zone.at(period_end), @publication.reload.subscription_current_period_end, 1.second
    assert_equal "cus_original", @publication.account.reload.stripe_customer_id
  end
end
