# Сильные темы пользователя — зеркало WeakTopicsSummary: темы, где ответы
# стабильно верные, а не только отсутствие ошибок.
#
# Считается по окну последних ANSWERS_WINDOW ответов ПО ТЕМЕ (не по вопросу,
# как в WeakQuestions — тема шире одного вопроса). Без окна старые ошибки
# тянули бы долю вниз навсегда: скажем, 10 ошибок в начале и дальше только
# верные ответы всё равно дают долю < 80% ещё очень долго, хотя тема давно
# освоена. Окно даёт статистике забывать прошлое по мере накопления свежих
# ответов — как и у слабых тем, где вопрос закрывается уже после 2 верных
# подряд, а не когда исчезнут все прежние ошибки.
#
# Тема не может быть одновременно слабой и сильной: если по ней есть текущие
# ошибки (WeakTopicsSummary), она остаётся только в слабых — иначе кабинет
# показывал бы противоречивую картину по одной теме.
class StrongTopicsSummary
  ANSWERS_WINDOW   = 10
  MIN_ANSWERS      = 3
  MIN_CORRECT_RATE = 0.8

  Entry = Struct.new(:slug, :label, :description, :color, :correct_count, :total_count, keyword_init: true) do
    def to_h
      { slug: slug, label: label, description: description, color: color,
        correct_count: correct_count, total_count: total_count }
    end
  end

  def self.for(user: nil, guest_token: nil, exclude_slugs: [])
    new(user: user, guest_token: guest_token, exclude_slugs: exclude_slugs)
  end

  def initialize(user: nil, guest_token: nil, exclude_slugs: [])
    @user          = user
    @guest_token   = guest_token
    @exclude_slugs = exclude_slugs.to_a
  end

  # Темы с лучшим результатом первыми.
  def entries
    @entries ||= begin
      correct, total = aggregate

      total.filter_map { |slug, count|
        next if count < MIN_ANSWERS
        next if @exclude_slugs.include?(slug)

        rate = correct[slug].to_f / count
        next if rate < MIN_CORRECT_RATE

        topic = TopicDictionary.find(slug)
        Entry.new(
          slug:          slug,
          label:         topic&.label || slug,
          description:   topic&.description,
          color:         topic&.color,
          correct_count: correct[slug],
          total_count:   count
        )
      }.sort_by { |e| [ -(e.correct_count.to_f / e.total_count), -e.total_count ] }
    end
  end

  def any?
    entries.any?
  end

  private

  # Ответы по теме берутся от свежих к старым и обрезаются окном — старые
  # ошибки, вытесненные за окно, на итог уже не влияют.
  def aggregate
    questions_cache = {}
    by_topic = Hash.new { |h, k| h[k] = [] }

    answers.each do |question_id, slug, was_correct|
      cache = questions_cache[slug] ||= YamlSyncService.load_questions(slug).index_by { |q| q["id"] }

      Array(cache[question_id]&.fetch("topics", nil)).each do |topic|
        by_topic[topic.to_s] << was_correct
      end
    end

    correct = Hash.new(0)
    total   = Hash.new(0)

    by_topic.each do |topic, results|
      windowed = results.first(ANSWERS_WINDOW)
      total[topic]   = windowed.size
      correct[topic] = windowed.count(true)
    end

    [ correct, total ]
  end

  # Свежие ответы первыми — от них отсчитывается окно в #aggregate.
  def answers
    return [] unless @user || @guest_token.present?

    scope = @user ? TestAttempt.where(user_id: @user.id) : TestAttempt.where(guest_token: @guest_token)

    TestAttemptAnswer
      .joins(:test_attempt)
      .merge(scope)
      .order(created_at: :desc)
      .pluck(:question_id, "test_attempts.test_slug", :correct)
  end
end
