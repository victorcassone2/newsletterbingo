# Sets Current.account from the URL, verifying the signed-in user's
# membership. Every admin query flows through Current.account.
module AccountScoping
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
    helper_method :current_account
  end

  private
    def set_current_account
      Current.account = Current.user.accounts.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "That account isn't available."
    end

    def current_account
      Current.account
    end
end
