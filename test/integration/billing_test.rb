require "test_helper"
require "ostruct"
require "minitest/mock"

# Subscription lifecycle end-to-end, with the Payments seam stubbed: one
# subscription per account (quantity = billable publications), started the
# moment the first publication is created -- directly with a card on file,
# through hosted Checkout without. Cancels in-app at period end, webhooks
# stay idempotent and tenant-isolated, and lapsing gates game rotation.
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

  test "creating the first publication with no card bounces to checkout, trial and quantity attached" do
    make_unsubscribed @account
    gateway = FakeGateway.new

    Payments.stub(:platform, gateway) do
      post account_publications_path(account_id: @account.id), params: {
        publication: { name: "Card Upfront Weekly", timezone: "America/Chicago" }
      }
    end

    publication = @account.publications.find_by(name: "Card Upfront Weekly")
    assert publication.present?
    assert_redirected_to "https://checkout.stripe.test/pay"
    assert_equal "cus_new_1", @account.reload.stripe_customer_id
    assert_equal "subscription", gateway.checkout_params[:mode]
    assert_equal 3, gateway.checkout_params[:line_items].first[:quantity],
      "the new publication joins the two fixtures on one subscription"
    assert_equal 30, gateway.checkout_params[:subscription_data][:trial_period_days]
    assert_equal @account.id, gateway.checkout_params[:subscription_data][:metadata][:account_id]
    assert_includes gateway.checkout_params[:success_url], "session_id={CHECKOUT_SESSION_ID}"
    assert_includes gateway.checkout_params[:success_url], "publication_id=#{publication.id}"
    assert_nil gateway.subscription_params
    assert_not publication.billing_active?, "no free ride for abandoned checkouts"
  end

  test "creating a publication with a card on file starts the subscription directly and lands on Setup" do
    make_unsubscribed @account
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(payment_methods: [ fake_card ],
      subscription: stripe_subscription(id: "sub_new", status: "trialing", account: @account))

    Payments.stub(:platform, gateway) do
      post account_publications_path(account_id: @account.id), params: {
        publication: { name: "Fresh Daily", timezone: "America/Chicago" }
      }
    end

    publication = @account.publications.find_by(name: "Fresh Daily")
    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: publication.id)
    assert_equal 30, gateway.subscription_params[:trial_period_days]
    assert_equal "pm_1", gateway.subscription_params[:default_payment_method]
    assert_equal 3, gateway.subscription_params[:items].first[:quantity]
    assert @account.reload.subscribed?
    assert publication.billing_active?
  end

  test "creating a publication on a subscribed account touches no billing UI, just re-points the quantity" do
    gateway = FakeGateway.new
    assert_enqueued_with job: Account::SyncSubscriptionQuantityJob, args: [ @account ] do
      Payments.stub(:platform, gateway) do
        post account_publications_path(account_id: @account.id), params: {
          publication: { name: "Third Herald", timezone: "America/Chicago" }
        }
      end
    end

    publication = @account.publications.find_by(name: "Third Herald")
    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: publication.id)
    assert_nil gateway.checkout_params
    assert_nil gateway.subscription_params
  end

  test "restarting a canceled subscription charges from day one" do
    @account.update!(subscription_status: "canceled", stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(payment_methods: [ fake_card ],
      subscription: stripe_subscription(id: "sub_new", status: "active", account: @account))

    Payments.stub(:platform, gateway) do
      post account_billing_subscription_path(account_id: @account.id)
    end

    assert_redirected_to account_billing_path(account_id: @account.id)
    assert_nil gateway.subscription_params[:trial_period_days]
    assert_equal 2, gateway.subscription_params[:items].first[:quantity]
    assert @account.reload.subscribed?
  end

  test "an already-subscribed account is never re-billed" do
    gateway = FakeGateway.new(payment_methods: [ fake_card ])
    Payments.stub(:platform, gateway) do
      post account_billing_subscription_path(account_id: @account.id)
    end

    assert_redirected_to account_billing_path(account_id: @account.id)
    assert_nil gateway.checkout_params
    assert_nil gateway.subscription_params
  end

  test "publication pages carry the free-trial banner while the account trial runs" do
    @account.update!(subscription_status: "trialing", subscription_current_period_end: 20.days.from_now)
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert_match "Free trial — your first charge of $58", response.body

    @account.update!(subscription_status: "active")
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert_no_match(/Free trial —/, response.body)
  end

  test "canceling schedules the end of the paid period, and can be undone" do
    gateway = FakeGateway.new(subscription: OpenStruct.new(id: "sub_publisher", status: "active",
      customer: "cus_own", current_period_end: 20.days.from_now.to_i, cancel_at_period_end: true))

    Payments.stub(:platform, gateway) do
      post account_billing_subscription_cancellation_path(account_id: @account.id)
    end
    assert_equal [ "sub_publisher", { cancel_at_period_end: true } ], gateway.update_args
    assert @account.reload.cancel_scheduled?
    assert @publication.billing_active?, "paid through the period end"

    undo = FakeGateway.new(subscription: OpenStruct.new(id: "sub_publisher", status: "active",
      customer: "cus_own", current_period_end: 20.days.from_now.to_i, cancel_at_period_end: false))
    Payments.stub(:platform, undo) do
      delete account_billing_subscription_cancellation_path(account_id: @account.id)
    end
    assert_equal [ "sub_publisher", { cancel_at_period_end: false } ], undo.update_args
    assert_not @account.reload.cancel_scheduled?
  end

  test "checkout return syncs the subscription and lands on the publication that started it" do
    make_unsubscribed @account
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(
      checkout: OpenStruct.new(customer: "cus_own", subscription: "sub_9"),
      subscription: stripe_subscription(id: "sub_9", status: "trialing", account: @account)
    )
    Payments.stub(:platform, gateway) do
      get account_billing_subscription_return_path(account_id: @account.id,
        session_id: "cs_9", publication_id: @publication.id)
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id)
    assert @account.reload.subscribed?
    assert_equal "sub_9", @account.stripe_subscription_id
  end

  test "a pasted foreign checkout session never overwrites subscription state" do
    make_unsubscribed @account
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(
      checkout: OpenStruct.new(customer: "cus_someone_else", subscription: "sub_evil"),
      subscription: stripe_subscription(id: "sub_evil", status: "active", account: @account)
    )
    Payments.stub(:platform, gateway) do
      get account_billing_subscription_return_path(account_id: @account.id, session_id: "cs_foreign")
    end

    assert_nil @account.reload.stripe_subscription_id
    assert_not @account.subscribed?
  end

  test "the billing page shows the one subscription and the portal opens from it" do
    get account_billing_path(account_id: @account.id)
    assert_response :success
    assert_match "$58/month", response.body

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
    @account.update!(subscription_status: "canceled")

    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert game.reload.completed?
    assert_nil @publication.active_game, "lapsed: the finished game gets no successor"
    assert_match "subscribe to keep the streak going", response.body

    fire_webhook subscription_event(id: "evt_sub_1", type: "customer.subscription.updated",
      subscription: stripe_subscription(id: "sub_publisher", status: "active", account: @account))
    assert_response :ok
    assert @account.reload.subscribed?

    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    assert @publication.active_game.present?, "the next visit launches the on-deck game"
  end

  test "a deleted webhook downgrades the account" do
    fire_webhook subscription_event(id: "evt_del_1", type: "customer.subscription.deleted",
      subscription: stripe_subscription(id: "sub_publisher", status: "canceled", account: @account))

    @account.reload
    assert_not @account.subscribed?
    assert_equal :inactive, @account.billing_state
  end

  test "a redelivered event id is acked without reapplying state" do
    event = subscription_event(id: "evt_dup", type: "customer.subscription.updated",
      subscription: stripe_subscription(id: "sub_publisher", status: "active", account: @account))

    fire_webhook event
    assert_equal "active", @account.reload.subscription_status

    # A later, fresher truth landed in between; the replayed old event must not undo it.
    @account.update!(subscription_status: "canceled")
    fire_webhook event
    assert_response :ok
    assert_equal "canceled", @account.reload.subscription_status
  end

  test "a webhook for one account never touches another" do
    fire_webhook subscription_event(id: "evt_iso", type: "customer.subscription.updated",
      subscription: stripe_subscription(id: "sub_publisher", status: "canceled", account: @account))

    assert_not @account.reload.subscribed?
    assert accounts(:rival).reload.subscribed?
  end

  test "the metadata fallback never overwrites an account's live subscription" do
    # A stray event from some other subscription (say a pre-migration
    # per-publication one) carries our account_id but not our subscription id.
    fire_webhook subscription_event(id: "evt_stray", type: "customer.subscription.deleted",
      subscription: stripe_subscription(id: "sub_old_duplicate", status: "canceled", account: @account))

    assert_response :ok
    assert_equal "sub_publisher", @account.reload.stripe_subscription_id
    assert @account.subscribed?, "the live subscription's state survives"
  end

  test "a webhook that resolves no account is acked and ignored" do
    make_unsubscribed @account
    orphan = stripe_subscription(id: "sub_ghost", status: "active", account: @account)
    orphan.metadata = {}
    fire_webhook subscription_event(id: "evt_ghost", type: "customer.subscription.created", subscription: orphan)

    assert_response :ok
    assert_nil @account.reload.subscription_status
  end

  test "an unverifiable webhook signature is rejected" do
    post stripe_webhook_path, params: "{}", headers: { "Stripe-Signature" => "bogus" }
    assert_response :bad_request
  end

  test "launching a game is blocked while the account is inactive" do
    @account.update!(subscription_status: "canceled")
    get account_publication_today_path(account_id: @account.id, publication_id: @publication.id)
    game = @publication.games.draft.first

    post account_publication_game_launch_path(account_id: @account.id, publication_id: @publication.id,
      game_id: game.id)

    assert game.reload.draft?
    assert_match(/subscription/, flash[:alert])
  end

  private
    def make_unsubscribed(account)
      account.update!(stripe_subscription_id: nil, subscription_status: nil,
        subscription_current_period_end: nil)
    end

    def fake_card
      OpenStruct.new(id: "pm_1", card: OpenStruct.new(brand: "visa", last4: "4242"))
    end

    def stripe_subscription(id:, status:, account:)
      OpenStruct.new(
        id: id, status: status, customer: "cus_hook",
        metadata: { "account_id" => account.id },
        items: OpenStruct.new(data: [ OpenStruct.new(id: "si_1", quantity: 1,
          current_period_end: 30.days.from_now.to_i) ])
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
