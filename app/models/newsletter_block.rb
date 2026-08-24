# Builds the tiny email-safe HTML block a publication pastes into its
# email. Table-based, inline CSS, no JavaScript. The click itself is the
# claim. The ESP's merge tags are inserted verbatim into the claim URL and
# replaced by the email platform at send time.
#
# Both cadences get evergreen HTML, pasted once, and both carry the
# campaign-id merge tag: the freshly stamped token is what proves a click
# came from the current send, so stale bookmarks can look but not claim.
# Issue-cadence blocks carry no word (the first click of a new send
# advances the game). Calendar blocks show today's word through a
# dynamically served image (WordImage), so the HTML itself never changes.
class NewsletterBlock
  include ERB::Util

  attr_reader :publication

  def initialize(publication)
    @publication = publication
  end

  def claim_url(email_value = publication.email_merge_tag)
    "#{NewsletterBingo.public_host}/c/#{publication.public_code}/today?email=#{email_value}&issue=#{publication.campaign_merge_tag}"
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
      publication.issue_cadence? ? evergreen_html : daily_html
    end

    def daily_html
      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:16px 0;">
          <tr>
            <td align="center">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="280" style="width:280px;max-width:100%;background-color:#{h publication.background_color};border:1px solid #{h publication.primary_color}22;border-radius:12px;">
                <tr>
                  <td align="center" style="padding:16px 20px 14px;font-family:Helvetica,Arial,sans-serif;">
                    <div style="font-size:11px;font-weight:bold;letter-spacing:2px;color:#{h publication.primary_color};">TODAY&#8217;S BINGO</div>
                    #{sponsor_row}
                    <img src="#{h word_image_url}" alt="Today&#8217;s bingo word" width="240" height="44" border="0" style="display:block;margin:6px auto 8px;max-width:100%;">
                    <a href="#{h claim_url}" style="display:inline-block;background-color:#{h publication.accent_color};color:#ffffff;text-decoration:none;font-size:14px;font-weight:bold;padding:9px 18px;border-radius:8px;">Claim today&#8217;s spot &#8594;</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      HTML
    end

    def word_image_url
      "#{NewsletterBingo.public_host}/c/#{publication.public_code}/word.png"
    end

    def evergreen_html
      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:16px 0;">
          <tr>
            <td align="center">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="280" style="width:280px;max-width:100%;background-color:#{h publication.background_color};border:1px solid #{h publication.primary_color}22;border-radius:12px;">
                <tr>
                  <td align="center" style="padding:16px 20px 14px;font-family:Helvetica,Arial,sans-serif;">
                    <div style="font-size:11px;font-weight:bold;letter-spacing:2px;color:#{h publication.primary_color};">TODAY&#8217;S BINGO</div>
                    #{sponsor_row}
                    <div style="padding-top:12px;"><a href="#{h claim_url}" style="display:inline-block;background-color:#{h publication.accent_color};color:#ffffff;text-decoration:none;font-size:14px;font-weight:bold;padding:9px 18px;border-radius:8px;">Claim today&#8217;s spot &#8594;</a></div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      HTML
    end

    def sponsor_row
      if sponsor_name.present?
        %(<div style="font-size:11px;color:#{h publication.text_color};opacity:0.7;padding-top:4px;">Sponsored by #{h sponsor_name}</div>)
      else
        ""
      end
    end
end
