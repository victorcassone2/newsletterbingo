ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/game_test_helper"

module ActiveSupport
  class TestCase
    # Process workers crash in pg connection setup on the supported local Ruby stack.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include GameTestHelper
  end
end
