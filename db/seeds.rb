# Seeds are safe to run repeatedly. The system word library is always
# topped up; the demo publisher is only created in development.

SYSTEM_WORDS = %w[
  ACORN AIRPLANE ANCHOR APPLE AQUARIUM AVOCADO BACKPACK BAKERY BALLOON BANJO
  BARN BASEBALL BASKET BEACH BICYCLE BIRDHOUSE BLANKET BLUEBERRY BONFIRE BOOK
  BOOTS BRIDGE BUTTERFLY CABIN CAMERA CAMPFIRE CANDLE CANOE CARDINAL CARNIVAL
  CAROUSEL CHERRY CHIMNEY CINNAMON COFFEE COMPASS COOKIE CUPCAKE DAISY DONUT
  DRAGONFLY DRUM EAGLE ENVELOPE FEATHER FIREFLY FIREWORKS FLASHLIGHT FLOWER
  FOUNTAIN FOX GARDEN GAZEBO GLACIER GUITAR HAMMOCK HARBOR HAYRIDE HEDGEHOG
  HONEY HOTCAKE ICEBERG JACKET JIGSAW JUKEBOX KAYAK KETTLE KITE LADDER LANTERN
  LEMONADE LIBRARY LIGHTHOUSE LILAC MAILBOX MAPLE MARIGOLD MEADOW MITTENS MOON
  MOUNTAIN MOVIE MUFFIN MUSHROOM NEST NOODLE OATMEAL ORCHARD OTTER OWL PADDLE
  PANCAKE PARK PEACH PELICAN PENGUIN PEPPER PIANO PICNIC PIER PILLOW PINECONE
  PIZZA POPCORN PORCH POSTCARD PRETZEL PUDDLE PUMPKIN QUILT RACCOON RAINBOW
  RASPBERRY RIVER ROCKET ROOSTER ROSE SAILBOAT SANDCASTLE SANDWICH SCARF
  SEASHELL SKATES SLED SNOWFLAKE SPARROW SPROUT STARGAZE STRAWBERRY SUNDIAL
  SUNFLOWER SUNRISE SUNSHINE SWEATER SWING TEAPOT TELESCOPE TENT THEATER
  TOBOGGAN TOMATO TRAIN TREEHOUSE TROLLEY TRUMPET TULIP TURTLE UKULELE UMBRELLA
  VIOLIN WAFFLE WAGON WATERFALL WHISTLE WILDFLOWER WINDMILL WINDOW YARN ZUCCHINI
]

SYSTEM_WORDS.each do |label|
  Word.system.create_with(label: label).find_or_create_by!(label: label)
end
puts "System word library: #{Word.system.count} words"

return unless Rails.env.development?
return if Publication.exists?(slug: "omaha-daily")

puts "Creating demo publisher…"

user = User.create!(email_address: "demo@example.com", password: "password", password_confirmation: "password")
account = Account.create!(name: "Demo Publisher")
Membership.create!(account: account, user: user, role: "owner")

publication = account.publications.create!(
  name: "Omaha Daily",
  slug: "omaha-daily",
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

car_wash = publication.sponsors.create!(name: "Omaha Car Wash", website_url: "https://example.com/carwash",
  description: "Hand wash and detail in Midtown.")
dundee_coffee = publication.sponsors.create!(name: "Dundee Coffee", website_url: "https://example.com/dundee-coffee",
  description: "Neighborhood roastery.")
midtown_market = publication.sponsors.create!(name: "Midtown Market", website_url: "https://example.com/midtown-market",
  description: "Local grocers since 1952.")

# Active game, currently on Day 9 of 24.
today = publication.local_date
starts_on = today - 8

GAME_WORDS = [
  "COFFEE", "UMBRELLA", "PIZZA", "DUNDEE", "BASEBALL", "BRIDGE", "PARK", "OMAHA ZOO",
  "FARMERS MARKET", "CAMERA", "POPCORN", "GARDEN", "AKSARBEN", "BICYCLE", "SUNSHINE",
  "LIBRARY", "DONUT", "RIVER", "MOVIE", "PICNIC", "BACKPACK", "COOKIE", "FLOWER", "TRAIN"
]

game = publication.games.create!(name: "Summer Omaha Bingo", starts_on: starts_on, status: "active")
game_words = GAME_WORDS.map do |label|
  word = publication.eligible_words.find_by!("lower(label) = ?", label.downcase)
  game.game_words.create!(word: word, label: word.label)
end

# Fixed schedule so FARMERS MARKET (index 8) lands on today (Day 9).
game_words.each_with_index do |game_word, index|
  game.daily_calls.create!(game_word: game_word, call_on: starts_on + index)
end

# Yesterday was sponsored; today is a sponsored prize call with rich content.
game.call_for(today - 1).update!(sponsor: dundee_coffee,
  description: "Free refill day at Dundee Coffee — mention the newsletter.",
  link_url: "https://example.com/dundee-coffee", link_text: "See the menu")
game.call_for(today).update!(
  sponsor: car_wash,
  prize_call: true,
  prize_description: "First 50 claims get a free basic wash.",
  description: "Explore local vendors, food and live music at this week's farmers market.",
  link_url: "https://example.com/farmers-market", link_text: "See market details"
)

game.prizes.create!(kind: "line", enabled: true, name: "$25 Dundee Coffee Gift Card",
  description: "A little fuel for your daily routine.", sponsor: dundee_coffee,
  instructions: "We'll email the gift card within 24 hours.",
  link_url: "https://example.com/dundee-coffee", link_text: "About Dundee Coffee")
game.prizes.create!(kind: "blackout", enabled: true, name: "$250 Midtown Market Shopping Spree",
  description: "The grand prize for perfect daily participation.", sponsor: midtown_market,
  instructions: "We'll contact you to arrange your spree.",
  link_url: "https://example.com/midtown-market", link_text: "About Midtown Market")

# --- Demo participants -----------------------------------------------------

def seed_claims(game, participant, days)
  board = participant.board_for(game)
  days.each do |day_index|
    call = game.daily_calls.find_by!(call_on: game.starts_on + day_index)
    claimed_at = (game.starts_on + day_index).in_time_zone(game.publication.tz).change(hour: 8)
    DailyClaim.create!(participant: participant, daily_call: call, game: game, claimed_at: claimed_at)
    square = board.square_for(call.game_word)
    square.update!(claimed_at: claimed_at)
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
    source_word, target_word = source.game_word, target.game_word
    source_position = source.position
    source.destroy!
    target.update!(game_word: source_word)
    BingoSquare.create!(bingo_board: dave_board, position: source_position, game_word: target_word)
  end
end
seed_claims(game, dave, called_days)

puts "Demo publisher ready:"
puts "  Sign in:   demo@example.com / password"
puts "  Claim URL: #{NewsletterBlock.new(publication).claim_url("alice@example.com")}"
