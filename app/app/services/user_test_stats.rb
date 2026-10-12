# Личная статистика пользователя по тестам: сколько раз прошёл, лучший
# результат и какая попытка его дала.
#
# Это единственный источник цифр про прохождения на карточках и странице теста.
# Раньше там лежали общие счётчики из test_metadata (attempts_count, best_score,
# best_attempt_id…): они считаются по всем пользователям, и гость видел чужие
# результаты — вместе со ссылкой на чужую страницу разбора. Общие счётчики
# остаются в БД для рейтинга (StatsController) и сортировки списка, но на
# страницы с личными данными не попадают.
#
# Разбор ошибок (weak_only) не считается — как и в общей статистике теста
# (см. RunsController#update_test_stats): это тренировка по части вопросов.
class UserTestStats
  Stat = Struct.new(:attempts_count, :best_score, :best_attempt_id, :avg_score, keyword_init: true)

  EMPTY = Stat.new(attempts_count: 0, best_score: nil, best_attempt_id: nil, avg_score: 0.0).freeze

  # { slug => Stat }. Для гостя и для тестов без попыток — EMPTY.
  def self.for(user, slugs)
    return Hash.new(EMPTY) unless user

    rows = TestAttempt
      .where(user_id: user.id, test_slug: slugs, weak_only: false)
      .where.not(completed_at: nil)
      .order(score: :desc, id: :asc)
      .pluck(:test_slug, :id, :score)

    stats = rows.group_by(&:first).transform_values do |attempts|
      best = attempts.first
      scores = attempts.map { |(_, _, score)| score.to_f }
      Stat.new(
        attempts_count:  attempts.size,
        best_score:      best[2].to_f,
        best_attempt_id: best[1],
        avg_score:       (scores.sum / scores.size).round(2)
      )
    end

    Hash.new(EMPTY).merge!(stats)
  end
end
