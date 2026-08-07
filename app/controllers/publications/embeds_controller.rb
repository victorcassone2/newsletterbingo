class Publications::EmbedsController < Publications::BaseController
  def show
    @newsletter_block = NewsletterBlock.new(@publication)
  end
end
