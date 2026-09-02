# The email platforms we know how to fill in for. Each one answers the
# only question Setup asks: which merge tags does this platform replace,
# and does it stamp anything that changes with every send?
#
# Publishers should never have to transcribe tag syntax from their
# platform's docs, so picking a platform is the whole answer and the tags
# are a disclosure for the curious and for everyone else.
class Platform
  attr_reader :name, :email_merge_tag, :campaign_merge_tag, :hint, :paste_steps, :caveat

  # Where the block goes when a platform has nowhere to paste HTML that
  # repeats, so the publisher isn't left pasting it into every issue.
  GENERIC_PASTE_STEPS = [
    "Paste it into your email template rather than a single issue, so every send carries it.",
    "If your platform has no template, paste it into each issue, or use the plain link below."
  ].freeze

  def self.all
    ALL
  end

  # The platform a publication's saved tags came from, or nil for tags
  # somebody typed themselves.
  def self.for(publication)
    ALL.find { |platform| platform.matches?(publication) }
  end

  def initialize(name:, email_merge_tag:, campaign_merge_tag:, hint:, paste_steps:, caveat: nil, link_first: false)
    @name = name
    @email_merge_tag = email_merge_tag
    @campaign_merge_tag = campaign_merge_tag
    @hint = hint
    @paste_steps = paste_steps
    @caveat = caveat
    @link_first = link_first
  end

  # Platforms whose set-and-forget spot takes a link but not HTML, so the
  # plain link is the route rather than the consolation.
  def link_first?
    @link_first
  end

  ALL = [
    {
      name: "beehiiv",
      email_merge_tag: "{{email}}",
      campaign_merge_tag: "{{current_date_ymd}}",
      hint: "beehiiv has no campaign-id tag, so we use its send-date tag: the first click of the day draws that day's word.",
      paste_steps: [
        "Open a post template, not a single post.",
        "Type / and choose HTML Snippet, then paste.",
        "Every post built from that template carries it."
      ],
      caveat: "HTML Snippet is a paid beehiiv feature. On the free plan, use the plain link below instead."
    },
    {
      name: "Mailchimp",
      email_merge_tag: "*|URL:EMAIL|*",
      campaign_merge_tag: "*|CAMPAIGN_UID|*",
      hint: "Mailchimp stamps a campaign id on every send. The URL: prefix encodes the address safely inside the link.",
      paste_steps: [
        "Edit your saved template, not a single campaign.",
        "Drag in a Code block and paste.",
        "Every campaign built from that template carries it."
      ]
    },
    {
      name: "Kit",
      email_merge_tag: "{{subscriber.email_address|url_encode}}",
      campaign_merge_tag: "",
      hint: "Kit has no per-send merge tag. Switch on its automatic UTM parameters and every broadcast proves itself; leave them off and sends are detected automatically.",
      paste_steps: [
        "Open Email Templates and create an HTML template, or edit the one you send with.",
        "Paste the block in below {{ message_content }}, above the footer.",
        "Every broadcast on that template carries it, with nothing to do per issue."
      ],
      caveat: "Rather not move to an HTML template? Add an HTML block to one broadcast and save it as a content snippet, then drop that snippet into each issue."
    },
    {
      name: "Ghost",
      email_merge_tag: "%%{email}%%",
      campaign_merge_tag: "",
      hint: "Ghost replaces %%{email}%% anywhere in the email, including an HTML card, and has no per-send tag, so sends are detected automatically.",
      paste_steps: [
        "Open Settings, then your newsletter, and edit the footer content.",
        "Write a line there and link it to the address under the plain link below.",
        "It rides in the footer of every issue, with nothing to do per send."
      ],
      caveat: "Ghost's footer takes text and links but not HTML, so this trades the header and the sponsor line for never touching it again. For the full block: paste it into a post as an HTML card, save that card as a snippet called bingo, and type /bingo each issue.",
      link_first: true
    }
  ].map { |attributes| new(**attributes) }.freeze

  def matches?(publication)
    email_merge_tag == publication.email_merge_tag.to_s &&
      campaign_merge_tag == publication.campaign_merge_tag.to_s
  end
end
