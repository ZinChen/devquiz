# Живая активность: кто сейчас проходит какой тест и на каком вопросе (#10).
#
# Хранится в таблице, а не в памяти процесса: Puma может вырасти до нескольких
# воркеров, а перезапуск контейнера не должен «выселять» всех из списка до
# следующего heartbeat'а.
class ActivityPresence < ApplicationRecord
  STREAM = "activity".freeze

  # Клиент шлёт heartbeat раз в 30 с (см. useActivity.js); строка старше TTL
  # считается брошенной — вкладку закрыли, не успев отписаться.
  TTL = 90.seconds

  MAX_QUESTION_ID_LENGTH = 64

  scope :alive, -> { where(last_seen_at: TTL.ago..) }

  class << self
    # Зритель начал (или продолжает) тест. Возвращает true, если запись есть.
    def join(viewer, test_slug:, question_id: nil)
      return false unless viewer.identified? && viewer.visible? && viewer.key
      return false unless TestMetadatum.active.exists?(slug: test_slug)

      record = find_or_initialize_by(viewer_key: viewer.key, test_slug: test_slug)
      record.assign_attributes(
        user_id:           viewer.user&.id,
        guest_name:        viewer.user ? nil : viewer.guest_identity[:name],
        guest_avatar_seed: viewer.user ? nil : viewer.guest_identity[:avatar_seed],
        question_id:       sanitize_question_id(question_id) || record.question_id,
        last_seen_at:      Time.current
      )
      record.save!
      broadcast
      true
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def focus(viewer, test_slug:, question_id:)
      join(viewer, test_slug: test_slug, question_id: question_id)
    end

    def leave(viewer, test_slug: nil)
      return unless viewer.key

      scope = where(viewer_key: viewer.key)
      scope = scope.where(test_slug: test_slug) if test_slug
      broadcast if scope.delete_all.positive?
    end

    # Пользователь скрыл активность: убираем его из списка сразу, а не ждать TTL.
    def forget_user(user)
      broadcast if where(user_id: user.id).delete_all.positive?
    end

    # { "ruby-basics" => [ {key:, name:, avatar_url:, avatar_seed:, question_id:,
    #                       user_id:, achievements_count:} ] }
    # Видимость проверяется и здесь, а не только при join: флаг могли
    # выключить, пока запись ещё жива.
    def snapshot
      purge_stale

      rows  = alive.order(:created_at).to_a
      users = User.where(id: rows.filter_map(&:user_id)).index_by(&:id)
      counts = achievement_tile_counts(users.keys)

      rows.each_with_object({}) do |row, acc|
        entry = presence_props(row, users[row.user_id], counts)
        (acc[row.test_slug] ||= []) << entry if entry
      end
    end

    def broadcast
      ActionCable.server.broadcast(STREAM, { activity: snapshot })
    end

    # Участник, чью карточку можно открыть: есть живая запись присутствия и он
    # не скрыл активность. Карточка — часть live-активности, а не публичный
    # профиль: по id постороннего пользователя она не открывается.
    def visible_user(user_id)
      return nil unless alive.exists?(user_id: user_id)

      User.find_by(id: user_id, activity_visible: true)
    end

    # Seed генерируемого аватара для чужих глаз. Запасной — не email (в кабинете
    # у самого пользователя он как раз email): снимок уходит всем подписчикам, а
    # почта не должна. Идентификатор так же стабилен — цвет не мигает между
    # сессиями.
    def public_avatar_seed(user)
      user.avatar_seed.presence || "user-#{user.id}"
    end

    private

    def purge_stale
      where(last_seen_at: ...TTL.ago).delete_all
    end

    def presence_props(row, user, counts)
      if row.user_id
        return nil unless user&.activity_visible?

        { key: row.viewer_key, name: user.name, avatar_url: user.avatar_url,
          avatar_seed: public_avatar_seed(user), question_id: row.question_id,
          user_id: user.id, achievements_count: counts.fetch(user.id, 0) }
      else
        { key: row.viewer_key, name: row.guest_name, avatar_url: nil,
          avatar_seed: row.guest_avatar_seed, question_id: row.question_id,
          user_id: nil, achievements_count: 0 }
      end
    end

    # Сколько плиток ачивок увидят в карточке участника (shareable, лесенки
    # свёрнуты до одной плитки): по этому числу карточка заранее рисует
    # плейсхолдер нужного размера, пока ачивки грузятся. Ровно та же логика, что
    # в Achievement.top_steps, только на SQL — для всего снимка одним запросом.
    # users.achievements_count не годится: он считает все выданные ступени,
    # включая shareable: false.
    LADDER_KEY = "DISTINCT COALESCE(NULLIF(achievements.group_name, ''), achievements.slug)".freeze

    def achievement_tile_counts(user_ids)
      return {} if user_ids.empty?

      UserAchievement
        .joins(:achievement)
        .merge(Achievement.shareable)
        .where(user_id: user_ids)
        .group(:user_id)
        .count(Arel.sql(LADDER_KEY))
    end

    def sanitize_question_id(value)
      value = value.to_s.strip
      value.presence&.first(MAX_QUESTION_ID_LENGTH)
    end
  end
end
