# Каталог ачивок из config/achievements.yml: метаданные (название, иконка,
# группа-лесенка, порог) отдельно от условий выдачи, которые живут в
# AchievementsService.
#
# Синхронизируется в базу через rake achievements:sync — так же, как тесты из
# tests/: YAML остаётся источником правды, база хранит id, на которые
# ссылаются user_achievements.
class AchievementsCatalog
  CONFIG_PATH = Rails.root.join("config/achievements.yml")

  Entry = Struct.new(:slug, :title, :description, :icon, :group, :threshold, :shareable, :position, keyword_init: true)

  # Цвет, которым красится подложка иконки, когда в yml его не задали.
  DEFAULT_COLOR = { "bg" => "#F3F4F6", "fg" => "#6B7280" }.freeze
  SINGLES_KEY   = "singles".freeze

  class << self
    # В разработке файл перечитывается на каждый запрос, чтобы правки в yml
    # были видны без перезапуска; в проде читается один раз. Тот же приём,
    # что в TopicDictionary.
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

    delegate :entries, :slugs, :find, :color_for, to: :current

    # YAML → база. Новые ачивки создаются, изменившиеся обновляются, лишние
    # (выпавшие из каталога) удаляются вместе с выдачами — иначе кабинет
    # показывал бы ачивку, которой больше нет в правилах.
    #
    # Возвращает сводку для rake-задачи.
    def sync!
      created = updated = 0

      entries.each do |entry|
        record = Achievement.find_or_initialize_by(slug: entry.slug)
        new_record = record.new_record?

        record.assign_attributes(
          title:       entry.title,
          description: entry.description,
          icon:        entry.icon,
          group_name:  entry.group,
          threshold:   entry.threshold,
          shareable:   entry.shareable,
          position:    entry.position
        )

        next unless record.changed?

        record.save!
        new_record ? created += 1 : updated += 1
      end

      removed = Achievement.where.not(slug: slugs).destroy_all.size
      # Выдачи удалённых ачивок ушли каскадом — счётчики у затронутых
      # пользователей теперь врут, поэтому пересчитываем их целиком.
      recount_users! if removed.positive?

      { created: created, updated: updated, removed: removed, total: Achievement.count }
    end

    # Пересчёт денормализованного users.achievements_count. Инкремент при
    # выдаче — основной путь, но он разъезжается с фактом после бэкфилла,
    # правки условий или удаления ачивки из каталога, и сам не лечится.
    def recount_users!
      counts = UserAchievement.group(:user_id).count

      User.find_each do |user|
        actual = counts[user.id].to_i
        user.update_column(:achievements_count, actual) if user.achievements_count != actual
      end
    end

    private

    def load_config
      raw = YAML.safe_load(File.read(CONFIG_PATH)) || {}
      new(raw)
    rescue Errno::ENOENT
      new({})
    end
  end

  attr_reader :entries, :colors

  def initialize(raw)
    @colors = (raw["colors"] || {}).transform_values(&:freeze).freeze
    @entries = (raw["achievements"] || {}).map { |slug, cfg|
      cfg ||= {}
      Entry.new(
        slug:        slug.to_s,
        title:       cfg["title"].presence || slug.to_s.titleize,
        description: cfg["description"].presence,
        icon:        cfg["icon"].presence,
        group:       cfg["group"].presence,
        threshold:   cfg["threshold"],
        # По умолчанию ачивка видна другим: закрываются только те, что
        # раскрывают поведение, и они помечены явно.
        shareable:   cfg.fetch("shareable", true),
        position:    cfg["position"].to_i
      ).freeze
    }.sort_by(&:position).freeze

    @by_slug = @entries.index_by(&:slug).freeze

    freeze
  end

  def slugs
    entries.map(&:slug)
  end

  def find(slug)
    @by_slug[slug.to_s]
  end

  # У одиночных ачивок группы нет — им отдаётся общий цвет, иначе каждая
  # красилась бы серым по умолчанию и выпадала из общей палитры.
  def color_for(group)
    colors[group.presence || SINGLES_KEY] || colors[SINGLES_KEY] || DEFAULT_COLOR
  end
end
