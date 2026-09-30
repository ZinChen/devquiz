namespace :achievements do
  desc "Sync app/config/achievements.yml to database"
  task sync: :environment do
    result = AchievementsCatalog.sync!
    puts "AchievementsCatalog: создано #{result[:created]}, обновлено #{result[:updated]}, удалено #{result[:removed]}, всего #{result[:total]}"
  end

  desc "Recalculate users.achievements_count from user_achievements"
  task recount: :environment do
    AchievementsCatalog.recount_users!
    puts "AchievementsCatalog: счётчики пересчитаны"
  end

  # Ачивки считаются по фактической истории, поэтому существующим
  # пользователям они выдаются тем же сервисом, что и всем остальным —
  # отдельной логики бэкфилла не нужно.
  desc "Grant achievements to every existing user"
  task backfill: :environment do
    granted = 0

    User.find_each do |user|
      earned = AchievementsService.call(user)
      granted += earned.size
      puts "  #{user.name || user.email}: +#{earned.size} (#{earned.map(&:slug).join(', ')})" if earned.any?
    end

    AchievementsCatalog.recount_users!
    puts "AchievementsCatalog: выдано #{granted} ачивок"
  end
end
