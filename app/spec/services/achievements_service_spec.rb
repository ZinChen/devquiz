require "rails_helper"

RSpec.describe AchievementsService do
  let(:user) { create(:user) }

  # Каталог живёт в config/achievements.yml и попадает в базу через sync —
  # в тестовой базе его нужно поднять так же, как это делает деплой.
  before { AchievementsCatalog.sync! }

  def complete(slug: "ror-basics", score: 100, correct: 10, at: Time.current, time_spent: 600, weak_only: false)
    # Слабые вопросы считаются только по живым тестам (WeakQuestions), а запись
    # в test_metadata в жизни есть у каждого — её заводит YamlSyncService.
    TestMetadatum.find_or_create_by!(slug: slug) { |m| m.title = slug }
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

  describe "исправленные ошибки" do
    # Вопрос уходит из слабых после STREAK_TO_CLEAR верных подряд — именно
    # такие и считаются исправленными.
    def answer(question_id, correct, at: Time.current)
      attempt = complete(at: at)
      attempt.test_attempt_answers.create!(question_id: question_id, correct: correct, created_at: at)
    end

    def fix(question_id, at: 3.hours.ago)
      answer(question_id, false, at: at)
      answer(question_id, true,  at: at + 1.hour)
      answer(question_id, true,  at: at + 2.hours)
    end

    it "считает вопрос исправленным после двух верных подряд" do
      10.times { |i| fix("q#{i}") }

      expect(granted_slugs).to include("mistakes_10")
    end

    it "не считает вопрос, в котором не было ошибок" do
      10.times do |i|
        answer("q#{i}", true, at: 2.hours.ago)
        answer("q#{i}", true, at: 1.hour.ago)
      end

      expect(granted_slugs).not_to include("mistakes_10")
    end

    it "не считает вопрос, который всё ещё слабый" do
      10.times do |i|
        answer("q#{i}", false, at: 2.hours.ago)
        answer("q#{i}", true,  at: 1.hour.ago)
      end

      expect(granted_slugs).not_to include("mistakes_10")
    end

    it "выдаёт «Чистый лист», когда слабых вопросов не осталось" do
      10.times { |i| fix("q#{i}") }

      expect(granted_slugs).to include("mistakes_clear")
    end

    it "не выдаёт «Чистый лист», пока есть неразобранные вопросы" do
      10.times { |i| fix("q#{i}") }
      answer("still-weak", false)

      expect(granted_slugs).not_to include("mistakes_clear")
    end

    it "не выдаёт «Чистый лист» тому, у кого ошибок не было" do
      answer("q1", true)

      expect(granted_slugs).not_to include("mistakes_clear")
    end

    it "не отбирает «Чистый лист», когда появляются новые ошибки" do
      10.times { |i| fix("q#{i}") }
      described_class.call(user)
      expect(user.achievements.pluck(:slug)).to include("mistakes_clear")

      answer("fresh-mistake", false)
      described_class.call(user)

      # Ачивка про факт, а не про состояние списка: отбирать её при первой же
      # новой ошибке значило бы наказывать за прохождение новых тестов.
      expect(user.achievements.pluck(:slug)).to include("mistakes_clear")
    end
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

  it "не считает один и тот же вопрос дважды при повторном прохождении" do
    2.times do |pass|
      attempt = complete(at: pass.hours.ago)
      100.times { |i| attempt.test_attempt_answers.create!(question_id: "q#{i}", correct: true) }
    end

    # Сто вопросов, пройденных дважды, — это сто вопросов, а не двести: иначе
    # лесенка мерила бы усидчивость, а не охват каталога.
    expect(AchievementFacts.new(user).correct_answers_count).to eq(100)
  end

  it "считает одинаковые id вопросов из разных тестов по отдельности" do
    %w[ror-basics postgresql-basics].each_with_index do |slug, pass|
      attempt = complete(slug: slug, at: pass.hours.ago)
      50.times { |i| attempt.test_attempt_answers.create!(question_id: "q#{i}", correct: true) }
    end

    # q1 есть почти в каждом тесте — это разные вопросы.
    expect(AchievementFacts.new(user).correct_answers_count).to eq(100)
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
