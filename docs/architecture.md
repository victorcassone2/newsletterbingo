# Newsletter Bingo — Domain Architecture

## Product loop

A Publication pastes one tiny email-safe HTML block into its email. Every day the
reader sees one word and clicks one link. That click idempotently claims the day's
square on the reader's own persistent 5×5 board. Missed days are gone forever, so a
24-day Game culminating in Blackout requires perfect daily participation.

## Entity map

```
User ──< Membership >── Account ──< Publication
                                        │
        ┌───────────────┬───────────────┼──────────────┬────────────┐
        │               │               │              │            │
      Word          Sponsor          Game ──< Prize (line|blackout) │
   (system rows                       │                        Participant
    have nil       ┌──────────────────┤                             │
    publication)   │                  │                             │
               GameWord ──── DailyCall│(one per game day)           │
                  │                   │                             │
             BingoSquare >── BingoBoard ────────────────────────────┤
                                      │                             │
                                 DailyClaim (participant × call)────┤
                                 PrizeAward (participant × game × kind)
```

## Key decisions

- **Calls are created up front.** Launching a Game creates its 24 `DailyCall` rows
  (one per local calendar date, words in random order). This gives the strongest
  integrity: `game+date` and `game+game_word` are unique in the database, and
  "change today's word" is a swap between two uncalled calls (deferred unique
  constraint makes the swap atomic).
- **Labels are snapshotted.** `GameWord#label` copies the Word's label at selection
  time; boards and history never change when a reusable Word is edited or archived.
- **Squares store `claimed_at` only.** A claimed square's content (description,
  link, sponsor, prize flag) comes from its GameWord's DailyCall, so history is a
  single source of truth.
- **Bingo/blackout state lives on the board** (`bingo_achieved_at`,
  `blackout_achieved_at`) so analytics can count winners even when prizes are
  disabled. `PrizeAward` rows exist only when an enabled Prize is won, and are
  unique per participant + game + kind.
- **All date math is Publication-local.** `Publication#local_date` /
  `Game#current_day` / `DailyCall#claimable_now?` use the publication's timezone;
  the server timezone is irrelevant.
- **Readers have no accounts.** A `Participant` is `publication + normalized email`,
  addressed publicly only by an unguessable `public_token`. After the claim GET, we
  set a signed cookie and redirect to a clean URL that never contains the email.
- **Tenancy is explicit.** Admin URLs are scoped `/a/:account_id/...`;
  `Current.account` is set from the URL after verifying membership; every admin
  query goes through `Current.account` associations. No default scopes.
- **Concurrency is settled in the database.** Participant, board, claim, and award
  creation all race-retry on `ActiveRecord::RecordNotUnique` backed by unique
  indexes; two simultaneous clicks converge on one row.

## Public routes

- `GET /c/:public_code/today?email=<merge tag>` — the newsletter claim link.
  Performs the claim, sets the signed participant cookie, redirects to the board.
- `GET /p/:public_code/board` — the clean board URL (participant from cookie).
- `GET /p/:public_code/out/call/:id`, `GET /p/:public_code/out/prize/:id` —
  click-tracking redirects to persisted, validated URLs only.

## Board geometry

Positions 0–24, row-major. Center (12) is FREE (`game_word_id IS NULL`, enforced by
check constraint). Lines: 5 rows, 5 columns, 2 diagonals; FREE always counts.
