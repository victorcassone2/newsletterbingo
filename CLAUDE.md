# Daily Bingo — 37signals Rails Conventions

Daily Bingo is a multi-tenant SaaS that lets a Publication (an email publication)
embed a tiny "TODAY'S BINGO" block in its emails. Each reader click claims that
day's square on their own persistent 5×5 bingo board for the current 24-day Game.

## Tech Stack

- **Ruby** 3.3.4 (Homebrew, `/usr/local/opt/ruby/bin`), **Rails** 8.1, **PostgreSQL 16**
  (Docker container `daily_bingo_postgres`, port **5434**, user/password `daily_bingo`)
- **Frontend:** Hotwire (Turbo + Stimulus), Importmap, Propshaft — no Node.js, no SPA
- **Testing:** Minitest + fixtures (not RSpec, not FactoryBot)
- **Auth:** Rails 8 built-in authentication generator (sessions, `has_secure_password`)
- **Jobs/Cache/Cable:** Solid Queue / Solid Cache / Solid Cable
- **IDs:** UUID primary keys everywhere (see `config/initializers/generators.rb`)

Ruby environment note: rvm's old Ruby 3.0 shadows the Homebrew Ruby. Run commands as:
`unset GEM_HOME GEM_PATH; export PATH=/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/3.3.0/bin:$PATH`

## Architecture

```
app/
  controllers/     # Thin. Only 7 REST actions. New resource for each state change.
  models/          # Rich. Business logic, concerns, associations, validations.
  models/concerns/ # Horizontal behavior.
  views/           # ERB + Turbo Frames/Streams. No JS frameworks.
  jobs/            # Shallow. Call model methods, don't contain logic.
```

**No `app/services/`, `app/queries/`, `app/policies/`, `app/forms/`.** Business logic
lives in models. Authorization via memberships + controller concerns.

## Core Philosophy

- **Vanilla Rails:** rich domain models, thin controllers, no service-object sprawl
- **Everything is CRUD:** state changes = new resources
- **Concerns for organization:** focused, horizontal behavior
- **Multi-tenancy:** `Current.account` set from URL/session; explicit scoping, **no default scopes**
- **Current for context:** `Current.user`, `Current.account`, `Current.session`
- **DB constraints back every concurrency-sensitive uniqueness rule**

## Domain glossary

- **Publication** (never "newsletter"): a customer property; belongs to an Account
- **Game**: exactly 24 local calendar days, exactly 24 unique words
- **DailyCall**: the one word called on a given game day
- **Participant**: a reader, identified by normalized email within a Publication
- **BingoBoard / BingoSquare**: a participant's stable randomized 5×5 arrangement
- **DailyClaim**: idempotent record that a participant claimed a DailyCall
- **PrizeAward**: persisted line/blackout award (unique per participant+game+kind)

All game-day math uses the **Publication's timezone**, never the server's.

## Key Commands

```bash
bin/setup                  # Initial setup
bin/dev                    # Start dev server
bin/rails test             # Full test suite
bin/ci                     # rubocop + brakeman + tests
bundle exec rubocop -a     # Auto-fix Ruby style
bin/rails db:migrate
```

## Style Guide (37signals)

- Expanded conditionals over guard clauses (exception: single-line early returns at method start)
- Method ordering: class methods > public instance (`initialize` first) > private
- Order private methods by invocation flow
- Bang methods (`!`) only when a non-bang counterpart exists
- No newline under `private`; indent content under it
- `belongs_to :creator, default: -> { Current.user }` for context defaults

See `.claude/rules/` for path-scoped conventions and `.claude/skills/` for patterns.
