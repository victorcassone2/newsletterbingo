class Publications::TestAddressesController < Publications::BaseController
  # Listing an address the account can't reach on its own: a seed list, an
  # outside designer, anyone who gets the real send but must never move the
  # game. Adds and removals land via Turbo Stream so Setup never reloads.
  def create
    @test_address = @publication.test_addresses.new(test_address_params)
    if @test_address.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to setup_path, notice: "#{@test_address.email} will only ever see a preview." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("test-address-errors",
            helpers.tag.div(@test_address.errors.full_messages.to_sentence, class: "errors"))
        end
        format.html { redirect_to setup_path, alert: @test_address.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @test_address = @publication.test_addresses.find(params[:id])
    @test_address.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to setup_path, notice: "#{@test_address.email} can claim again." }
    end
  end

  private
    def test_address_params
      params.require(:test_address).permit(:email)
    end

    def setup_path
      edit_account_publication_path(id: @publication.id, pane: "connect")
    end
end
