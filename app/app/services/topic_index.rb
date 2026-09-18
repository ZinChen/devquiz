# Обратный индекс «тема → тесты и вопросы, где она встречается».
#
# topics живут в YAML вопросов, а не в БД, поэтому поиск тестов по теме иначе
# потребовал бы читать все файлы на каждый запрос. Индекс строится один раз и
# кэшируется; в разработке пересобирается, чтобы правки в файлах были видны
# без перезапуска.
class TopicIndex
  class << self
    def current
      if Rails.env.development?
        build
      else
        @current ||= build
      end
    end

    def reload!
      @current = nil
      current
    end

    delegate :tests_for, :question_ids_for, :topics_of, to: :current

    private

    def build
      new(TestSource.files_by_slug)
    end
  end

  # entries: { slug => { path:, ... } } из TestSource — победитель по каждому
  # слагу уже выбран, поэтому переопределённый тест не попадёт в индекс дважды.
  def initialize(entries)
    # { "mvc" => { "ror-basics" => ["q1", "q2"] } }
    by_topic = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

    entries.each do |slug, entry|
      path = entry[:path]

      data = begin
        YAML.safe_load(File.read(path), permitted_classes: [ Symbol ])
      rescue StandardError
        nil
      end
      next unless data.is_a?(Hash)

      Array(data["questions"]).each do |question|
        Array(question["topics"]).each do |topic|
          by_topic[topic.to_s][slug] << question["id"].to_s
        end
      end
    end

    # Hash#to_h на хэше возвращает его же — вместе с default_proc, который
    # при первом же промахе пытается писать в замороженный хэш. Копируем
    # содержимое в чистые хэши, чтобы чтение отсутствующего ключа было
    # безопасным.
    @by_topic = by_topic.each_with_object({}) { |(topic, tests), acc|
      acc[topic] = tests.each_with_object({}) { |(slug, ids), inner| inner[slug] = ids.freeze }.freeze
    }.freeze

    freeze
  end

  # Слаги тестов, где есть вопросы по теме — больше вопросов, выше в списке.
  def tests_for(topic)
    question_ids_for(topic).sort_by { |_slug, ids| -ids.size }.map(&:first)
  end

  # { "ror-basics" => ["q1", "q2"] } — вопросы темы по тестам.
  def question_ids_for(topic)
    @by_topic.fetch(topic.to_s, {})
  end

  def topics_of(test_slug)
    @by_topic.select { |_topic, tests| tests.key?(test_slug.to_s) }.keys
  end
end
