# Seeds are safe to run repeatedly. The system word library is always
# topped up; the demo publisher is only created in development.

system_words = Rails.root.join("db/seeds/system_words.txt").readlines
  .map(&:strip).reject { |line| line.blank? || line.start_with?("#") }

existing = Word.system.pluck(:label).map(&:downcase).to_set
system_words.each do |label|
  Word.system.create!(label: label) unless existing.include?(label.downcase)
end
puts "System word library: #{Word.system.count} words"

return unless Rails.env.development?
return if Publication.exists?(name: "Omaha Daily")

puts "Creating demo publisher…"

user = User.create!(email_address: "demo@example.com", password: "password", password_confirmation: "password")
account = Account.create!(name: "Demo Publisher")
Membership.create!(account: account, user: user, role: "owner")

publication = account.publications.create!(
  name: "Omaha Daily",
  timezone: "America/Chicago",
  primary_color: "#B3402A",
  accent_color: "#D97706",
  background_color: "#FDF6EC",
  text_color: "#2A2118",
  email_merge_tag: "{{ subscriber.email }}"
)

%w[ AKSARBEN DUNDEE HUSKERS OMAHA\ ZOO FARMERS\ MARKET MEMORIAL\ PARK TACO\ RIDE OLD\ MARKET ].each do |label|
  publication.words.create!(label: label)
end

# The standing "Brought to you by" line and prize pair — always on,
# whatever game is running.
publication.update!(sponsor_name: "Dundee Coffee")
publication.line_prize.update!(enabled: true, name: "$25 Dundee Coffee Gift Card",
  description: "A little fuel for your daily routine.",
  instructions: "We'll email the gift card within 24 hours.",
  link_url: "https://example.com/dundee-coffee", link_text: "About Dundee Coffee")
publication.blackout_prize.update!(enabled: true, name: "$250 Midtown Market Shopping Spree",
  description: "The grand prize for perfect daily participation.",
  instructions: "We'll contact you to arrange your spree.",
  link_url: "https://example.com/midtown-market", link_text: "About Midtown Market")

# Active game, currently on Day 9 of 30.
today = publication.local_date
starts_on = today - 8

GAME_WORDS = [
  "COFFEE", "UMBRELLA", "PIZZA", "DUNDEE", "BASEBALL", "BRIDGE", "PARK", "OMAHA ZOO",
  "FARMERS MARKET", "CAMERA", "POPCORN", "GARDEN", "AKSARBEN", "BICYCLE", "SUNSHINE",
  "LIBRARY", "DONUT", "RIVER", "MOVIE", "PICNIC", "BACKPACK", "COOKIE", "FLOWER", "TRAIN",
  "SUNRISE", "LEMONADE", "GUITAR", "CAMPFIRE", "WAFFLE", "FIREWORKS"
]

game = publication.games.create!(starts_on: starts_on, ends_on: starts_on + GAME_WORDS.size - 1, status: "active")
game_words = GAME_WORDS.each_with_index.map do |label, index|
  word = publication.eligible_words.find_by!("lower(label) = ?", label.downcase)
  game.game_words.create!(word: word, label: word.label, position: index + 1)
end

# Issue cadence: nine sends have gone out so far, one word per issue, so
# FARMERS MARKET (index 8) is the current word. The rest wait undated.
game_words.each_with_index do |game_word, index|
  issued_on = index <= 8 ? starts_on + index : nil
  call = game.daily_calls.create!(game_word: game_word, position: index + 1, call_on: issued_on)
  next unless issued_on
  # Backdated past the issue-interval floor so a fresh test send can
  # advance the game right away.
  sent_at = [ issued_on.in_time_zone(publication.tz).change(hour: 8), 13.hours.ago ].min
  game.issues.create!(token: "campaign-#{format('%03d', index + 1)}", daily_call: call,
    called_on: issued_on, created_at: sent_at)
end

# Yesterday carried rich content; today is a prize call.
game.call_for(today - 1).update!(
  description: "Free refill day at Dundee Coffee — mention the newsletter.",
  link_url: "https://example.com/dundee-coffee", link_text: "See the menu")
game.call_for(today).update!(
  prize_call: true,
  prize_description: "First 50 claims get a free basic wash.",
  description: "Explore local vendors, food and live music at this week's farmers market.",
  link_url: "https://example.com/farmers-market", link_text: "See market details"
)

# The on-deck draft that will launch automatically when this game ends.
publication.rotate_games

# --- Demo participants -----------------------------------------------------

def seed_claims(game, participant, days)
  board = participant.board_for(game)
  days.each do |day_index|
    call = game.daily_calls.find_by!(call_on: game.starts_on + day_index)
    claimed_at = (game.starts_on + day_index).in_time_zone(game.publication.tz).change(hour: 8)
    DailyClaim.create!(participant: participant, daily_call: call, game: game, claimed_at: claimed_at)
    # Cards hold a subset of the pool, so some called words miss this board.
    board.square_for(call.game_word)&.update!(claimed_at: claimed_at)
  end
  board.refresh_achievements
  board
end

called_days = (0..8).to_a # Days 1–9 (today included)

# Alice: perfect participation so far.
alice = Participant.locate_or_register(publication, "alice@example.com")
seed_claims(game, alice, called_days)

# Bob: missed Day 5 — that square stays blank forever.
bob = Participant.locate_or_register(publication, "bob@example.com")
seed_claims(game, bob, called_days - [ 4 ])

# Carol: casual player, three missed days.
carol = Participant.locate_or_register(publication, "carol@example.com")
seed_claims(game, carol, called_days - [ 1, 4, 6 ])

# Dave: board arranged so the 9 called words nearly fill row 2 + center —
# he already has a bingo (and a line prize award).
dave = Participant.locate_or_register(publication, "dave@example.com")
dave_board = dave.board_for(game)
called_words = game.daily_calls.where(call_on: ..today).map(&:game_word)
row = [ 10, 11, 13, 14 ] # row 2 minus the FREE center
row.each_with_index do |position, index|
  dave_board.reload
  target = dave_board.square_at(position)
  source = dave_board.square_for(called_words[index])
  next if source == target
  ActiveRecord::Base.transaction do
    if source
      source_word, target_word = source.game_word, target.game_word
      source_position = source.position
      source.destroy!
      target.update!(game_word: source_word)
      BingoSquare.create!(bingo_board: dave_board, position: source_position, game_word: target_word)
    else
      # The called word wasn't dealt to Dave's card; deal it into place.
      target.update!(game_word: called_words[index])
    end
  end
end
seed_claims(game, dave, called_days)

puts "Demo publisher ready:"
puts "  Sign in:   demo@example.com / password"
puts "  Claim URL: #{NewsletterBlock.new(publication).claim_url("alice@example.com")}"
