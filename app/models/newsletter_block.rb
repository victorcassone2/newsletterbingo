# Builds the tiny email-safe HTML block a publication pastes into its
# email. Table-based, inline CSS, no JavaScript — the click itself is the
# claim. The ESP's merge tags are inserted verbatim into the claim URL and
# replaced by the email platform at send time.
#
# Issue-cadence publications get an evergreen block (no word baked in) that
# lives in a reusable template: the campaign-id merge tag stamps each send,
# and the first click of a new send advances the game to its next word.
class NewsletterBlock
  include ERB::Util

  attr_reader :publication, :daily_call

  def initialize(publication, daily_call: nil)
    @publication = publication
    @daily_call = daily_call || publication.current_call
  end

  def claim_url(email_value = publication.email_merge_tag)
    url = "#{DailyBingo.public_host}/c/#{publication.public_code}/today?email=#{email_value}"
    if publication.issue_cadence?
      url + "&issue=#{publication.campaign_merge_tag}"
    else
      url
    end
  end

  def word_label
    daily_call&.label || "TODAY'S WORD"
  end

  def sponsor_name
    daily_call&.sponsor&.name
  end

  def prize_call?
    daily_call&.prize_call? || false
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
                    <div style="font-size:11px;font-weight:bold;letter-spacing:2px;color:#{h publication.primary_color};">TODAY&#8217;S BINGO#{" &#127873;" if prize_call?}</div>
                    #{sponsor_row}
                    <div style="font-size:22px;font-weight:bold;color:#{h publication.text_color};padding:10px 0 12px;">#{h word_label}</div>
                    <a href="#{h claim_url}" style="display:inline-block;background-color:#{h publication.accent_color};color:#ffffff;text-decoration:none;font-size:14px;font-weight:bold;padding:9px 18px;border-radius:8px;">Claim today&#8217;s spot &#8594;</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      HTML
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
                    <div style="font-size:14px;color:#{h publication.text_color};padding:10px 0 12px;">A new word drops with this issue &#8212; claim your square.</div>
                    <a href="#{h claim_url}" style="display:inline-block;background-color:#{h publication.accent_color};color:#ffffff;text-decoration:none;font-size:14px;font-weight:bold;padding:9px 18px;border-radius:8px;">Claim today&#8217;s spot &#8594;</a>
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
