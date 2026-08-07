class Word < ApplicationRecord
  include Archivable

  belongs_to :publication, optional: true
  has_many :game_words, dependent: :restrict_with_error

  scope :system, -> { where(publication_id: nil) }
  scope :custom, -> { where.not(publication_id: nil) }
  scope :search, ->(query) { query.present? ? where("label ILIKE ?", "%#{sanitize_sql_like(query)}%") : all }

  normalizes :label, with: ->(l) { l.strip.squish.upcase }

  validates :label, presence: true, length: { maximum: 40 }
  validate :label_unique_in_scope

  def system?
    publication_id.nil?
  end

  def in_open_game?
    game_words.joins(:game).merge(Game.open).exists?
  end

  private
    def label_unique_in_scope
      scope = system? ? Word.system : Word.where(publication_id: publication_id)
      if scope.where.not(id: id).where("lower(label) = ?", label.to_s.downcase).exists?
        errors.add(:label, "is already in the word library")
      end
    end
end
