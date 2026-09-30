# Факты об истории пользователя, по которым считаются ачивки: сколько тестов
# пройдено, сколько верных ответов, какая была серия по дням и так далее.
#
# Отдельно от AchievementsService, потому что те же числа нужны кабинету —
# плитка группы показывает не только взятую ступень, но и прогресс до
# следующей («23 / 30»). Считать это дважды разными способами значило бы
# получить два расходящихся ответа на один вопрос.
#
# Тренировки по ошибкам (weak_only) в зачёт не идут, как и в статистике теста:
# исключение — weak_trainings_count, ачивка про них и есть.
class AchievementFacts
  PASS_SCORE      = 70   # с этого результата тест считается пройденным
  PERFECT_SCORE   = 100
  SPEEDRUN_SCORE  = 80
  SPEEDRUN_FACTOR = 0.5  # доля estimated_time, в которую нужно уложиться
  COMEBACK_GAIN   = 30   # на сколько пунктов улучшен результат по тесту

  def initialize(user)
    @user = user
  end

  # Число, с которым сравнивается threshold ачивки. nil — у ачивок, где
  # прогресса нет: они либо получены, либо нет.
  def value_for(entry)
    case entry.group
    when "tests_passed"    then passed_slugs.size
    when "correct_answers" then correct_answers_count
    when "perfect"         then perfect_slugs.size
    when "level_basic"     then level_counts["basic"].to_i
    when "level_advanced"  then level_counts["advanced"].to_i
    when "level_expert"    then level_counts["expert"].to_i
    else
      case entry.slug
      when "weak_trained"                then weak_trainings_count
      when "hoarder"                     then bookmarks_count
      when "streak_three", "streak_week" then longest_streak
      end
    end
  end

  # Ачивки без порога: условие либо выполнено, либо нет.
  def flag_for(slug)
    case slug
    when "speedrun"    then speedrun?
    when "code_runner" then code_runner?
    when "comeback"    then comeback?
    end
  end

  # Все зачётные попытки разом: условий много, и каждое читает ту же историю —
  # десяток запросов вместо одного тут ничего не даёт.
  def attempts
    @attempts ||= user.test_attempts
      .where.not(completed_at: nil)
      .where(weak_only: false)
      .order(:completed_at)
      .to_a
  end

  # Уникальные тесты: десять повторов одного теста — одна единица.
  def passed_slugs
    @passed_slugs ||= attempts.map(&:test_slug).uniq
  end

  def perfect_slugs
    @perfect_slugs ||= attempts.select { |a| a.score.to_f >= PERFECT_SCORE }.map(&:test_slug).uniq
  end

  def correct_answers_count
    @correct_answers_count ||= begin
      ids = attempts.map(&:id)
      ids.empty? ? 0 : TestAttemptAnswer.where(attempt_id: ids, correct: true).count
    end
  end

  # Сколько разных тестов каждого уровня пройдено на PASS_SCORE и выше.
  def level_counts
    @level_counts ||= begin
      slugs = attempts.select { |a| a.score.to_f >= PASS_SCORE }.map(&:test_slug).uniq
      slugs.empty? ? {} : TestMetadatum.where(slug: slugs).group(:difficulty).count
    end
  end

  def speedrun?
    limits = estimated_times

    attempts.any? do |attempt|
      estimated = limits[attempt.test_slug]
      next false if estimated.to_i.zero? || attempt.time_spent.to_i.zero?

      attempt.score.to_f >= SPEEDRUN_SCORE &&
        attempt.time_spent <= estimated * 60 * SPEEDRUN_FACTOR
    end
  end

  def code_runner?
    return false if passed_slugs.empty?

    TestMetadatum.where(slug: passed_slugs, has_code_challenge: true).exists?
  end

  # Улучшение результата по одному и тому же тесту: попытки идут по времени,
  # поэтому достаточно сравнивать каждую с худшей среди предыдущих.
  def comeback?
    attempts.group_by(&:test_slug).any? do |_slug, list|
      worst = nil

      list.any? do |attempt|
        score  = attempt.score.to_f
        gained = worst && (score - worst) >= COMEBACK_GAIN
        worst  = [ worst, score ].compact.min
        gained
      end
    end
  end

  def weak_trainings_count
    @weak_trainings_count ||= user.test_attempts
      .where.not(completed_at: nil)
      .where(weak_only: true)
      .count
  end

  def bookmarks_count
    @bookmarks_count ||= user.bookmarks.count
  end

  # Самая длинная серия дней подряд с хотя бы одним пройденным тестом.
  def longest_streak
    @longest_streak ||= begin
      days = attempts.map { |a| a.completed_at.in_time_zone.to_date }.uniq.sort
      best = current = 0
      previous = nil

      days.each do |day|
        current  = previous && day == previous + 1 ? current + 1 : 1
        best     = current if current > best
        previous = day
      end

      best
    end
  end

  private

  attr_reader :user

  def estimated_times
    @estimated_times ||= passed_slugs.empty? ? {} :
      TestMetadatum.where(slug: passed_slugs).pluck(:slug, :estimated_time).to_h
  end
end
