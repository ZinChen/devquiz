# Проверка и выдача ачивок. Вызывается после завершения теста
# (RunsController#create), после переноса гостевой истории при логине
# (SessionsController) и при добавлении закладки (BookmarksController).
#
# Условия считаются по фактической истории (см. AchievementFacts), а не
# инкрементом счётчиков: так выдача идемпотентна и переживает бэкфилл, правку
# правил и перенос гостевых попыток. Часть условий счётчиком и не выражается —
# серия по дням, улучшение результата.
class AchievementsService
  def self.call(user)
    new(user).call
  end

  def initialize(user, facts: nil)
    @user  = user
    @facts = facts
  end

  # Возвращает свежевыданные Achievement в порядке каталога — вызывающий
  # решает, показать их блоком на странице результата или строкой в приветствии.
  def call
    return [] if user.blank?

    pending = AchievementsCatalog.entries.reject { |entry| earned_slugs.include?(entry.slug) }
    return [] if pending.empty?

    grant(pending.select { |entry| satisfied?(entry) })
  end

  private

  attr_reader :user

  def facts
    @facts ||= AchievementFacts.new(user)
  end

  def earned_slugs
    @earned_slugs ||= Achievement
      .joins(:user_achievements)
      .where(user_achievements: { user_id: user.id })
      .pluck(:slug)
      .to_set
  end

  # Ачивка с порогом — сравнение с фактом, без порога — флаг. Незнакомый слаг
  # без порога не выдаётся никогда: правило для него просто не написано, и
  # выдать его «на всякий случай» хуже, чем не выдать.
  def satisfied?(entry)
    if entry.threshold.present?
      value = facts.value_for(entry)
      value.present? && value >= entry.threshold
    else
      facts.flag_for(entry.slug) == true
    end
  end

  def grant(entries)
    return [] if entries.empty?

    records = Achievement.where(slug: entries.map(&:slug)).index_by(&:slug)
    granted = entries.filter_map { |entry| award(records[entry.slug]) }

    # Счётчик для бейджа на аватарке (#10) — денормализован намеренно, см.
    # миграцию. increment! меняет и базу атомарно, и объект в памяти.
    user.increment!(:achievements_count, granted.size) if granted.any?

    granted
  end

  # Уникальный индекс в базе — последняя линия защиты: сервис может
  # сработать дважды одновременно (завершение теста и логин в двух вкладках).
  def award(achievement)
    return nil if achievement.nil?

    UserAchievement.create!(user: user, achievement: achievement, earned_at: Time.current)
    achievement
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil
  end
end
