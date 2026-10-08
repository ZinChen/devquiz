require "rails_helper"

RSpec.describe ActivityPresence do
  let!(:test_meta) { create(:test_metadatum, slug: "ruby-basics") }
  let(:user)       { create(:user) }
  let(:viewer)     { ActivityViewer.new(user: user) }
  let(:guest)      do
    ActivityViewer.new(guest_token: "tok-1", guest_identity: { name: "Тихий Ёж", avatar_seed: "abcd1234" })
  end

  describe ".join" do
    it "записывает аккаунт и отдаёт его в снимке" do
      described_class.join(viewer, test_slug: "ruby-basics", question_id: "q1")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry).to include(name: user.name, question_id: "q1")
    end

    it "не светит почту, если у пользователя нет avatar_seed" do
      user.update!(avatar_seed: nil)
      described_class.join(viewer, test_slug: "ruby-basics")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry[:avatar_seed]).to eq("user-#{user.id}")
      expect(entry.values.map(&:to_s).join).not_to include(user.email)
    end

    it "записывает гостя под сгенерированным именем и без сырого токена" do
      described_class.join(guest, test_slug: "ruby-basics")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry).to include(name: "Тихий Ёж", avatar_seed: "abcd1234")
      expect(entry[:key]).not_to include("tok-1")
      expect(described_class.pluck(:viewer_key).join).not_to include("tok-1")
    end

    it "повторный вход обновляет запись, а не плодит дубли" do
      2.times { described_class.join(viewer, test_slug: "ruby-basics") }

      expect(described_class.count).to eq(1)
    end

    it "не записывает того, кто скрыл активность" do
      user.update!(activity_visible: false)

      expect(described_class.join(viewer, test_slug: "ruby-basics")).to be(false)
      expect(described_class.count).to eq(0)
    end

    it "не записывает анонима без идентичности" do
      expect(described_class.join(ActivityViewer.new, test_slug: "ruby-basics")).to be(false)
    end

    it "не записывает несуществующий тест" do
      expect(described_class.join(viewer, test_slug: "nope")).to be(false)
    end

    it "сохраняет прежний вопрос, если heartbeat пришёл без question_id" do
      described_class.join(viewer, test_slug: "ruby-basics", question_id: "q3")
      described_class.join(viewer, test_slug: "ruby-basics")

      expect(described_class.last.question_id).to eq("q3")
    end
  end

  describe ".snapshot" do
    it "прячет пользователя, выключившего видимость после входа" do
      described_class.join(viewer, test_slug: "ruby-basics")
      user.update!(activity_visible: false)

      expect(described_class.snapshot).to eq({})
    end

    it "не показывает и удаляет записи старше TTL" do
      described_class.join(viewer, test_slug: "ruby-basics")
      described_class.update_all(last_seen_at: (described_class::TTL + 1.second).ago)

      expect(described_class.snapshot).to eq({})
      expect(described_class.count).to eq(0)
    end
  end

  describe "число ачивок у участника" do
    before { AchievementsCatalog.sync! }

    def grant(slug)
      UserAchievement.create!(user: user, achievement: Achievement.find_by!(slug: slug), earned_at: Time.current)
    end

    it "считает только shareable-ачивки, а не users.achievements_count" do
      grant("first_test")
      grant("streak_three")  # раскрывает поведение: shareable: false
      user.update!(achievements_count: 2)
      described_class.join(viewer, test_slug: "ruby-basics")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry).to include(user_id: user.id, achievements_count: 1)
    end

    it "считает лесенку одной плиткой" do
      %w[first_test ten_tests twenty_tests perfect_score].each { |slug| grant(slug) }
      described_class.join(viewer, test_slug: "ruby-basics")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry[:achievements_count]).to eq(2)
    end

    it "у гостя ачивок нет и id пользователя пуст" do
      described_class.join(guest, test_slug: "ruby-basics")

      entry = described_class.snapshot.fetch("ruby-basics").first
      expect(entry).to include(user_id: nil, achievements_count: 0)
    end
  end

  describe ".visible_user" do
    it "находит участника с живой записью" do
      described_class.join(viewer, test_slug: "ruby-basics")

      expect(described_class.visible_user(user.id)).to eq(user)
    end

    it "не находит того, кого нет в активности" do
      expect(described_class.visible_user(user.id)).to be_nil
    end

    it "не находит скрывшего активность" do
      described_class.join(viewer, test_slug: "ruby-basics")
      user.update!(activity_visible: false)

      expect(described_class.visible_user(user.id)).to be_nil
    end
  end

  describe ".leave" do
    it "убирает зрителя из списка" do
      described_class.join(viewer, test_slug: "ruby-basics")
      described_class.leave(viewer)

      expect(described_class.snapshot).to eq({})
    end
  end

  describe ".forget_user" do
    it "убирает все записи пользователя" do
      described_class.join(viewer, test_slug: "ruby-basics")
      described_class.forget_user(user)

      expect(described_class.count).to eq(0)
    end
  end
end
