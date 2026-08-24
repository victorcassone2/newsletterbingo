require "test_helper"
require "ostruct"
require "minitest/mock"

# Subscription lifecycle end-to-end, with the Payments seam stubbed: billing
# starts at newsletter creation (confirm with the card on file, or hosted
# Checkout to collect one), cancels in-app at period end, webhooks stay
# idempotent and tenant-isolated, and lapsing gates game rotation.
class BillingTest < ActionDispatch::IntegrationTest
  # Stands in for Payments::Gateway; records params so tests can assert on
  # what would have been sent to Stripe.
  class FakeGateway
    attr_reader :checkout_params, :portal_params, :subscription_params, :update_args

    def initialize(checkout: nil, subscription: nil, payment_methods: [])
      @checkout = checkout
      @subscription = subscription
      @payment_methods = payment_methods
    end

    def create_customer(**params)
      OpenStruct.new(id: "cus_new_1")
    end

    def retrieve_customer(id)
      OpenStruct.new(id: id,
        invoice_settings: OpenStruct.new(default_payment_method: @payment_methods.first&.id))
    end

    def list_payment_methods(customer_id)
      OpenStruct.new(data: @payment_methods)
    end

    def create_checkout_session(**params)
      @checkout_params = params
      OpenStruct.new(id: "cs_new", url: "https://checkout.stripe.test/pay")
    end

    def retrieve_checkout_session(id)
      @checkout
    end

    def retrieve_subscription(id)
      @subscription
    end

    def create_subscription(**params)
      @subscription_params = params
      @subscription
    end

    def update_subscription(id, **params)
      @update_args = [ id, params ]
      @subscription
    end

    def create_billing_portal_session(**params)
      @portal_params = params
      OpenStruct.new(url: "https://billing.stripe.test/portal")
    end
  end

  setup do
    sign_in_as users(:one)
    @account = accounts(:publisher)
    @publication = publications(:omaha)
  end

  test "creating a newsletter routes through the billing confirm page, gated until confirmed" do
    post account_publications_path(account_id: @account.id), params: {
      publication: { name: "Card Upfront Weekly", timezone: "America/Chicago" }
    }
    publication = @account.publications.find_by(name: "Card Upfront Weekly")
    assert_redirected_to new_account_publication_subscription_path(account_id: @account.id, publication_id: publication.id)
    assert_equal :pending, publication.billing_state
    assert_not publication.billing_active?, "no free ride for abandoned checkouts"
  end

  test "confirming with a card on file creates the subscription directly, trial included" do
    @account.update!(stripe_customer_id: "cus_own")
    publication = @account.publications.create!(name: "Fresh Daily")
    gateway = FakeGateway.new(payment_methods: [ fake_card ],
      subscription: stripe_subscription(id: "sub_new", status: "trialing", publication: publication))

    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: publication.id)
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: publication.id)
    assert_equal 30, gateway.subscription_params[:trial_period_days]
    assert_equal "pm_1", gateway.subscription_params[:default_payment_method]
    assert_equal publication.id, gateway.subscription_params[:metadata][:publication_id]
    assert publication.reload.subscribed?
    assert publication.billing_active?
  end

  test "publication pages carry a free-trial banner" do
    # Stripe card-upfront trial: first-charge date.
    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "trialing",
      subscription_current_period_end: 20.days.from_now)
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert_match "Free trial — your first charge of $29", response.body

    # Legacy app-side trial: days left + confirm nudge.
    lincoln = publications(:lincoln)
    get account_publication_today_path(account_id: @account.id, publication_id: lincoln.id)
    assert_match "Confirm billing", response.body

    # No trial, no banner.
    @publication.update!(subscription_status: "active")
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert_no_match(/Free trial —/, response.body)
  end

  test "confirming without a card bounces to hosted checkout with the trial attached" do
    gateway = FakeGateway.new
    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: @publication.id)
    end

    assert_redirected_to "https://checkout.stripe.test/pay"
    assert_equal "cus_new_1", @account.reload.stripe_customer_id
    assert_equal "subscription", gateway.checkout_params[:mode]
    assert_equal @publication.id, gateway.checkout_params[:subscription_data][:metadata][:publication_id]
    assert_equal @publication.trial_ends_at.to_i, gateway.checkout_params[:subscription_data][:trial_end],
      "a legacy publication carries its remaining app-side trial into Stripe"
    assert_includes gateway.checkout_params[:success_url], "session_id={CHECKOUT_SESSION_ID}"
    assert_nil gateway.subscription_params
  end

  test "restarting a canceled subscription charges from day one" do
    @account.update!(stripe_customer_id: "cus_own")
    @publication.update!(trial_ends_at: 1.day.ago,
      stripe_subscription_id: "sub_old", subscription_status: "canceled")
    gateway = FakeGateway.new(payment_methods: [ fake_card ],
      subscription: stripe_subscription(id: "sub_new", status: "active", publication: @publication))

    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: @publication.id)
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, anchor: "billing")
    assert_nil gateway.subscription_params[:trial_period_days]
    assert_nil gateway.subscription_params[:trial_end]
    assert @publication.reload.subscribed?
  end

  test "an already-subscribed publication is never re-billed" do
    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "active")
    gateway = FakeGateway.new(payment_methods: [ fake_card ])
    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: @publication.id)
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, anchor: "billing")
    assert_nil gateway.checkout_params
    assert_nil gateway.subscription_params
  end

  test "canceling schedules the end of the paid period, and can be undone" do
    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "active")
    gateway = FakeGateway.new(subscription: OpenStruct.new(id: "sub_1", status: "active",
      customer: "cus_own", current_period_end: 20.days.from_now.to_i, cancel_at_period_end: true))

    Payments.stub(:platform, gateway) do
      post account_publication_subscription_cancellation_path(account_id: @account.id, publication_id: @publication.id)
    end
    assert_equal [ "sub_1", { cancel_at_period_end: true } ], gateway.update_args
    assert @publication.reload.cancel_scheduled?
    assert @publication.billing_active?, "paid through the period end"

    undo = FakeGateway.new(subscription: OpenStruct.new(id: "sub_1", status: "active",
      customer: "cus_own", current_period_end: 20.days.from_now.to_i, cancel_at_period_end: false))
    Payments.stub(:platform, undo) do
      delete account_publication_subscription_cancellation_path(account_id: @account.id, publication_id: @publication.id)
    end
    assert_equal [ "sub_1", { cancel_at_period_end: false } ], undo.update_args
    assert_not @publication.reload.cancel_scheduled?
  end

  test "checkout return syncs the subscription without waiting for the webhook" do
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(
      checkout: OpenStruct.new(customer: "cus_own", subscription: "sub_9"),
      subscription: stripe_subscription(id: "sub_9", status: "trialing", publication: @publication)
    )
    Payments.stub(:platform, gateway) do
      get account_publication_subscription_return_path(account_id: @account.id, publication_id: @publication.id,
        session_id: "cs_9")
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, anchor: "billing")
    assert @publication.reload.subscribed?
    assert_equal "sub_9", @publication.stripe_subscription_id
  end

  test "a pasted foreign checkout session never overwrites subscription state" do
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(
      checkout: OpenStruct.new(customer: "cus_someone_else", subscription: "sub_evil"),
      subscription: stripe_subscription(id: "sub_evil", status: "active", publication: @publication)
    )
    Payments.stub(:platform, gateway) do
      get account_publication_subscription_return_path(account_id: @account.id, publication_id: @publication.id,
        session_id: "cs_foreign")
    end

    assert_nil @publication.reload.stripe_subscription_id
    assert_not @publication.subscribed?
  end

  test "the billing page and portal live at the account level" do
    get account_billing_path(account_id: @account.id)
    assert_response :success
    assert_match "collected when you confirm", response.body

    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new
    Payments.stub(:platform, gateway) do
      post account_billing_portal_path(account_id: @account.id)
    end
    assert_redirected_to "https://billing.stripe.test/portal"
    assert_equal "cus_own", gateway.portal_params[:customer]
  end

  test "a subscription webhook flips status and unblocks rotation on the next request" do
    game = create_running_game(@publication)
    game.update_columns(starts_on: @publication.local_date - 40, ends_on: @publication.local_date - 17)
    @publication.update!(trial_ends_at: 1.day.ago)

    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert game.reload.completed?
    assert_nil @publication.active_game, "lapsed: the finished game gets no successor"
    assert_match "subscribe to keep the streak going", response.body

    fire_webhook subscription_event(id: "evt_sub_1", type: "customer.subscription.created",
      subscription: stripe_subscription(id: "sub_1", status: "active", publication: @publication))
    assert_response :ok
    assert @publication.reload.subscribed?

    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert @publication.active_game.present?, "the next visit launches the on-deck game"
  end

  test "a deleted webhook downgrades the publication" do
    @publication.update!(trial_ends_at: 1.day.ago,
      stripe_subscription_id: "sub_1", subscription_status: "active")

    fire_webhook subscription_event(id: "evt_del_1", type: "customer.subscription.deleted",
      subscription: stripe_subscription(id: "sub_1", status: "canceled", publication: @publication))

    @publication.reload
    assert_not @publication.subscribed?
    assert_equal :canceled, @publication.billing_state
  end

  test "a redelivered event id is acked without reapplying state" do
    event = subscription_event(id: "evt_dup", type: "customer.subscription.updated",
      subscription: stripe_subscription(id: "sub_1", status: "active", publication: @publication))

    fire_webhook event
    assert_equal "active", @publication.reload.subscription_status

    # A later, fresher truth landed in between; the replayed old event must not undo it.
    @publication.update!(subscription_status: "canceled")
    fire_webhook event
    assert_response :ok
    assert_equal "canceled", @publication.reload.subscription_status
  end

  test "a webhook for one publication never touches another" do
    fire_webhook subscription_event(id: "evt_iso", type: "customer.subscription.created",
      subscription: stripe_subscription(id: "sub_omaha", status: "active", publication: @publication))

    assert @publication.reload.subscribed?
    assert_nil publications(:lincoln).reload.subscription_status
    assert_nil publications(:rival).reload.subscription_status
  end

  test "a webhook that resolves no publication is acked and ignored" do
    orphan = stripe_subscription(id: "sub_ghost", status: "active", publication: @publication)
    orphan.metadata = {}
    fire_webhook subscription_event(id: "evt_ghost", type: "customer.subscription.created", subscription: orphan)

    assert_response :ok
    assert_nil @publication.reload.subscription_status
  end

  test "an unverifiable webhook signature is rejected" do
    post stripe_webhook_path, params: "{}", headers: { "Stripe-Signature" => "bogus" }
    assert_response :bad_request
  end

  test "launching a game is blocked once the trial ends" do
    @publication.update!(trial_ends_at: 1.day.ago)
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    game = @publication.games.draft.first

    post account_publication_game_launch_path(account_id: @account.id, publication_id: @publication.id,
      game_id: game.id)

    assert game.reload.draft?
    assert_match(/billing/, flash[:alert])
  end

  private
    def fake_card
      OpenStruct.new(id: "pm_1", card: OpenStruct.new(brand: "visa", last4: "4242"))
    end

    def stripe_subscription(id:, status:, publication:)
      OpenStruct.new(
        id: id, status: status, customer: "cus_hook",
        metadata: { "publication_id" => publication.id },
        items: OpenStruct.new(data: [ OpenStruct.new(current_period_end: 30.days.from_now.to_i) ])
      )
    end

    def subscription_event(id:, type:, subscription:)
      OpenStruct.new(id: id, type: type, data: OpenStruct.new(object: subscription))
    end

    def fire_webhook(event)
      Payments.stub(:construct_webhook_event, event) do
        post stripe_webhook_path, params: "{}", headers: { "Stripe-Signature" => "sig" }
      end
    end
end
