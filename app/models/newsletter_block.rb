# Builds the email-safe HTML block a publication pastes into its email.
# Table-based, inline CSS, no JavaScript. The click itself is the claim.
# The ESP's merge tags are inserted verbatim into the claim URL and
# replaced by the email platform at send time.
#
# The block is styled as a native section of the newsletter, the way
# Morning Brew runs trivia and 1440 runs polls: a bold section header
# under the Newsletter Bingo mark, one sentence of body copy, the claim
# as a text link, and the sponsor as a small credit line. No box, so it
# reads like the editor wrote it.
#
# The HTML is evergreen: pasted once, it never names a word, because the
# first click of a new send is what draws the next one. Platforms that
# stamp a value per send (a campaign id, or beehiiv's send date) get that
# merge tag in the claim URL, so the freshly stamped token proves a click
# came from the current email and stale bookmarks can look but not claim.
# Platforms with neither (Kit, Ghost) get a link with no token: the send
# is proven by whatever campaign id the platform stamps into the link on
# its way out, and inferred from how long the publication has been quiet
# when it stamps nothing.
class NewsletterBlock
  include ERB::Util

  # The claim link is the one thing in the block that must never be hard
  # to see, so it wears the Newsletter Bingo amber rather than the
  # publication's accent. A publisher who picks a pale accent for their
  # board can't accidentally hide the link their whole game depends on.
  #
  # The dark amber, not the bright one: newsletters are overwhelmingly
  # white, where #f59e0b measures 2.15:1 and fails WCAG AA for text this
  # size. This clears it at 5.02:1 on white and still reads at 3.15:1 on
  # a dark background, which the bright amber wins but only there.
  CLAIM_LINK_COLOR = "#b45309"

  attr_reader :publication

  def initialize(publication)
    @publication = publication
  end

  def claim_url(email_value = publication.email_merge_tag)
    url = "#{NewsletterBingo.public_host}/c/#{publication.public_code}/today?email=#{email_value}"
    url += "&issue=#{publication.campaign_merge_tag}" if publication.campaign_tagged?
    url
  end

  def sponsor_name
    publication.sponsor_name
  end

  # Safe to render directly: every dynamic value below is escaped with +h+.
  def to_html
    build_html.html_safe
  end

  private
    def build_html
      section_html(evergreen_sentence)
    end

    def section_html(sentence)
      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:16px 0;">
          <tr>
            <td style="font-family:Helvetica,Arial,sans-serif;">
              #{header_html}
              #{sponsor_row}
              <div style="font-size:14px;line-height:1.6;color:#{h publication.text_color};">#{sentence}</div>
              <div style="font-size:14px;line-height:1.6;margin:6px 0 0;"><a href="#{h claim_url}" style="color:#{CLAIM_LINK_COLOR};font-weight:bold;text-decoration:none;white-space:nowrap;">Claim today&#8217;s word &#8594;</a></div>
            </td>
          </tr>
        </table>
      HTML
    end

    # The mark and the header sit in their own two cells rather than
    # riding the same text line. Editors like beehiiv style every image
    # in a pasted snippet as a block, which drops an inline mark onto a
    # line of its own; cells lay out side by side no matter what the
    # host stylesheet says about images.
    def header_html
      bottom_margin = sponsor_name.present? ? "2px" : "8px"
      %(<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 #{bottom_margin};"><tr>) +
        %(<td width="15" style="width:15px;padding:0 8px 0 0;vertical-align:middle;"><img src="#{h brand_icon_url}" alt="" width="15" height="15" border="0" style="display:block;width:15px;height:15px;"></td>) +
        %(<td style="vertical-align:middle;font-family:Helvetica,Arial,sans-serif;font-size:17px;font-weight:bold;color:#{h publication.text_color};">Today&#8217;s bingo</td>) +
        %(</tr></table>)
    end

    def evergreen_sentence
      "A new word has dropped. One click puts it on your board."
    end

    def brand_icon_url
      "#{NewsletterBingo.public_host}/icon-192x192.png"
    end

    def sponsor_row
      if sponsor_name.present?
        %(<div style="font-size:12px;color:#{h publication.text_color};opacity:0.55;margin:0 0 8px;">Sponsored by #{h sponsor_name}</div>)
      else
        ""
      end
    end
end
