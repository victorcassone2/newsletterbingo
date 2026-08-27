module BillingsHelper
  # The whole bill in one line, under the list it summarizes: what's being
  # charged for, what it comes to, and the date that matters next.
  def billing_summary
    units = pluralize(current_account.billable_publications.count, "publication")
    "#{units} × $#{Account::PRICE_PER_PUBLICATION} = #{monthly_total}#{billing_timing}"
  end

  # An account with publications but no subscription is either starting one
  # for the first time or picking an old one back up.
  def subscription_start_label
    if current_account.stripe_subscription_id.present?
      "Restart at #{monthly_total}"
    else
      "Start free trial"
    end
  end

  # Canceling one publication is reversible and dated, so the confirmation
  # says both: what the publisher is paid through, and that they can call it
  # off until then.
  def cancellation_confirmation(publication)
    if current_account.paid_through
      "Cancel #{publication.name}? It keeps running until " \
        "#{current_account.paid_through.to_date.strftime("%B %-d")}, the end of the period you've already paid for, " \
        "then its claim links and boards go dark. Your other publications aren't affected, " \
        "and you can call this off any time before then."
    else
      "Cancel #{publication.name}? Its claim links and boards go dark right away. " \
        "Your other publications aren't affected, and you can restore it later."
    end
  end

  # Two different undos: one calls off a cancellation that hasn't landed yet,
  # the other puts a dark publication back on the air and back on the bill.
  def restoration_confirmation(publication)
    if publication.closed?
      "Restore #{publication.name}? Its boards and games pick up where they left off, and it goes back on " \
        "your subscription at $#{Account::PRICE_PER_PUBLICATION}/month, prorated for the rest of this month."
    else
      "Keep #{publication.name}? It stays on the air and stays on your subscription at " \
        "$#{Account::PRICE_PER_PUBLICATION}/month."
    end
  end

  # Offered on the last publication a subscription pays for, where canceling
  # the publication and canceling the subscription are the same act.
  def subscription_cancellation_confirmation(publication)
    "Cancel your subscription? #{publication.name} is the only publication it pays for, so this ends " \
      "the whole thing. #{games_run_until}"
  end

  private
    def monthly_total
      "$#{current_account.monthly_price}/month"
    end

    # The next date on the calendar that costs or saves them something.
    def billing_timing
      case current_account.billing_state
      when :inactive
        ", once a subscription is running."
      when :payment_problem
        ". Your card needs updating."
      else
        if current_account.cancel_scheduled?
          ". Your subscription ends #{renewal_date} and games run until then."
        elsif current_account.trialing?
          ", free until #{renewal_date}. Cancel before then and you won't pay a thing."
        else
          ". Next renewal is #{renewal_date}."
        end
      end
    end

    def games_run_until
      if current_account.paid_through
        "Games run until #{current_account.paid_through.to_date.strftime("%B %-d, %Y")}, then they stop rotating."
      else
        "Games run until the paid period ends, then they stop rotating."
      end
    end

    def renewal_date
      current_account.subscription_current_period_end&.strftime("%B %-d, %Y")
    end
end
