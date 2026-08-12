# Структура над плоским списком тегов из tests/*.yml.
#
# Теги в тестах — просто строки через запятую (см. TestMetadatum#tag_list),
# иерархии в базе нет. Она описана в config/tag_taxonomy.yml и живёт здесь:
# темы (categories) с подтегами пользователь выбирает как интересные ему,
# служебные (service) — метаданные вроде источника теста, которые в выборе
# предпочтений не участвуют.
class TagTaxonomy
  CONFIG_PATH = Rails.root.join("config", "tag_taxonomy.yml")

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

    delegate :categories, :category_tags, :service, :service_tags, :kind_of,
             :children_of, :selectable?, :known_tags, :sanitize,
             :descriptions, :description_of, to: :current

    private

    def load_config
      raw = YAML.safe_load(File.read(CONFIG_PATH)) || {}
      new(raw)
    end
  end

  attr_reader :categories, :service, :category_tags, :service_tags, :known_tags, :descriptions

  def initialize(raw)
    # Всё считается в конструкторе, а не лениво: объект замораживается, чтобы
    # закэшированный в проде экземпляр нельзя было случайно мутировать.
    #
    # children в yml — словарь { тег => описание }, поэтому порядок сохраняется,
    # а описание лежит рядом с тегом и не может от него оторваться.
    @categories = (raw["categories"] || {}).map { |tag, cfg|
      cfg ||= {}
      {
        tag:         tag,
        title:       cfg["title"].presence || tag.titleize,
        description: cfg["description"].presence,
        children:    (cfg["children"] || {}).keys.freeze
      }.freeze
    }.freeze

    # { "hh" => "source", "backend" => "broad", ... }
    @service = (raw["service"] || {}).each_with_object({}) { |(kind, tags), acc|
      (tags || {}).each_key { |tag| acc[tag] = kind }
    }.freeze

    # Описание любого тега — категории, подтега или служебного — в одном месте.
    @descriptions = {}.tap { |acc|
      (raw["categories"] || {}).each do |tag, cfg|
        cfg ||= {}
        acc[tag] = cfg["description"].presence
        (cfg["children"] || {}).each { |child, text| acc[child] = text.presence }
      end
      (raw["service"] || {}).each_value do |tags|
        (tags || {}).each { |tag, text| acc[tag] = text.presence }
      end
    }.compact.freeze

    @category_tags = @categories.map { |c| c[:tag] }.freeze
    @service_tags  = @service.keys.freeze
    @known_tags    = (@category_tags + @categories.flat_map { |c| c[:children] } + @service_tags).uniq.freeze

    freeze
  end

  # Описание тега для подсказки при наведении; nil, если тег незнакомый.
  def description_of(tag)
    descriptions[tag.to_s]
  end

  # "source" / "level" / "broad" для служебного тега, nil для тематического.
  def kind_of(tag)
    service[tag.to_s]
  end

  def children_of(tag)
    categories.find { |c| c[:tag] == tag.to_s }&.fetch(:children) || []
  end

  # Служебные теги (источник, уровень) не предлагаются как предпочтения.
  def selectable?(tag)
    !service.key?(tag.to_s)
  end

  # Предпочтения приходят из браузера, поэтому в хранилище попадают только
  # теги, реально объявленные в таксономии и доступные для выбора.
  def sanitize(tags)
    Array(tags).map(&:to_s).uniq.select { |tag| known_tags.include?(tag) && selectable?(tag) }
  end
end
