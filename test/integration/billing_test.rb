require "test_helper"
require "ostruct"
require "minitest/mock"

# Subscription lifecycle end-to-end, with the Payments seam stubbed: checkout
# redirect, sync-on-return, webhooks (idempotent, tenant-isolated), and the
# game-rotation gate that lapsing closes and subscribing reopens.
class BillingTest < ActionDispatch::IntegrationTest
  # Stands in for Payments::Gateway; records params so tests can assert on
  # what would have been sent to Stripe.
  class FakeGateway
    attr_reader :checkout_params, :portal_params

    def initialize(checkout: nil, subscription: nil)
      @checkout = checkout
      @subscription = subscription
    end

    def create_customer(**params)
      OpenStruct.new(id: "cus_new_1")
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

  test "subscribe creates the account's customer and bounces to hosted checkout" do
    gateway = FakeGateway.new
    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: @publication.id)
    end

    assert_redirected_to "https://checkout.stripe.test/pay"
    assert_equal "cus_new_1", @account.reload.stripe_customer_id
    assert_equal "subscription", gateway.checkout_params[:mode]
    assert_equal "cus_new_1", gateway.checkout_params[:customer]
    assert_equal @publication.id, gateway.checkout_params[:subscription_data][:metadata][:publication_id]
    assert_equal @account.id, gateway.checkout_params[:subscription_data][:metadata][:account_id]
    assert_includes gateway.checkout_params[:success_url], "session_id={CHECKOUT_SESSION_ID}"
  end

  test "an already-subscribed publication is not sent back to checkout" do
    @publication.update!(stripe_subscription_id: "sub_1", subscription_status: "active")
    gateway = FakeGateway.new
    Payments.stub(:platform, gateway) do
      post account_publication_subscription_path(account_id: @account.id, publication_id: @publication.id)
    end

    assert_redirected_to edit_account_publication_path(account_id: @account.id, id: @publication.id, anchor: "billing")
    assert_nil gateway.checkout_params
  end

  test "checkout return syncs the subscription without waiting for the webhook" do
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new(
      checkout: OpenStruct.new(customer: "cus_own", subscription: "sub_9"),
      subscription: stripe_subscription(id: "sub_9", status: "active", publication: @publication)
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

  test "the portal hands out a one-time billing URL for the account's customer" do
    @account.update!(stripe_customer_id: "cus_own")
    gateway = FakeGateway.new
    Payments.stub(:platform, gateway) do
      post account_publication_subscription_portal_path(account_id: @account.id, publication_id: @publication.id)
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
    assert_match(/Subscribe/, flash[:alert])
  end

  private
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
