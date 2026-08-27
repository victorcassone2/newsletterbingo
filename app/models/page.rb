# A numbered slice of an ordered relation, with the neighbors a view needs to
# link to. Lists only grow page links once they outgrow one screenful, so a
# short list reads exactly as it did before it was paginated.
class Page
  SIZE = 10

  attr_reader :number, :size, :total

  # An out-of-range page number (a stale link, a hand-typed one) clamps to the
  # nearest real page rather than rendering an empty list.
  def initialize(relation, number: nil, size: SIZE)
    @relation = relation
    @size = size
    @total = relation.count
    @number = number.to_i.clamp(1, last_number)
  end

  def records
    @records ||= @relation.offset(offset).limit(size)
  end

  # One screenful needs no navigation.
  def multiple?
    total > size
  end

  def first?
    number == 1
  end

  def last?
    number == last_number
  end

  def previous_number
    number - 1
  end

  def next_number
    number + 1
  end

  # The stretch of the list this page covers, for the count line.
  def range
    "#{offset + 1}-#{[ offset + size, total ].min}"
  end

  private
    def last_number
      [ (total / size.to_f).ceil, 1 ].max
    end

    def offset
      (number - 1) * size
    end
end
