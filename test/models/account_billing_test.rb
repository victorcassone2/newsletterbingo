require "test_helper"
require "ostruct"
require "minitest/mock"

class AccountBillingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @account = accounts(:publisher)
    @publication = publications(:omaha)
  end

  # A Stripe subscription whose one item sits at the given quantity.
  def stripe_item_at(quantity)
    OpenStruct.new(id: "sub_publisher", status: "active", customer: "cus_x",
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_1", quantity: quantity,
        current_period_end: 20.days.from_now.to_i) ]))
  end

  test "billing_state is exactly three situations" do
    assert_equal :active, @account.billing_state

    @account.update!(subscription_status: "trialing")
    assert_equal :active, @account.billing_state
    assert @account.trialing?

    @account.update!(subscription_status: "past_due")
    assert_equal :payment_problem, @account.billing_state
    assert @account.subscribed?, "past_due rides Stripe's retry window"

    @account.update!(subscription_status: "canceled")
    assert_equal :inactive, @account.billing_state
    assert_not @account.subscribed?

    @account.update!(subscription_status: nil, stripe_subscription_id: nil)
    assert_equal :inactive, @account.billing_state, "never-subscribed and canceled look the same"
  end

  test "trial params: full trial for a first subscription, none for a restart" do
    fresh = Account.create!(name: "Fresh Account")
    assert_equal({ trial_period_days: 30 }, fresh.stripe_trial_params)

    assert_equal({}, @account.stripe_trial_params, "a restart pays from day one")
  end

  test "monthly price counts billable publications only" do
    assert_equal 58, @account.monthly_price, "two publications at $29"

    @publication.update!(complimentary: true)
    assert_equal 29, @account.monthly_price

    assert_equal 1, @account.subscription_quantity
  end

  test "subscription quantity never drops below one" do
    fresh = Account.create!(name: "Empty Account")
    assert_equal 1, fresh.subscription_quantity
  end

  test "billing_active? gates on the account, complimentary rides free" do
    assert @publication.billing_active?

    @account.update!(subscription_status: "canceled")
    assert_not @publication.reload.billing_active?

    @publication.update!(complimentary: true)
    assert @publication.billing_active?
  end

  test "a subscribed account rotates its publications into new games" do
    game = age_out_game(create_running_game(@publication))

    @publication.rotate_games

    assert game.reload.completed?
    assert @publication.active_game.present?
  end

  test "a lapsed account's game plays out but no successor launches" do
    game = age_out_game(create_running_game(@publication))
    @account.update!(subscription_status: "canceled")

    @publication.rotate_games

    assert game.reload.completed?, "the running game still completes"
    assert_nil @publication.active_game, "no successor launches while lapsed"
    assert @publication.on_deck_game.present?, "drafting continues so resubscribing resumes instantly"
  end

  test "sync copies status, takes period end from items, and keeps the customer id" do
    period_end = 30.days.from_now.to_i
    subscription = OpenStruct.new(
      id: "sub_9", status: "active",
      customer: OpenStruct.new(id: "cus_expanded"),
      items: OpenStruct.new(data: [ OpenStruct.new(current_period_end: period_end) ])
    )

    @account.sync_stripe_subscription!(subscription)

    @account.reload
    assert_equal "sub_9", @account.stripe_subscription_id
    assert_equal "active", @account.subscription_status
    assert_in_delta Time.zone.at(period_end), @account.subscription_current_period_end, 1.second
    assert_equal "cus_expanded", @account.stripe_customer_id,
      "an expanded customer object still lands as an id"
  end

  test "sync records a scheduled cancellation and never clobbers an existing customer id" do
    @account.update!(stripe_customer_id: "cus_original")
    scheduled = OpenStruct.new(id: "sub_9", status: "active", customer: "cus_other",
      current_period_end: 10.days.from_now.to_i, cancel_at_period_end: true)

    @account.sync_stripe_subscription!(scheduled)

    assert @account.reload.cancel_scheduled?
    assert_equal "cus_original", @account.stripe_customer_id
  end

  test "quantity sync re-points the Stripe item at the billable count" do
    gateway = Minitest::Mock.new
    gateway.expect :retrieve_subscription, OpenStruct.new(
      id: "sub_publisher", status: "active", customer: "cus_x",
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_1", quantity: 1, current_period_end: 20.days.from_now.to_i) ])
    ), [ "sub_publisher" ]
    gateway.expect :update_subscription, OpenStruct.new(
      id: "sub_publisher", status: "active", customer: "cus_x",
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_1", quantity: 2, current_period_end: 20.days.from_now.to_i) ])
    ), [ "sub_publisher" ], items: [ { id: "si_1", quantity: 2 } ]

    Payments.stub(:platform, gateway) do
      @account.sync_subscription_quantity!
    end
    assert gateway.verify
  end

  test "quantity sync is a no-op when the quantity already matches, the account isn't subscribed, or nothing is billable" do
    gateway = Minitest::Mock.new
    gateway.expect :retrieve_subscription, OpenStruct.new(
      id: "sub_publisher", status: "active", customer: "cus_x",
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_1", quantity: 2, current_period_end: 20.days.from_now.to_i) ])
    ), [ "sub_publisher" ]
    Payments.stub(:platform, gateway) do
      @account.sync_subscription_quantity!
    end
    assert gateway.verify

    @account.update!(subscription_status: "canceled")
    Payments.stub(:platform, nil) do
      assert_nothing_raised { @account.sync_subscription_quantity! }
    end

    @account.update!(subscription_status: "active")
    @account.publications.update_all(complimentary: true)
    Payments.stub(:platform, nil) do
      assert_nothing_raised { @account.sync_subscription_quantity! }
    end
  end

  test "a canceled publication comes off the price right away but stays on the air" do
    assert_equal 58, @account.monthly_price

    @publication.close

    assert_equal 29, @account.reload.monthly_price, "off the next invoice immediately"
    assert @publication.canceled?
    assert_not @publication.closed?, "still running out the period it was paid for"
    assert_equal @account.subscription_current_period_end.to_date, @publication.closes_on
    assert_not_includes @account.billable_publications, @publication
    assert_includes @account.billable_publications, publications(:lincoln)
    assert_includes Publication.playable, @publication, "readers still reach it"
  end

  test "a canceled publication goes dark on its own when the paid period runs out" do
    @publication.close

    travel_to @publication.closes_on + 1.day do
      assert @publication.reload.closed?
      assert_not_includes Publication.playable, @publication
      assert_not @publication.billing_active?
    end
  end

  test "canceling stops the next game from starting, and the running one plays out" do
    game = age_out_game(create_running_game(@publication))
    @publication.close

    @publication.rotate_games

    assert game.reload.completed?, "the running game still completes"
    assert_nil @publication.active_game, "no game starts that couldn't finish before the lights go out"
    assert @publication.on_deck_game.present?, "drafting continues so calling it off resumes instantly"
  end

  test "canceling with nothing paid for goes dark on the spot" do
    @account.update!(subscription_status: "canceled")

    @publication.close

    assert @publication.closed?
    assert_equal Date.current, @publication.closes_on
  end

  test "canceling and calling it off enqueue quantity syncs with the right proration" do
    assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account, false ] do
      @publication.close
    end

    assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account, false ] do
      @publication.reopen
    end

    @publication.close
    travel_to @publication.closes_on + 1.day do
      assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account, true ] do
        @publication.reload.reopen
      end
    end
  end

  test "a quantity drop never credits the customer, a quantity rise prorates" do
    gateway = Minitest::Mock.new
    gateway.expect :retrieve_subscription, stripe_item_at(2), [ "sub_publisher" ]
    gateway.expect :update_subscription, stripe_item_at(1), [ "sub_publisher" ],
      items: [ { id: "si_1", quantity: 1 } ], proration_behavior: "none"

    @publication.close
    Payments.stub(:platform, gateway) do
      @account.sync_subscription_quantity!(prorate: false)
    end
    assert gateway.verify
  end

  test "the last publication the subscription pays for is not closable" do
    assert @publication.closable?, "two billable publications, either can go"

    publications(:lincoln).close
    assert_not @publication.reload.closable?

    # Lapsed accounts bill for nothing, so the bar is only that something stays open.
    @account.update!(subscription_status: "canceled")
    assert_not @publication.reload.closable?

    @account.publications.create!(name: "Bellevue Beacon")
    assert @publication.reload.closable?
  end

  test "a complimentary publication is closable even when it is the only billable one" do
    publications(:lincoln).update!(complimentary: true)
    assert_not @publication.closable?, "the only publication being billed"
    assert publications(:lincoln).closable?, "free ones carry no quantity to drop"
  end

  test "creating and destroying publications enqueues a quantity sync for subscribed accounts" do
    publication = nil
    assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account, true ] do
      publication = @account.publications.create!(name: "Papillion Post")
    end

    assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account, true ] do
      publication.destroy
    end

    @account.update!(subscription_status: nil, stripe_subscription_id: nil)
    assert_no_enqueued_jobs only: Account::SyncSubscriptionQuantityJob do
      @account.publications.create!(name: "La Vista Ledger")
    end
  end
end
