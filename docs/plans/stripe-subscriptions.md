# Plan: Stripe subscriptions, billed per Publication

Goal: each Publication carries its own paid subscription (launch price $29/month,
create the Price so it can be changed without code). Reuse the **same Stripe
account** as `../local_deal_engine` and mirror its proven patterns. That app is
the reference implementation; read the files named below before writing code.

## Reference files in ../local_deal_engine (read these first)

- `config/initializers/stripe.rb` — ENV-first config hash pattern (`Rails.application.config.stripe`), test-env dummy fill.
- `app/models/payments.rb` — the single Stripe seam: `Payments.platform` returning a `Gateway` wrapper; `construct_webhook_event` tries each configured signing secret.
- `app/models/processed_webhook_event.rb` — idempotent webhook ledger (`.once(event_id)`); copy nearly verbatim.
- `app/models/publisher.rb` (search "subscri") — billable fields, `SUBSCRIBED_STATUSES`, `subscribed?`, `subscription_state`, `sync_stripe_subscription!` (note its handling of `current_period_end` moving into subscription items, and customer arriving expanded).
- `app/controllers/admin/organizations/subscriptions_controller.rb` — find-or-create customer, redirect to hosted Checkout in subscription mode, metadata riding on the subscription.
- `app/controllers/admin/organizations/subscriptions/returns_controller.rb` — sync on Checkout return (belt and suspenders vs. the webhook), including the `own_checkout?` guard against pasted foreign session ids.
- `app/controllers/admin/organizations/subscriptions/portals_controller.rb` — one-time Billing Portal URL.
- `app/controllers/public/payments/webhooks_controller.rb` — signature check, `customer.subscription.*` handling, resolution by customer id with metadata fallback.

Everything is Stripe-hosted (Checkout + Billing Portal). No Stripe.js, no
Elements, no publishable key needed in the UI. Gem: `gem "stripe", "~> 13.0"`.

## Decisions (already made, don't relitigate)

1. **~~Same Stripe account, new objects.~~ SUPERSEDED (2026-08-24): own
   Stripe account.** Checkout/portal/receipt branding is account-wide, and
   the shared account would say "ClaimStreet" at checkout. A separate
   account ("Newsletter Bingo", `acct_1U82HpBT3v7o43Nl`, same Stripe login)
   now owns the Product ("Newsletter Bingo") and $29/month Price. Sandbox price:
   `price_1U82LrBANx8kmkP1PLD2iccr`. Nothing is shared with
   local_deal_engine anymore — separate keys, webhook endpoint, branding.
2. **Customer per Account, Subscription per Publication.** One Stripe Customer
   on `Account` (one card covers all of an owner's newsletters); one Stripe
   Subscription per Publication with `metadata: { publication_id:, account_id: }`.
   Independent subscribe/cancel per newsletter, and the portal shows all of an
   account's subscriptions in one place.
3. **App-side free trial, no card required.** `trial_ends_at` set to 30 days at
   publication creation (one full game arc). Billing state is
   `trialing → subscribed / lapsed`. No Stripe involvement until checkout.
4. **Readers are never punished mid-game.** Gating acts at game-rotation time,
   not claim time: a lapsed publication's active game plays out to its natural
   end; `rotate_games` simply won't launch the successor. Claim links then hit
   the existing "There's no bingo game running right now" soft landing (already
   shipped). Admin pages show the subscribe prompt.
5. **`complimentary` boolean on Publication** (same idea as local_deal_engine's
   comp flag) so we can grant free service without fake Stripe objects.
6. **State lives in local columns synced from webhooks** — never call Stripe on
   a request path to answer "is this publication paid?".

## Step 1 — Migrations

- `accounts`: add `stripe_customer_id :string` (index).
- `publications`: add `stripe_subscription_id :string`,
  `subscription_status :string`, `subscription_current_period_end :datetime`,
  `trial_ends_at :datetime`, `complimentary :boolean, default: false, null: false`.
  Index `stripe_subscription_id`.
- New table `processed_webhook_events`: `event_id :string, null: false` +
  unique index (copy local_deal_engine's shape; UUID pk comes from this repo's
  generator config automatically).
- Backfill: existing publications get `trial_ends_at = 30.days.from_now`.
- Follow `.claude/rules/` and the migration-patterns skill (no FK constraints).

## Step 2 — Config + seam

- `config/initializers/stripe.rb` mirroring local_deal_engine's, minus Connect
  and per-publisher test mode (this app has no Connect and no demo publishers):
  keys `secret_key`, `webhook_secret`, `price_id`, plus the test-env dummy fill.
  ENV names: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
  `STRIPE_BINGO_PRICE_ID` (distinct name — the shared account means shared ENV
  namespaces on shared infra; don't collide with local_deal_engine's
  `STRIPE_SUBSCRIPTION_PRICE_ID`).
- `app/models/payments.rb`: trimmed copy of local_deal_engine's — `Payments.platform`,
  `MisconfiguredError`, `construct_webhook_event` (single + test secret list),
  `Gateway` with only: `create_customer`, `create_checkout_session`,
  `retrieve_checkout_session`, `retrieve_subscription`,
  `create_billing_portal_session`.

## Step 3 — Model layer (rich models, no services)

- `Publication::Billable` concern (new file `app/models/publication/billable.rb`,
  included from `Publication`):
  - `SUBSCRIBED_STATUSES = %w[ active trialing past_due ]` (past_due rides
    Stripe's retry window, matching local_deal_engine).
  - `subscribed?` — status in list.
  - `in_trial?` — `trial_ends_at&.future?` and never subscribed.
  - `billing_active?` — `complimentary? || subscribed? || in_trial?`.
  - `billing_state` — one of `:complimentary, :subscribed, :past_due, :trialing,
    :trial_expired, :canceled` for the UI.
  - `sync_stripe_subscription!(subscription)` — port from
    local_deal_engine's `Publisher#sync_stripe_subscription!` including the
    `current_period_end`-from-items and expanded-customer quirks; writes
    customer id up to `account`.
- `Account#ensure_stripe_customer!` — find-or-create, metadata `account_id`,
  email = a membership owner's user email.
- Gate: in `Publication#rotate_games`, guard `launch_on_deck_game` (and the
  first-game launch path in the admin controller) with `billing_active?`.
  Nothing else blocks — boards, claims on the running game, analytics all stay up.
- `ProcessedWebhookEvent` — copy from local_deal_engine with its comments.

## Step 4 — Controllers + routes (CRUD, one resource per state change)

Admin, inside the existing `scope "a/:account_id"` publications block:

- `resource :subscription, only: :create` →
  `Publications::SubscriptionsController#create`: ensure customer on the
  account, create Checkout session (`mode: "subscription"`, price from config,
  `subscription_data.metadata` carrying publication_id + account_id,
  success/cancel URLs back to the publication settings page). Port the
  local_deal_engine controller; scope through `Current.account`.
- `resource :return, only: :show` (module subscriptions) — sync-on-return with
  the `own_checkout?` guard (compare against the account's customer id).
- `resource :portal, only: :create` — Billing Portal session for the account's
  customer.

Public:

- `post "/webhooks/stripe" → Payments::WebhooksController#create` — port from
  local_deal_engine but handle ONLY `customer.subscription.created/updated/deleted`
  (subscription-mode checkouts are synced by these + the return page; there are
  no orders here). Resolve the publication by `stripe_subscription_id`, then by
  `metadata.publication_id`; wrap in `ProcessedWebhookEvent.once`. Exempt this
  path from any rate limiting. `skip_forgery_protection` with the
  signature-check comment.

## Step 5 — UI

- `publications/edit.html.erb`: new "Billing" card — current `billing_state`
  with plain-language copy (trial days left / next renewal date / lapsed),
  Subscribe button (button_to the subscription resource) or "Manage billing"
  (portal). Match the page's existing card/hint styles.
- `publications/index.html.erb` (account home): small badge per publication for
  trial/lapsed states only.
- Trial-expired nudge on the Today page: if `!billing_active?` and no launchable
  successor, an `.attention` banner ("Your next game won't start — subscribe to
  keep the streak going") linking to settings#billing.

## Step 6 — Tests (Minitest + fixtures; no live Stripe calls)

- Stub the seam, not the internet: tests stub `Payments.platform` with a
  simple fake gateway (look at how local_deal_engine's suite stubs `Payments`
  for the pattern) and build webhook payloads as plain hashes passed through a
  stubbed `construct_webhook_event`.
- Cover: trial-active publication launches games; trial-expired one completes
  its running game but launches nothing (readers get the existing soft-landing
  notice); subscription webhook flips status and unblocks rotation on the next
  request; `deleted` webhook downgrades; `past_due` still counts as subscribed;
  webhook idempotency (same event id twice = one state change); cross-account
  isolation (webhook for pub A never touches pub B; return controller rejects
  a foreign session id); complimentary bypasses everything.
- Fixture updates: publications gain `trial_ends_at` (ERB `30.days.from_now`)
  so every existing test keeps passing without thinking about billing.

## Step 7 — Stripe dashboard + deploy checklist (manual, same account as local_deal_engine)

1. In the shared Stripe account: create Product "Newsletter Bingo", Price $29/month
   recurring (and a $39 price too if A/B pricing is wanted later — the config
   holds one id).
2. Add webhook endpoint `https://<daily-bingo-host>/webhooks/stripe` with events
   `customer.subscription.created`, `customer.subscription.updated`,
   `customer.subscription.deleted`. Copy its signing secret.
3. Enable the customer Billing Portal in Stripe settings if not already on
   (local_deal_engine already uses it — likely done).
4. Set ENV on the daily_bingo deploy: `STRIPE_SECRET_KEY` (same value as
   local_deal_engine), `STRIPE_WEBHOOK_SECRET` (new, from step 2),
   `STRIPE_BINGO_PRICE_ID` (from step 1).
5. Repeat 1–2 in Stripe **test mode** for local dev; `stripe listen --forward-to
   localhost:3000/webhooks/stripe` for local webhook testing.

## Order of execution

Migrations → initializer + Payments seam → Billable concern + gating →
webhooks controller → subscription/return/portal controllers + routes → UI →
tests throughout → `bin/ci` green → dashboard/env checklist → manual test-mode
end-to-end (subscribe, cancel via portal, lapse, resubscribe).

## Out of scope (deliberately)

- Metered/participant-based pricing, coupons, multiple tiers.
- Dunning emails (Stripe's own emails + past_due grace cover v1).
- Proration when a publication is deleted mid-cycle (portal cancel handles it).
- Any reader-facing billing surface. Readers never see billing.
