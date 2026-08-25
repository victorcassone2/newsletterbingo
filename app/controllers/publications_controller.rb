class PublicationsController < ApplicationController
  include AccountScoping, SubscriptionStarting

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

  # Creating the publication is the billing commitment (the button says so):
  # an already-subscribed account just grows its subscription's quantity via
  # the callback, a fresh one starts its subscription here -- straight to
  # Setup with a card on file, through hosted Checkout without.
  def create
    @publication = Current.account.publications.new(publication_params)
    if @publication.save
      if @publication.billing_active?
        redirect_to edit_account_publication_path(id: @publication.id),
          notice: "#{@publication.name} is created. Time to set it up."
      else
        start_subscription_or_checkout(
          landing_path: edit_account_publication_path(id: @publication.id),
          publication: @publication
        )
      end
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
      # pane rides as a query param, not a URL fragment: Turbo drops
      # fragments when following a form submission's redirect.
      redirect_to edit_account_publication_path(id: @publication.id, pane: params[:pane].presence), notice: "Saved."
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
        :cadence, :campaign_merge_tag, :board_size, :primary_color, :accent_color,
        :background_color, :text_color, :logo, send_days: [])
    end

    # Real words for the branding preview: the current game's board if
    # there is one, otherwise a slice of the library.
    def preview_words
      if (game = @publication.active_game || @publication.on_deck_game)
        game.game_words.map(&:label).first(@publication.board_cells)
      else
        @publication.eligible_words.order(:label).limit(@publication.board_cells).map(&:label)
      end
    end
end
