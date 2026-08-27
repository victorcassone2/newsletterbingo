require "test_helper"

class PageTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:publisher)
    23.times { |index| @account.publications.create!(name: "Weekly #{format("%02d", index)}") }
    @relation = @account.publications.order(:name)
  end

  test "a page carries its own slice and knows where it sits" do
    page = Page.new(@relation, number: 2)

    assert_equal 25, page.total
    assert_equal 10, page.records.count
    assert_equal @relation.offset(10).limit(10).map(&:id), page.records.map(&:id)
    assert_equal "11-20", page.range
    assert_not page.first?
    assert_not page.last?
    assert_equal 1, page.previous_number
    assert_equal 3, page.next_number
  end

  test "the last page is short and knows it" do
    page = Page.new(@relation, number: 3)

    assert page.last?
    assert_equal 5, page.records.count
    assert_equal "21-25", page.range
  end

  test "a missing or out-of-range number clamps to a real page" do
    assert_equal 1, Page.new(@relation).number
    assert_equal 1, Page.new(@relation, number: "0").number
    assert_equal 3, Page.new(@relation, number: "99").number
    assert_equal 1, Page.new(@account.publications.none).number, "an empty list still has a first page"
  end

  test "a list that fits on one page needs no navigation" do
    page = Page.new(@account.publications.where(name: "Weekly 01"))

    assert_not page.multiple?
    assert page.first?
    assert page.last?
  end
end
