require "rails_helper"

RSpec.describe AchievementsService do
  let(:user) { create(:user) }

  # Каталог живёт в config/achievements.yml и попадает в базу через sync —
  # в тестовой базе его нужно поднять так же, как это делает деплой.
  before { AchievementsCatalog.sync! }

  def complete(slug: "ror-basics", score: 100, correct: 10, at: Time.current, time_spent: 600, weak_only: false)
    TestAttempt.create!(
      user_id: user.id, test_slug: slug, total_questions: 10, correct_count: correct,
      score: score, started_at: at - 10.minutes, completed_at: at,
      time_spent: time_spent, weak_only: weak_only
    )
  end

  def granted_slugs
    described_class.call(user).map(&:slug)
  end

  it "выдаёт первый шаг за первый пройденный тест" do
    complete

    expect(granted_slugs).to include("first_test")
  end

  it "не выдаёт ачивку дважды" do
    complete
    described_class.call(user)

    expect(described_class.call(user)).to be_empty
    expect(user.user_achievements.where(achievement: Achievement.find_by(slug: "first_test")).count).to eq(1)
  end

  it "считает пройденным уникальный тест, а не каждую попытку" do
    10.times { |i| complete(at: i.hours.ago) }

    expect(granted_slugs).not_to include("ten_tests")
  end

  it "выдаёт ступень за десять разных тестов" do
    10.times { |i| complete(slug: "test-#{i}", at: i.hours.ago) }

    expect(granted_slugs).to include("ten_tests")
  end

  it "не зачитывает тренировки по ошибкам как пройденный тест" do
    complete(weak_only: true)

    expect(granted_slugs).not_to include("first_test")
  end

  it "выдаёт работу над ошибками именно за тренировки" do
    5.times { |i| complete(weak_only: true, at: i.hours.ago) }

    expect(granted_slugs).to include("weak_trained")
  end

  it "выдаёт «без ошибок» за результат 100%" do
    complete(score: 100)

    expect(granted_slugs).to include("perfect_score")
  end

  it "не выдаёт «без ошибок» за неполный результат" do
    complete(score: 90)

    expect(granted_slugs).not_to include("perfect_score")
  end

  describe "уровни сложности" do
    before do
      3.times do |i|
        create(:test_metadatum, slug: "basic-#{i}", difficulty: "basic")
        complete(slug: "basic-#{i}", score: 75, at: i.hours.ago)
      end
    end

    it "зачитывает тесты уровня при результате от 70%" do
      expect(granted_slugs).to include("three_basic")
    end

    it "не зачитывает тест, пройденный ниже порога" do
      user.test_attempts.update_all(score: 65)

      expect(granted_slugs).not_to include("three_basic")
    end
  end

  describe "скоростное прохождение" do
    let!(:meta) { create(:test_metadatum, slug: "fast", estimated_time: 20) }

    it "выдаётся за половину отведённого времени при высоком результате" do
      complete(slug: "fast", score: 90, time_spent: 9.minutes.to_i)

      expect(granted_slugs).to include("speedrun")
    end

    it "не выдаётся, если время вышло за половину" do
      complete(slug: "fast", score: 90, time_spent: 15.minutes.to_i)

      expect(granted_slugs).not_to include("speedrun")
    end

    it "не выдаётся при слабом результате" do
      complete(slug: "fast", score: 60, time_spent: 5.minutes.to_i)

      expect(granted_slugs).not_to include("speedrun")
    end
  end

  describe "второй подход" do
    it "выдаётся за улучшение результата по тесту на 30 пунктов" do
      complete(slug: "ror-basics", score: 40, at: 2.days.ago)
      complete(slug: "ror-basics", score: 75, at: 1.day.ago)

      expect(granted_slugs).to include("comeback")
    end

    it "не выдаётся за улучшение меньше порога" do
      complete(slug: "ror-basics", score: 40, at: 2.days.ago)
      complete(slug: "ror-basics", score: 60, at: 1.day.ago)

      expect(granted_slugs).not_to include("comeback")
    end

    it "не считает улучшением высокий результат в другом тесте" do
      complete(slug: "ror-basics", score: 40, at: 2.days.ago)
      complete(slug: "postgresql-basics", score: 95, at: 1.day.ago)

      expect(granted_slugs).not_to include("comeback")
    end
  end

  describe "серия по дням" do
    it "выдаётся за три дня подряд" do
      complete(at: 2.days.ago)
      complete(at: 1.day.ago)
      complete(at: Time.current)

      expect(granted_slugs).to include("streak_three")
    end

    it "не выдаётся, если в серии есть пропуск" do
      complete(at: 4.days.ago)
      complete(at: 3.days.ago)
      complete(at: Time.current)

      expect(granted_slugs).not_to include("streak_three")
    end

    it "не считает несколько тестов за один день серией" do
      complete(at: Time.current.change(hour: 9))
      complete(at: Time.current.change(hour: 14))
      complete(at: Time.current.change(hour: 20))

      expect(granted_slugs).not_to include("streak_three")
    end
  end

  it "выдаёт ачивку за избранное по числу закладок" do
    question = create(:question)
    9.times { create(:bookmark, user: user, question: create(:question)) }

    expect(granted_slugs).not_to include("hoarder")

    create(:bookmark, user: user, question: question)
    expect(granted_slugs).to include("hoarder")
  end

  it "считает верные ответы по всем попыткам" do
    attempt = complete
    100.times { |i| attempt.test_attempt_answers.create!(question_id: "q#{i}", correct: true) }

    expect(granted_slugs).to include("correct_100")
  end

  it "не считает неверные ответы" do
    attempt = complete
    100.times { |i| attempt.test_attempt_answers.create!(question_id: "q#{i}", correct: false) }

    expect(granted_slugs).not_to include("correct_100")
  end

  it "обновляет денормализованный счётчик пользователя" do
    complete
    described_class.call(user)

    expect(user.reload.achievements_count).to eq(user.user_achievements.count)
    expect(user.achievements_count).to be_positive
  end

  it "ничего не делает для гостя" do
    expect(described_class.call(nil)).to eq([])
  end
end
