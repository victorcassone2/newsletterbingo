class Publications::BaseController < ApplicationController
  include AccountScoping

  before_action :set_publication

  private
    def set_publication
      @publication = Current.account.publications.find(params[:publication_id])
    end
end
