require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "passwords must be 8+ characters with upper, lower, number, and special character" do
    user = User.new(email_address: "strong@example.com")

    [ "short1!", "alllowercase1!", "ALLUPPERCASE1!", "NoNumbers!", "NoSpecial123" ].each do |weak|
      user.password = user.password_confirmation = weak
      assert_not user.valid?, "#{weak.inspect} should be rejected"
    end

    user.password = user.password_confirmation = "S3cure!password"
    assert user.valid?
  end

  test "updating a user without touching the password skips password validation" do
    user = users(:one)
    assert user.update(email_address: "renamed@example.com")
  end
end
