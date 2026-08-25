class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    render :landing, layout: "marketing"
  end
end
