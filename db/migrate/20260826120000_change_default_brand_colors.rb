class ChangeDefaultBrandColors < ActiveRecord::Migration[8.1]
  # New publications start on the Newsletter Bingo palette: the logo's
  # darker amber for headings, its main amber for claimed squares.
  COLORS = {
    primary_color: [ "#b45309", "#1F2937" ],
    accent_color: [ "#f59e0b", "#2563EB" ],
    background_color: [ "#fcfcfc", "#F9FAFB" ],
    text_color: [ "#2a2118", "#111827" ]
  }

  def up
    COLORS.each do |column, (new_default, _old_default)|
      change_column_default :publications, column, new_default
    end
  end

  def down
    COLORS.each do |column, (_new_default, old_default)|
      change_column_default :publications, column, old_default
    end
  end
end
