require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  test "email is normalized before lookup" do
    participant = Participant.locate_or_register(publications(:omaha), "  Reader@Example.COM ")
    assert_equal "reader@example.com", participant.email
  end

  test "same email in the same publication returns the same participant" do
    first = Participant.locate_or_register(publications(:omaha), "reader@example.com")
    second = Participant.locate_or_register(publications(:omaha), "READER@example.com")
    assert_equal first, second
  end

  test "same email in different publications creates separate participants" do
    omaha = Participant.locate_or_register(publications(:omaha), "reader@example.com")
    lincoln = Participant.locate_or_register(publications(:lincoln), "reader@example.com")
    assert_not_equal omaha, lincoln
  end

  test "malformed emails are rejected" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Participant.locate_or_register(publications(:omaha), "not-an-email")
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      Participant.locate_or_register(publications(:omaha), "{{email}}")
    end
  end

  test "public tokens are long and unique" do
    participant = Participant.locate_or_register(publications(:omaha), "reader@example.com")
    assert_operator participant.public_token.length, :>=, 36
  end
end
