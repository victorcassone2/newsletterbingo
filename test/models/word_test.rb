require "test_helper"

class WordTest < ActiveSupport::TestCase
  test "labels are normalized to squished uppercase" do
    word = Word.create!(label: "  farmers   market ")
    assert_equal "FARMERS MARKET", word.label
  end

  test "system labels are unique case-insensitively" do
    Word.create!(label: "UNIQUEWORD")
    duplicate = Word.new(label: "uniqueword")
    assert_not duplicate.valid?
  end

  test "a publication can shadow a system label but not duplicate its own" do
    publication = publications(:omaha)
    assert publication.words.new(label: "SYSWORD0").valid?
    assert_not publication.words.new(label: "farmers market").valid?
  end

  test "custom words are invisible to other publications" do
    assert_not_includes publications(:rival).eligible_words, words(:custom_omaha)
  end

  test "archived words leave the eligible pool" do
    words(:custom_omaha).archive
    assert_not_includes publications(:omaha).eligible_words, words(:custom_omaha)
  end
end
