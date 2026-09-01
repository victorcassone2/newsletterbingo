# Every asset this app loads is served from its own origin: no CDN, no Google
# Fonts, no third-party script. The one exception is Active Storage, which
# hands a publication's logo or a prize photo off to a signed S3 URL, so
# img-src has to allow https.
#
# Checkout and the billing portal are full-page redirects to Stripe rather
# than embedded forms or iframes, so nothing here needs to name stripe.com.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.font_src        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none
    policy.script_src      :self
    policy.connect_src     :self
    # Active Storage redirects to a signed S3 URL on another host.
    policy.img_src         :self, :data, :https
    # Reader boards and the admin carry inline style attributes for each
    # publication's brand colors. Style attributes can't take a nonce, and a
    # nonce would make CSP ignore unsafe-inline, so style-src stays nonce-free.
    policy.style_src       :self, :unsafe_inline
  end

  # The importmap's <script type="importmap"> is the only inline script in the
  # app; importmap-rails stamps it with this nonce on its own.
  #
  # Not Rails' suggested request.session.id: a reader landing on a board, or
  # anyone on the marketing page, has no session yet at render time, so the
  # nonce came out empty and the browser dropped the importmap along with every
  # bit of JavaScript behind it. Generated per request and memoized in the env
  # instead, so the header and the tag always agree and a nonce always exists.
  config.content_security_policy_nonce_generator = ->(request) {
    request.env["newsletter_bingo.csp_nonce"] ||= SecureRandom.base64(16)
  }
  config.content_security_policy_nonce_directives = %w[ script-src ]
end
