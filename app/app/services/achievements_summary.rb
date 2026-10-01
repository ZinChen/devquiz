# Ачивки пользователя в том виде, в каком их показывает кабинет.
#
# Главное здесь — сворачивание лесенок: ступени одной группы («Первый шаг» →
# «На разгоне» → «Половина пути» → «Знаток каталога») показываются одной
# плиткой с текущей ступенью и прогрессом до следующей. Иначе профиль
# превращается в стену из десятка плиток, где девять — уже пройденные ступени
# одного и того же.
class AchievementsSummary
  RECENT_LIMIT = 5

  def self.for(user:)
    new(user: user)
  end

  def initialize(user:)
    @user = user
  end

  # Счёт идёт по плиткам, а не по ступеням каталога: под шапкой «6 из 13»
  # лежат ровно 13 плиток, и число совпадает с тем, что человек видит. Счёт по
  # ступеням давал бы «15 из 28» над тринадцатью карточками — формально верно,
  # но читается как ошибка. Детализация по ступеням осталась в бейдже 3/4 на
  # самой плитке.
  def to_props
    {
      earned_count: items.count { |item| item[:earned] },
      total_count:  items.size,
      items:        items,
      recent:       recent
    }
  end

  # Ачивки этого пользователя так, как их увидит кто-то другой — бейдж на
  # аватарке в live-активности (#10). Отличий от своего вида три, и все
  # намеренные: только полученные (чужие цели никому не интересны), только
  # shareable (часть ачивок раскрывает поведение, а не результат), без даты
  # получения и без прогресса — по ним восстанавливается график активности,
  # который человек мог как раз и не хотеть показывать.
  #
  # Фильтр по самому флагу видимости пользователя остаётся вызывающему: это
  # его решение, кого он вообще показывает.
  def to_public_props
    shareable = Achievement.shareable.ordered.where(slug: earned_at_by_slug.keys)

    {
      count: shareable.size,
      items: shareable.map do |a|
        {
          slug:        a.slug,
          title:       a.title,
          description: a.description,
          icon:        a.icon,
          color:       AchievementsCatalog.color_for(a.group_name),
          earned:      true
        }
      end
    }
  end

  # Плитки: по одной на группу-лесенку и по одной на каждую одиночную ачивку.
  def items
    @items ||= grouped_entries.map { |key, tiers| tile_for(key, tiers) }
  end

  # Последние полученные — для компактной полоски на вкладке «Тесты».
  #
  # Отдаются теми же полями, что и плитки профиля: мини-карточка показывает
  # прогресс и ступень, отличаясь от большой только отсутствием описания.
  # Прогресс берётся из плитки группы, а не считается заново — иначе два места
  # показывали бы одно и то же число по-разному.
  def recent
    @recent ||= begin
      tiles_by_slug = items.index_by { |item| item[:slug] }

      user.user_achievements
        .includes(:achievement)
        .recent_first
        .limit(RECENT_LIMIT)
        .map do |ua|
          achievement = ua.achievement
          tile = tiles_by_slug[achievement.slug]

          {
            slug:      achievement.slug,
            title:     achievement.title,
            icon:      achievement.icon,
            color:     AchievementsCatalog.color_for(achievement.group_name),
            # В полоске все карточки по определению получены — поле нужно
            # компоненту, он по нему решает, зажигать ли цвет подложки.
            earned:    true,
            earned_at: ua.earned_at,
            tier:      tile&.dig(:tier),
            progress:  tile&.dig(:progress)
          }
        end
    end
  end

  private

  attr_reader :user

  def facts
    @facts ||= AchievementFacts.new(user)
  end

  def earned_at_by_slug
    @earned_at_by_slug ||= user.user_achievements
      .joins(:achievement)
      .pluck("achievements.slug", :earned_at)
      .to_h
  end

  # Ключ плитки — имя группы либо слаг одиночной ачивки. Порядок каталога
  # сохраняется: entries уже отсортированы по position.
  def grouped_entries
    AchievementsCatalog.entries.group_by { |entry| entry.group.presence || entry.slug }
  end

  def tile_for(key, tiers)
    earned_tiers = tiers.select { |t| earned_at_by_slug.key?(t.slug) }
    # Текущая ступень — последняя взятая; пока ничего не взято, плитка
    # показывает первую как цель.
    current = earned_tiers.last || tiers.first
    next_up = tiers.find { |t| !earned_at_by_slug.key?(t.slug) }

    {
      key:         key,
      slug:        current.slug,
      title:       current.title,
      description: current.description,
      icon:        current.icon,
      color:       AchievementsCatalog.color_for(current.group),
      earned:      earned_tiers.any?,
      earned_at:   earned_at_by_slug[current.slug],
      tier:        tiers.size > 1 ? { index: earned_tiers.size, total: tiers.size } : nil,
      progress:    progress_for(next_up)
    }
  end

  # Прогресс есть только у ачивок со счётным условием и только пока есть
  # следующая ступень. У бинарных (speedrun, code_runner, comeback) порога нет,
  # и показывать «0 / 1» вместо условия бессмысленно.
  def progress_for(next_up)
    return nil if next_up.nil? || next_up.threshold.blank?

    value = facts.value_for(next_up)
    return nil if value.nil?

    {
      current:    [ value, next_up.threshold ].min,
      target:     next_up.threshold,
      next_title: next_up.title
    }
  end
end
