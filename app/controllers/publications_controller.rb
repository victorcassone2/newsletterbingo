class PublicationsController < ApplicationController
  include AccountScoping

  before_action :set_publication, only: %i[ show edit update ]

  def index
    @publications = Current.account.publications.order(:name)
  end

  def show
    redirect_to account_publication_today_path(publication_id: @publication.id)
  end

  def new
    @publication = Current.account.publications.new
  end

  def create
    @publication = Current.account.publications.new(publication_params)
    if @publication.save
      redirect_to account_publication_today_path(publication_id: @publication.id),
        notice: "#{@publication.name} is ready. Create a game to start playing."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @publication.update(publication_params)
      redirect_to account_publication_today_path(publication_id: @publication.id), notice: "Settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_publication
      @publication = Current.account.publications.find(params[:id])
    end

    def publication_params
      params.require(:publication).permit(:name, :slug, :timezone, :email_merge_tag, :active,
        :primary_color, :accent_color, :background_color, :text_color, :logo)
    end
end
