# Ачивки за мастерство в теме: «Знаток запросов к БД» → «Эксперт» → «Гуру».
#
# В config/achievements.yml их нет: тем 38 и список растёт вместе с
# tests/topics.yml, поэтому записи собираются из словаря тем на лету и
# попадают в каталог наравне с остальными (см. AchievementsCatalog#initialize).
#
# Считается по topics вопроса, а не по тегам теста: тег описывает тест целиком,
# и «50 верных ответов в тестах с тегом ruby» засчитало бы вопросы про
# алгоритмы и SQL, которые там тоже есть. Тема же стоит на самом вопросе —
# на ней держатся слабые места, тренировки и рекомендации.
class TopicAchievements
  # Тема попадает в ачивки, только если вопросов по ней хватает на первую
  # ступень с запасом. Иначе каталог наполняется недостижимыми целями: по
  # caching и background-jobs в репозитории 2 вопроса.
  MIN_POOL = 20

  # Ступени: порог — число уникальных вопросов темы, отвеченных верно.
  TIERS = [
    { key: "known",  title: "Знаток",  threshold: 10, icon: "📙" },
    { key: "expert", title: "Эксперт", threshold: 25, icon: "📔" },
    { key: "guru",   title: "Гуру",    threshold: 50, icon: "🏅" }
  ].freeze

  POSITION_BASE = 100

  class << self
    # Записи каталога — по одной на ступень каждой подходящей темы. Ступень,
    # которой не хватает вопросов, не создаётся вовсе: «Гуру» по теме из 20
    # вопросов недостижим, и показывать его как цель нечестно.
    #
    # TopicIndex.current пересобирается в development на каждое обращение
    # (полное сканирование tests/*.yml) — снимок берём один раз и передаём
    # дальше, а не зовём TopicIndex.question_ids_for в цикле по 38 темам,
    # где каждый вызов заново пересобирал бы индекс.
    def entries(topic_index: TopicIndex.current)
      topics(topic_index: topic_index).flat_map.with_index do |(slug, label, pool), index|
        TIERS.filter_map.with_index do |tier, tier_index|
          next if tier[:threshold] > pool

          {
            slug:        achievement_slug(slug, tier[:key]),
            title:       "#{tier[:title]}: #{label}",
            description: "#{tier[:threshold]} вопросов темы отвечены верно",
            icon:        tier[:icon],
            group:       group_for(slug),
            threshold:   tier[:threshold],
            shareable:   true,
            position:    POSITION_BASE + index * TIERS.size + tier_index
          }
        end
      end
    end

    # Группа-лесенка на тему: ступени сворачиваются в одну плитку, как и
    # остальные группы.
    def group_for(topic_slug)
      "topic_#{topic_slug}"
    end

    # Слаг темы из имени группы — по нему AchievementFacts понимает, что
    # считать. Возвращает nil для групп, которые к темам отношения не имеют.
    def topic_of(group_name)
      group_name.to_s.delete_prefix("topic_").presence if group_name.to_s.start_with?("topic_")
    end

    # Темы, по которым вообще заводятся ачивки: есть в словаре и набирают
    # MIN_POOL вопросов в текущем каталоге тестов.
    def topics(topic_index: TopicIndex.current)
      TopicDictionary.topics.filter_map do |slug, topic|
        pool = pool_size(slug, topic_index: topic_index)
        [ slug, topic.label, pool ] if pool >= MIN_POOL
      end.sort_by { |_slug, _label, pool| -pool }
    end

    def pool_size(topic_slug, topic_index: TopicIndex.current)
      topic_index.question_ids_for(topic_slug).values.sum(&:size)
    end

    private

    def achievement_slug(topic_slug, tier_key)
      "topic_#{topic_slug}_#{tier_key}"
    end
  end
end
