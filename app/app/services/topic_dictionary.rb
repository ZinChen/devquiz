# Словарь тем из tests/topics.yml: человеческое название, описание и цвет для
# слага, который стоит в поле topics: у вопроса.
#
# Слаги (mvc, indexes) удобны в YAML, но в отчёте о слабых местах нужны
# «MVC & Request lifecycle» и цвет. Незнакомый слаг не ошибка: тема просто
# показывается как есть, чтобы отчёт не разваливался из-за опечатки в тесте.
class TopicDictionary
  CONFIG_PATH = YamlSyncService::TESTS_DIR.join("topics.yml")

  Topic = Struct.new(:slug, :label, :description, :color, keyword_init: true)

  class << self
    # В разработке файл перечитывается на каждый запрос, чтобы правки в yml
    # были видны без перезапуска; в проде читается один раз.
    def current
      if Rails.env.development?
        load_config
      else
        @current ||= load_config
      end
    end

    def reload!
      @current = nil
      current
    end

    delegate :topics, :slugs, :known?, :find, :label_for, :decorate, to: :current

    private

    def load_config
      raw = YAML.safe_load(File.read(CONFIG_PATH)) || {}
      new(raw)
    rescue Errno::ENOENT
      new({})
    end
  end

  attr_reader :topics

  def initialize(raw)
    @topics = (raw["topics"] || {}).each_with_object({}) { |(slug, cfg), acc|
      cfg ||= {}
      acc[slug.to_s] = Topic.new(
        slug:        slug.to_s,
        label:       cfg["label"].presence || slug.to_s.titleize,
        description: cfg["description"].presence,
        color:       cfg["color"].presence
      ).freeze
    }.freeze

    freeze
  end

  def slugs
    topics.keys
  end

  def known?(slug)
    topics.key?(slug.to_s)
  end

  def find(slug)
    topics[slug.to_s]
  end

  def label_for(slug)
    find(slug)&.label || slug.to_s
  end

  # Слаги тем -> данные для отрисовки. Неизвестные не отбрасываем: слаг
  # становится подписью, цвета и описания просто не будет.
  def decorate(slugs)
    Array(slugs).map { |slug| find(slug) || Topic.new(slug: slug.to_s, label: slug.to_s) }
  end
end
