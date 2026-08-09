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
      redirect_to edit_account_publication_path(id: @publication.id),
        notice: "#{@publication.name} is ready. Set your merge tag and branding here, then create a game from Today."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Setup: newsletter embed, merge tag, branding, and publication settings
  # on one guided page.
  def edit
    @newsletter_block = NewsletterBlock.new(@publication)
    @preview_words = preview_words
  end

  def update
    if @publication.update(publication_params)
      redirect_to edit_account_publication_path(id: @publication.id), notice: "Saved."
    else
      @newsletter_block = NewsletterBlock.new(@publication)
      @preview_words = preview_words
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_publication
      @publication = Current.account.publications.find(params[:id])
    end

    def publication_params
      params.require(:publication).permit(:name, :timezone, :email_merge_tag, :active,
        :cadence, :campaign_merge_tag, :primary_color, :accent_color, :background_color,
        :text_color, :logo, send_days: [])
    end

    # Real words for the branding preview: the open game's board if there
    # is one, otherwise a slice of the library.
    def preview_words
      if (game = @publication.open_game)
        game.game_words.map(&:label).first(24)
      else
        @publication.eligible_words.order(:label).limit(24).map(&:label)
      end
    end
end
