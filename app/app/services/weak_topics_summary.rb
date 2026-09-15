# Слабые темы пользователя по всей его истории — для кабинета.
#
# В отчёте после теста темы считаются по одной попытке; здесь берётся картина
# целиком: слабые вопросы из WeakQuestions (то есть уже с учётом окна попыток
# и самоочистки после верных ответов) группируются по topics вопроса.
#
# Темы вопроса живут в YAML, а не в БД, поэтому файлы читаются через
# YamlSyncService с кэшем на слаг: у пользователя обычно немного тестов.
class WeakTopicsSummary
  HIGH_LEVEL   = 3
  MEDIUM_LEVEL = 2

  # sources — из каких тестов набралась тема: [{ slug:, title:, wrong_count: }].
  Entry = Struct.new(:slug, :label, :description, :color, :wrong_count, :level, :sources, keyword_init: true) do
    def to_h
      { slug: slug, label: label, description: description, color: color,
        wrong_count: wrong_count, level: level, sources: sources }
    end
  end

  def self.for(user: nil, guest_token: nil)
    new(user: user, guest_token: guest_token)
  end

  def initialize(user: nil, guest_token: nil)
    @user        = user
    @guest_token = guest_token
  end

  # Темы с числом ошибок, самые проблемные первыми.
  def entries
    @entries ||= begin
      counts, sources = aggregate

      counts.map { |slug, count|
        topic = TopicDictionary.find(slug)
        Entry.new(
          slug:        slug,
          label:       topic&.label || slug,
          description: topic&.description,
          color:       topic&.color,
          wrong_count: count,
          level:       level_for(count),
          sources:     sources_for(sources[slug])
        )
      }.sort_by { |e| [ -e.wrong_count, e.label ] }
    end
  end

  def slugs
    entries.map(&:slug)
  end

  def any?
    entries.any?
  end

  private

  # Один проход по слабым вопросам даёт и счётчики по темам, и разбивку
  # по тестам: { "mvc" => 4 }, { "mvc" => { "ror-basics" => 3 } }.
  def aggregate
    questions_cache = {}
    counts  = Hash.new(0)
    sources = Hash.new { |h, k| h[k] = Hash.new(0) }

    weak_entries.each do |entry|
      cache = questions_cache[entry.test_slug] ||=
        YamlSyncService.load_questions(entry.test_slug).index_by { |q| q["id"] }

      Array(cache[entry.question_id]&.fetch("topics", nil)).each do |topic|
        counts[topic.to_s] += entry.wrong_count
        sources[topic.to_s][entry.test_slug] += entry.wrong_count
      end
    end

    [ counts, sources ]
  end

  # Названия тестов подтягиваем одним запросом на весь отчёт.
  def sources_for(by_slug)
    return [] if by_slug.blank?

    titles = test_titles
    by_slug.sort_by { |_slug, count| -count }.map do |slug, count|
      { slug: slug, title: titles[slug] || slug, wrong_count: count }
    end
  end

  def test_titles
    @test_titles ||= TestMetadatum.where(slug: weak_entries.map(&:test_slug).uniq)
                                  .pluck(:slug, :title).to_h
  end

  def weak_entries
    WeakQuestions.for(user: @user, guest_token: @guest_token).entries
  end

  def level_for(count)
    case count
    when HIGH_LEVEL..  then "high"
    when MEDIUM_LEVEL  then "medium"
    else                    "low"
    end
  end
end
