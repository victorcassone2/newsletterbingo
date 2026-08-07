class Publications::SponsorsController < Publications::BaseController
  before_action :set_sponsor, only: %i[ edit update ]

  def index
    @sponsors = @publication.sponsors.order(:name)
  end

  def new
    @sponsor = @publication.sponsors.new
  end

  def create
    @sponsor = @publication.sponsors.new(sponsor_params)
    if @sponsor.save
      redirect_to account_publication_sponsors_path(publication_id: @publication.id), notice: "#{@sponsor.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sponsor.update(sponsor_params)
      redirect_to account_publication_sponsors_path(publication_id: @publication.id), notice: "Sponsor saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_sponsor
      @sponsor = @publication.sponsors.find(params[:id])
    end

    def sponsor_params
      params.require(:sponsor).permit(:name, :website_url, :description, :logo)
    end
end
