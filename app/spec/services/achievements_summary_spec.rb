require "rails_helper"

RSpec.describe AchievementsSummary do
  let(:user) { create(:user) }

  before { AchievementsCatalog.sync! }

  def complete(slug:, score: 100, at: Time.current)
    TestAttempt.create!(
      user_id: user.id, test_slug: slug, total_questions: 10, correct_count: 10,
      score: score, started_at: at - 10.minutes, completed_at: at, time_spent: 600
    )
  end

  def props
    described_class.for(user: user).to_props
  end

  def tile(key)
    props[:items].find { |i| i[:key] == key }
  end

  it "сворачивает ступени группы в одну плитку" do
    tests_passed = props[:items].count { |i| i[:key] == "tests_passed" }

    expect(tests_passed).to eq(1)
    expect(props[:items].size).to be < AchievementsCatalog.entries.size
  end

  it "показывает первую ступень как цель, пока ничего не взято" do
    expect(tile("tests_passed")).to include(earned: false, title: "Первый шаг")
  end

  it "показывает взятую ступень и прогресс до следующей" do
    complete(slug: "ror-basics")
    AchievementsService.call(user)

    expect(tile("tests_passed")).to include(earned: true, title: "Первый шаг")
    expect(tile("tests_passed")[:progress]).to include(current: 1, target: 10, next_title: "На разгоне")
  end

  it "считает взятые ступени группы" do
    complete(slug: "ror-basics")
    AchievementsService.call(user)

    expect(tile("tests_passed")[:tier]).to eq({ index: 1, total: 4 })
  end

  it "не показывает прогресс у бинарных ачивок" do
    expect(tile("speedrun")[:progress]).to be_nil
  end

  it "красит подложку иконки цветом группы, а одиночные — общим" do
    expect(tile("tests_passed")[:color]).to eq(AchievementsCatalog.color_for("tests_passed"))
    expect(tile("speedrun")[:color]).to eq(AchievementsCatalog.color_for(nil))
  end

  it "отдаёт в полоску ступень и прогресс той же группы, что и плитка" do
    12.times { |i| complete(slug: "test-#{i}", at: i.hours.ago) }
    AchievementsService.call(user)

    recent = described_class.for(user: user).to_props[:recent].find { |r| r[:slug] == "ten_tests" }
    expect(recent[:progress]).to eq(tile("tests_passed")[:progress])
    expect(recent[:color]).to eq(tile("tests_passed")[:color])
  end

  it "обрезает прогресс по порогу следующей ступени" do
    12.times { |i| complete(slug: "test-#{i}", at: i.hours.ago) }
    AchievementsService.call(user)

    progress = tile("tests_passed")[:progress]
    expect(progress[:target]).to eq(20)
    expect(progress[:current]).to eq(12)
  end

  it "убирает прогресс, когда лесенка пройдена целиком" do
    30.times { |i| complete(slug: "test-#{i}", at: i.hours.ago) }
    AchievementsService.call(user)

    expect(tile("tests_passed")[:progress]).to be_nil
    expect(tile("tests_passed")[:title]).to eq("Знаток каталога")
  end

  it "отдаёт последние полученные ачивки для полоски в кабинете" do
    complete(slug: "ror-basics")
    AchievementsService.call(user)

    expect(props[:recent].size).to be_between(1, described_class::RECENT_LIMIT)
    expect(props[:recent].first).to include(:slug, :title, :icon, :earned_at)
  end

  describe "#to_public_props — вид для других пользователей (#10)" do
    before do
      complete(slug: "ror-basics")
      # Серия по дням — из тех ачивок, что раскрывают поведение: shareable: false.
      complete(slug: "test-a", at: 1.day.ago)
      complete(slug: "test-b", at: 2.days.ago)
      AchievementsService.call(user)
    end

    it "отдаёт только полученные ачивки" do
      slugs = described_class.for(user: user).to_public_props[:items].map { |i| i[:slug] }

      expect(slugs).to include("first_test")
      expect(slugs).not_to include("ten_tests")
    end

    it "скрывает ачивки, раскрывающие поведение" do
      slugs = described_class.for(user: user).to_public_props[:items].map { |i| i[:slug] }

      expect(user.achievements.pluck(:slug)).to include("streak_three")
      expect(slugs).not_to include("streak_three")
    end

    it "не отдаёт ни дату получения, ни прогресс" do
      item = described_class.for(user: user).to_public_props[:items].first

      expect(item.keys).to contain_exactly(:slug, :title, :description, :icon, :color, :earned)
      expect(item).not_to include(:earned_at, :progress, :tier)
    end

    it "считает ачивки для бейджа" do
      public_props = described_class.for(user: user).to_public_props

      expect(public_props[:count]).to eq(public_props[:items].size)
    end
  end

  it "считает плитки, а не ступени каталога" do
    complete(slug: "ror-basics")
    AchievementsService.call(user)

    # Ступеней выдано больше, чем плиток: first_test и perfect_score — это две
    # ступени в двух разных группах, и каждая показана одной плиткой.
    expect(props[:total_count]).to eq(props[:items].size)
    expect(props[:total_count]).to be < Achievement.count
    expect(props[:earned_count]).to eq(props[:items].count { |i| i[:earned] })
  end

  it "не считает группу дважды, когда в ней взято несколько ступеней" do
    12.times { |i| complete(slug: "test-#{i}", at: i.hours.ago) }
    AchievementsService.call(user)

    # Взяты first_test и ten_tests — две ступени одной группы, плитка одна.
    expect(user.achievements.where(group_name: "tests_passed").count).to eq(2)
    expect(props[:items].count { |i| i[:key] == "tests_passed" }).to eq(1)
  end
end
