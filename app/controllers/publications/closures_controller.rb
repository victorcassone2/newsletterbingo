# Canceling one publication on an account that runs several. It comes off the
# subscription right away (the next invoice is smaller by $29) and stays on
# the air until the end of the period already paid for, so readers finish out
# what the publisher bought. Every other publication is untouched, which is
# the whole point. DELETE calls the whole thing off.
class Publications::ClosuresController < Publications::BaseController
  def create
    if @publication.closable?
      @publication.close
      back_to_billing notice: cancellation_notice
    else
      back_to_billing alert: "#{@publication.name} is the only publication your subscription pays for. " \
        "Cancel the subscription itself to shut it down."
    end
  end

  def destroy
    @publication.reopen
    back_to_billing notice: "#{@publication.name} is staying. Your next bill is $#{Current.account.monthly_price}/month."
  end

  private
    # An account with no paid period left has nothing to run out, so its
    # publications go dark on the spot.
    def cancellation_notice
      if @publication.closed?
        "#{@publication.name} is cancelled, and its claim links and boards are dark now."
      else
        "#{@publication.name} is cancelled. Readers keep playing until #{@publication.closes_on.strftime("%B %-d")}, " \
          "and your next bill is $#{Current.account.monthly_price}/month."
      end
    end

    # Back to the page of the list they acted from, not the top of it.
    def back_to_billing(**flash)
      redirect_to account_billing_path(account_id: Current.account.id, page: params[:page].presence), **flash
    end
end
