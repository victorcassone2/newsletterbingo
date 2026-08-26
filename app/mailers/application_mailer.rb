class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Newsletter Bingo <no-reply@localhost>")
  layout "mailer"
end
