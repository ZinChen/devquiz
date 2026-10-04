class TestsController < ApplicationController
  CODE_TAG   = "code"
  CUSTOM_TAG = "custom"

  def index
    tests_list = TestMetadatum.active.order(attempts_count: :desc).to_a
    total = tests_list.size
    tag_counts = tests_list.flat_map { |t| tags_for(t) }.tally
    visible_tags = tag_counts
      .reject { |_, count| count == total }
      .sort_by { |_, count| -count }
      .map(&:first)

    completed_modes_by_slug = user_completed_modes(tests_list.map(&:slug))
    # Один снимок на весь список, а не TopicIndex.topics_of в цикле: в
    # development индекс пересобирается (читает все tests/*.yml) на каждое
    # обращение к классовому методу — 43 вызова означали бы 43 пересборки.
    topic_index = TopicIndex.current

    render inertia: "Tests/Index", props: {
      tests: tests_list.map { |t|
        test_props(t, completed_modes_by_slug[t.slug] || [], topic_index)
      },
      all_tags: visible_tags,
      # nil (а не []) означает, что экран выбора ещё не показывали.
      preferred_tags:      preferred_tags,
      tag_categories:      TagTaxonomy.categories,
      tag_descriptions:    TagTaxonomy.descriptions,
      show_tag_onboarding: show_tag_onboarding?
    }
  end

  def show
    test = TestMetadatum.find_by!(slug: params[:slug])
    render inertia: "Tests/Show", props: { test: test_props(test) }
  end

  private

  # Экран выбора тем показывается всем, кто ещё не выбирал, включая гостей:
  # выбор гостя хранится в куке и переносится в профиль при первом входе.
  # Закрыть его можно крестиком, Esc или кликом по фону.
  def show_tag_onboarding?
    preferred_tags.nil?
  end

  def user_completed_modes(slugs)
    return {} unless current_user
    TestAttempt
      .where(user_id: current_user.id, test_slug: slugs)
      .where.not(challenge_mode: [ nil, "" ])
      .group(:test_slug)
      .pluck(:test_slug, Arel.sql("array_agg(DISTINCT challenge_mode)"))
      .to_h
  end

  # topic_index — опциональный снимок TopicIndex.current: нужен только для
  # поиска по темам вопросов на главной (см. #index), а не для карточки
  # отдельного теста (#show), где достаточно тегов.
  def test_props(t, completed_modes = [], topic_index = nil)
    topics = topic_index ? topic_index.topics_of(t.slug) : []

    {
      slug:                      t.slug,
      title:                     t.title,
      description:               t.description,
      tags:                      tags_for(t),
      # Теги — голые слаги (sre, prometheus), по ним и так ищут сейчас, но
      # искать «надёжность» по ним нельзя: слаги латиницей. Описание тега —
      # единственный русский текст, который у него вообще есть (отдельного
      # «названия» тега в таксономии нет, см. TagTaxonomy).
      tags_translated:           tags_for(t).filter_map { |tag| TagTaxonomy.description_of(tag) },
      # Темы — свойство вопроса, не теста (см. TopicAchievements): тест с
      # тегом ruby может не содержать ни одного вопроса по теме reliability,
      # и наоборот. topics.yml даёт каждой теме короткий русский label.
      topics:                    topics,
      # label_for отдаёт сам слаг как есть для незнакомых тем (это поведение
      # для UI отчёта, где показать что-то лучше, чем ничего) — здесь это
      # дало бы задвоенный мусор в поиске, поэтому непереведённые отфильтрованы.
      topics_translated:         topics.select { |slug| TopicDictionary.known?(slug) }.map { |slug| TopicDictionary.label_for(slug) },
      difficulty:                t.difficulty,
      estimated_time:            t.estimated_time,
      questions_count:           t.questions_count,
      attempts_count:            t.attempts_count,
      created_at:                t.created_at,
      avg_score:                 t.avg_score.to_f,
      pass_rate:                 t.pass_rate.to_f,
      best_score:                t.best_score&.to_f,
      best_attempt_id:           t.best_attempt_id,
      has_code_challenge:        t.has_code_challenge?,
      custom:                    t.custom?,
      overrides_repo:            t.overrides_repo,
      completed_challenge_modes: completed_modes
    }
  end

  # Synthetic tags, not stored in the yaml/db: derived from the record itself
  # so they can't drift out of sync with the actual test content.
  def tags_for(t)
    tags = t.tag_list
    tags += [ CODE_TAG ]   if t.has_code_challenge?
    tags += [ CUSTOM_TAG ] if t.custom?
    # Тот же тег мог оказаться и в yaml: тогда он всё равно должен значить
    # «этот тест из tests_custom/», а не появиться в списке дважды.
    tags.uniq
  end
end
