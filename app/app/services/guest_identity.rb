# Имя и seed аватара анонимного посетителя — до логина хранятся в
# подписанной куке рядом с guest_token, а не в БД: гостю не заводится
# запись, а данные живут ровно там же и столько же, сколько сам токен.
#
# Нужны для будущего "кто сейчас проходит тест" (гостей тоже нужно как-то
# подписывать) и для того, чтобы при логине аккаунт унаследовал уже
# примелькавшееся имя/аватар вместо нового случайного (см. User.from_omniauth).
class GuestIdentity
  def self.from_cookie(raw)
    return nil if raw.blank?

    parsed = JSON.parse(raw, symbolize_names: true)
    return nil unless parsed[:name].present? && parsed[:avatar_seed].present?

    parsed
  rescue JSON::ParserError
    nil
  end

  def self.generate
    { name: RandomIdentity.name, avatar_seed: RandomIdentity.avatar_seed }
  end
end
