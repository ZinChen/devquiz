# Единый канал live-активности: список тестов слушает его, чтобы рисовать
# аватарки на карточках, экран прохождения — чтобы показать, кто на каком
# вопросе. Клиент получает полный снимок {activity: {slug => [зрители]}}, а не дельты:
# так потерянное сообщение не оставляет «призраков» в списке.
class ActivityChannel < ApplicationCable::Channel
  def subscribed
    stream_from ActivityPresence::STREAM
    # me — ключ самого зрителя: клиент по нему не рисует собственную аватарку
    # рядом с чужими (на экране прохождения это был бы шум).
    transmit({ me: viewer.key, activity: ActivityPresence.snapshot })
  end

  # Начало прохождения и heartbeat — одно и то же действие (upsert).
  def join(data)
    ActivityPresence.join(viewer, test_slug: data["test_slug"].to_s, question_id: data["question_id"])
  end

  def focus(data)
    ActivityPresence.focus(viewer, test_slug: data["test_slug"].to_s, question_id: data["question_id"])
  end

  def leave(data)
    ActivityPresence.leave(viewer, test_slug: data["test_slug"].to_s.presence)
  end

  def unsubscribed
    ActivityPresence.leave(viewer)
  end
end
