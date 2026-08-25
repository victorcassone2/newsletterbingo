# Sets Current.account from the URL, verifying the signed-in user's
# membership. Every admin query flows through Current.account.
# A deactivated account stays reachable only for its owners.
module AccountScoping
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
    helper_method :current_account
  end

  private
    def set_current_account
      Current.account = Current.user.accounts.find(params[:account_id])
      unless Current.user.can_access?(Current.account)
        Current.account = nil
        redirect_to dashboard_path, alert: "That account has been deactivated."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to dashboard_path, alert: "That account isn't available."
    end

    def current_account
      Current.account
    end

    def require_account_owner
      unless Current.user.owner_of?(Current.account)
        redirect_to account_account_profile_path(account_id: Current.account.id),
          alert: "Only account owners can do that."
      end
    end
end
