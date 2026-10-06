require "rails_helper"

RSpec.describe AchievementsCatalog do
  describe ".sync!" do
    it "создаёт записи по каталогу" do
      result = described_class.sync!

      expect(result[:created]).to eq(described_class.entries.size)
      expect(Achievement.count).to eq(described_class.entries.size)
    end

    it "второй прогон ничего не меняет" do
      described_class.sync!

      expect(described_class.sync!).to include(created: 0, updated: 0, removed: 0)
    end

    it "обновляет изменившиеся поля" do
      described_class.sync!
      Achievement.find_by(slug: "first_test").update!(title: "Старое название")

      expect(described_class.sync!).to include(updated: 1)
      expect(Achievement.find_by(slug: "first_test").title).to eq("Первый шаг")
    end

    it "удаляет ачивки, выпавшие из каталога, вместе с выдачами" do
      described_class.sync!
      user = create(:user)
      stale = Achievement.create!(slug: "stale", title: "Лишняя")
      UserAchievement.create!(user: user, achievement: stale, earned_at: Time.current)
      user.update!(achievements_count: 1)

      expect(described_class.sync!).to include(removed: 1)
      expect(Achievement.find_by(slug: "stale")).to be_nil
      # Счётчик пересчитан: выдача ушла каскадом, иначе бейдж показывал бы
      # ачивку, которой больше нет.
      expect(user.reload.achievements_count).to eq(0)
    end

    it "переносит группу, порог и флаг видимости из yml" do
      described_class.sync!

      expect(Achievement.find_by(slug: "ten_tests")).to have_attributes(
        group_name: "tests_passed", threshold: 10, shareable: true
      )
      expect(Achievement.find_by(slug: "streak_week").shareable).to be(false)
    end
  end

  describe ".recount_users!" do
    it "исправляет разъехавшийся счётчик" do
      described_class.sync!
      user = create(:user, achievements_count: 7)
      UserAchievement.create!(user: user, achievement: Achievement.first, earned_at: Time.current)

      described_class.recount_users!

      expect(user.reload.achievements_count).to eq(1)
    end
  end

  describe "каталог" do
    it "у каждой ачивки есть название и позиция" do
      expect(described_class.entries).to all(have_attributes(title: be_present, position: be_present))
    end

    it "слаги уникальны" do
      slugs = described_class.slugs

      expect(slugs.uniq.size).to eq(slugs.size)
    end

    it "ступени группы различаются порогами" do
      described_class.entries.group_by(&:group).each do |group, tiers|
        next if group.nil?

        thresholds = tiers.map(&:threshold)
        expect(thresholds).to all(be_present)
        expect(thresholds.uniq.size).to eq(thresholds.size), "группа #{group}: пороги повторяются"
      end
    end
  end
end
