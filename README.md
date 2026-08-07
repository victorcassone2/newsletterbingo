# Daily Bingo

Daily Bingo is a multi-tenant SaaS for **publications** (email newsletters,
local media, community publishers). A publication pastes one tiny HTML block
near the bottom of its email:

```
TODAY'S BINGO 🎁
Sponsored by Omaha Car Wash

FARMERS MARKET

Claim today's spot →
```

Every day the reader sees one word and clicks one link. That click — with no
second "claim" button and no intermediate page — marks the day's square on the
reader's own persistent 5×5 bingo board. The destination page reveals optional
local content, sponsor messages, event links, and prizes. Missed days can never
be recovered, so a 24-day game culminating in a **Blackout** requires perfect
daily participation. The publication gets a recurring engagement habit and
sellable sponsorship inventory without giving up meaningful newsletter space.

## Stack

- Ruby 3.3 · Rails 8.1 · PostgreSQL 16
- Hotwire (Turbo + Stimulus), Importmap, Propshaft — server-rendered, no SPA
- Rails 8 built-in authentication (publishers only; readers never sign up)
- Solid Queue / Solid Cache / Solid Cable
- Minitest + fixtures, Brakeman, bundler-audit, RuboCop (rails-omakase)
- UUID primary keys everywhere; Active Storage for logos and prize images

Conventions follow the 37signals pack in `.claude/` (from
[rails_ai_agents](https://github.com/ThibautBaissac/rails_ai_agents)): rich
domain models, focused concerns, thin REST controllers, no service layer.
See `docs/architecture.md` for the domain map and key decisions.

## Getting started

### Requirements

- Ruby 3.3+ (this machine: Homebrew Ruby at `/usr/local/opt/ruby/bin`; rvm's
  older Ruby shadows it, so prefix commands with
  `unset GEM_HOME GEM_PATH; export PATH=/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/3.3.0/bin:$PATH`)
- Docker (for the project's PostgreSQL) — or any PostgreSQL 14+ you point
  `PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD` at

### PostgreSQL

Development and test use a dedicated container on port **5434**:

```bash
docker run -d --name daily_bingo_postgres \
  -e POSTGRES_USER=daily_bingo -e POSTGRES_PASSWORD=daily_bingo \
  -p 5434:5432 --restart unless-stopped postgres:16
```

### Setup and run

```bash
bundle install
bin/rails db:setup          # create, load schema, seed
bin/dev                     # http://localhost:3000
```

Seeds create the system word library (~160 safe, visual words) plus, in
development, a demo publisher:

- Sign in: `demo@example.com` / `password`
- Publication **Omaha Daily**, mid-game (Day 9 of 24), sponsors, prizes, and
  participants in interesting states (perfect attendance, missed days, an
  existing bingo winner)
- A ready-to-click claim URL is printed at the end of seeding

### Tests and checks

```bash
bin/rails test              # full Minitest suite
bin/ci                      # rubocop + brakeman + bundler-audit + tests
```

## Domain model

| Concept | Meaning |
|---|---|
| **Account / Membership / User** | Publishers sign in; a user can belong to several accounts (roles: owner, member) |
| **Publication** | A customer property: branding, timezone, merge tag, secure `pub_…` public code |
| **Word** | Reusable library entry — system-wide (`publication_id IS NULL`) or publication-owned |
| **Game** | Exactly 24 local calendar days (`ends_on = starts_on + 23`), exactly 24 unique words; one open game per publication (partial unique index) |
| **GameWord** | The 24 chosen words with **snapshotted labels** — later library edits never rewrite history |
| **DailyCall** | The one word called on a given date, plus optional description, link, sponsor, and prize-call flag |
| **Participant** | A reader: publication + normalized email, addressed publicly only by an unguessable token |
| **BingoBoard / BingoSquare** | The participant's permanent randomized arrangement; FREE center enforced by check constraint |
| **DailyClaim** | Idempotent proof a participant claimed a call (unique per participant + call) |
| **Prize / PrizeAward** | Optional line and blackout prizes per game; awards unique per participant + game + kind |

### Game lifecycle

1. **Draft** — publisher names the game and picks Day 1. 24 words are chosen
   automatically (publication words first, topped up from the system library);
   they can be shuffled or individually replaced before launch.
2. **Launch** — the 24 DailyCalls are created up front, one per date, words in
   random order. `game+date` and `game+word` are unique in the database.
   Future calls can swap words (atomic via a deferred unique constraint) or
   substitute an unused library word; called or claimed days are locked.
3. **Active** — one call per day. The publisher's Today dashboard is built for
   sub-minute daily adjustments: description, destination link, sponsor,
   prize-call flag, copy newsletter HTML.
4. **Completed** — after Day 24 the game closes lazily; boards, claims, calls,
   and awards are preserved forever. A new game starts fresh: new words, new
   board layouts (created lazily on each reader's first claim), same
   participant identity.

### Boards and bingo

Positions 0–24 (row-major); position 12 is FREE. All players share the game's
24 words but each board is shuffled with `SecureRandom` at first claim and
persisted — refreshes and returns never reshuffle. Lines are the 5 rows,
5 columns, and 2 diagonals; FREE always counts. Bingo and blackout are
detected on every claim; achievements live on the board
(`bingo_achieved_at` / `blackout_achieved_at`) and prize awards are created
only when an enabled prize exists — at most one line and one blackout award
per participant per game, enforced by unique indexes.

## Newsletter integration

Each publication's **Embed** screen (and the Today dashboard) generates a
compact, email-safe HTML block: tables + inline CSS, no JavaScript, no
iframes. The block shows the eyebrow, optional "Sponsored by …", optional 🎁
prize-call icon, today's word, and the claim button. The call's description
and destination link are deliberately **not** in the email — they're the
reward for clicking.

### Subscriber email merge tags

Every email platform writes the subscriber's address differently, so the
merge tag is a plain per-publication setting inserted verbatim into the claim
URL:

```
https://your-host/c/pub_7Kw93X…/today?email={{ subscriber.email }}
```

`{{email}}`, `|EMAIL|`, `{{contact.email}}` — whatever the ESP uses. The ESP
substitutes the real address at send time; this app never does.

Set the externally reachable origin with `APP_HOST`
(e.g. `APP_HOST=https://bingo.example.com`).

### The claim endpoint

`GET /c/:public_code/today?email=…` — one request does everything:

identify publication → validate + normalize email → find/create participant →
find the active game → verify today is one of its 24 local dates → find
today's call → find/create the board → create the claim idempotently → mark
the square → evaluate bingo and blackout → create awards if earned →
set a signed participant cookie → **redirect to a clean URL**
(`/p/:public_code/board`) that never contains the email.

Every failure mode (missing/malformed email, unreplaced merge tag, unknown
code, inactive publication, no game, game not started or finished, no call
today) renders a friendly branded page — never a Rails error.

### A note on reader identity

The merge-tag link is **not strong authentication** — it identifies the
participant for a low-sensitivity bingo game, nothing more. Accordingly: the
raw-email URL is immediately redirected away; reader pages carry
`Referrer-Policy: no-referrer` and `noindex`; participants are addressed only
by signed cookies over unguessable tokens; there is no participant directory
and no data beyond game state on the page. A signed ESP integration (e.g.
HMAC-signed links) can be layered on later without changing the model.

## White labeling

Publications configure name, logo, primary/accent/background/text colors.
The Branding screen live-previews both the newsletter block and the board.
Colors flow through CSS custom properties (`--brand-*`) across the entire
reader experience — page, buttons, board, claimed squares, prize and sponsor
treatments — with button text color chosen for contrast automatically. The
reader page carries only a subtle "Powered by Daily Bingo" footer (built to
become removable on higher plans).

## Sponsors

Sponsors belong to a publication and can be attached independently to daily
calls, line prizes, and blackout prizes — three separate sellable slots. The
Sponsors screen tracks usage; Analytics rolls up claims and link clicks per
sponsor. Outbound links go through an internal click-tracking redirect that
only ever forwards to persisted, `http(s)`-validated URLs (open-redirect
safe), and only for participants who actually earned that content.

## Multi-tenancy and security

- Admin URLs are scoped `/a/:account_id/…`; `Current.account` is set from the
  URL only after verifying the signed-in user's membership, and every admin
  query flows through `Current.account` associations. No default scopes.
- UUIDs everywhere; publications are addressed publicly by cryptographically
  random `pub_…` codes; participants by 36+ character random tokens.
- Concurrency-sensitive invariants (participant, board, claim, award
  uniqueness; one open game; one call per date; one use per word; unique
  square positions; the FREE center) are all **database constraints**, with
  `create_or_find_by!` race-retries on top. Two simultaneous clicks converge
  on one row — covered by real multi-threaded tests.
- Publisher-entered URLs are validated to `http(s)` only; all reader-visible
  text is escaped; game-day eligibility is enforced server-side in the
  publication's timezone (a 12:05 AM click cannot claim yesterday).

## Timezones

All game-day math uses the publication's timezone via `Publication#local_date`,
`Game#day_number`, and `DailyCall#claimable_now?` — the server clock and
server timezone are irrelevant to eligibility.

## Project layout notes

- `app/models` — the entire domain; no services, no policies, no queries dirs
- `app/models/newsletter_block.rb` — the email-safe HTML generator (PORO)
- `app/models/publication/analytics.rb` — lightweight reporting queries
- `app/controllers/public_controller.rb` — base for all reader-facing pages
- `docs/architecture.md` — entity map and the reasoning behind key decisions
- `.claude/` — 37signals-style Claude Code conventions (rules, skills, agents)
