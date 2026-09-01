class ApplicationMailer < ActionMailer::Base
  # Development's address only. Mailgun refuses mail from a domain it hasn't
  # verified, and raise_delivery_errors turns that refusal into a 500 on the
  # invitation and password-reset paths, so production supplies its own and
  # config/initializers/required_env.rb refuses to boot without it.
  default from: ENV.fetch("MAIL_FROM", "Newsletter Bingo <no-reply@localhost>")
  layout "mailer"
end
