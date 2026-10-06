class AddAchievementsCountToUsers < ActiveRecord::Migration[8.1]
  def change
    # Денормализованный счётчик для бейджа на аватарке (#10): live-активность
    # опрашивается каждые 15с, считать ачивки для всей стопки участников на
    # каждом опросе нельзя. Инкрементируется при выдаче; rake
    # achievements:recount пересчитывает, если разъехался.
    add_column :users, :achievements_count, :integer, null: false, default: 0
  end
end
