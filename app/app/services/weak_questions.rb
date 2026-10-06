# Вопросы, которые пользователю стоит проработать: те, где он ошибался и ещё
# не показал, что тему закрыл.
#
# Отдельной таблицы нет — всё считается по test_attempt_answers. Ключевое
# правило: учитываются только последние ATTEMPTS_WINDOW попыток по каждому
# вопросу, и вопрос пропадает из списка после STREAK_TO_CLEAR верных ответов
# подряд. Иначе список копил бы ошибки за всю историю и никогда не очищался
# по мере обучения.
class WeakQuestions
  ATTEMPTS_WINDOW = 5
  STREAK_TO_CLEAR = 2

  Entry = Struct.new(:question_id, :test_slug, :wrong_count, :last_wrong_at, keyword_init: true)

  def self.for(user: nil, guest_token: nil, test_slug: nil)
    new(user: user, guest_token: guest_token, test_slug: test_slug)
  end

  def initialize(user: nil, guest_token: nil, test_slug: nil)
    @user       = user
    @guest_token = guest_token
    @test_slug  = test_slug
  end

  # Слабые вопросы, самые проблемные первыми.
  def entries
    @entries ||= grouped_answers.filter_map { |(question_id, slug), answers| build_entry(question_id, slug, answers) }
                                .sort_by { |e| [ -e.wrong_count, -e.last_wrong_at.to_i ] }
  end

  def question_ids
    entries.map(&:question_id)
  end

  # Вопросы, которые были слабыми и закрыты: когда-то отвечены неверно, а
  # последние STREAK_TO_CLEAR ответов подряд — верные. Это ровно те, что ушли
  # из entries по правилу самоочистки, и именно их считает ачивка
  # «Работа над ошибками».
  #
  # Отдельной таблицы под это нет, поэтому смотрим всю историю ответов по
  # вопросу, а не окно: окно отвечает на вопрос «слаб ли он сейчас», а здесь
  # нужно «была ли ошибка когда-либо».
  def fixed_count
    @fixed_count ||= grouped_answers.count do |(_question_id, _slug), answers|
      streak = answers.first(STREAK_TO_CLEAR)

      streak.size == STREAK_TO_CLEAR &&
        streak.all? { |_id, _slug, correct, _at| correct } &&
        answers.any? { |_id, _slug, correct, _at| !correct }
    end
  end

  def any?
    entries.any?
  end

  private

  # Ответы пользователя, сгруппированные по вопросу; внутри группы — от
  # свежих к старым, чтобы окно и серия считались от последней попытки.
  def grouped_answers
    return {} unless @user || @guest_token.present?

    scope = @user ? TestAttempt.where(user_id: @user.id) : TestAttempt.where(guest_token: @guest_token)
    scope = scope.where(test_slug: @test_slug) if @test_slug

    # Только живые тесты. Ошибки по удалённому тесту остаются в истории, но
    # показать их нечем: вопросов в YAML больше нет, и список «частых ошибок»
    # вырождался в голые q4/q13, а ссылка вела на несуществующий тест.
    # Ответы при этом не трогаем — вернётся тест, вернутся и его слабые вопросы.
    scope = scope.where(test_slug: TestMetadatum.active.select(:slug))

    TestAttemptAnswer
      .joins(:test_attempt)
      .merge(scope)
      .order(created_at: :desc)
      .pluck(:question_id, "test_attempts.test_slug", :correct, :created_at)
      .group_by { |question_id, slug, _correct, _at| [ question_id, slug ] }
  end

  def build_entry(question_id, slug, answers)
    recent = answers.first(ATTEMPTS_WINDOW)

    # Тема закрыта: последние ответы подряд верные.
    return nil if recent.first(STREAK_TO_CLEAR).size == STREAK_TO_CLEAR &&
                  recent.first(STREAK_TO_CLEAR).all? { |_id, _slug, correct, _at| correct }

    wrong = recent.reject { |_id, _slug, correct, _at| correct }
    return nil if wrong.empty?

    Entry.new(
      question_id:   question_id,
      test_slug:     slug,
      wrong_count:   wrong.size,
      last_wrong_at: wrong.first.last
    )
  end
end
