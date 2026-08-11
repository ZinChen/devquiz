require "rails_helper"

RSpec.describe "Гостевые попытки", type: :request do
  let(:user) { create(:user, :with_github) }
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 1) }

  def sign_in(user)
    identity = user.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider,
      uid: identity.uid,
      info: { email: user.email, name: user.name, image: user.avatar_url }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  # Проходит тест без авторизации — попытка сохраняется с guest_token.
  def complete_test_as_guest
    post "/tests/#{meta.slug}/run", params: {
      # Rails выбрасывает пустой хэш из параметров, поэтому отвечаем на вопрос,
      # которого нет в тесте: попытка всё равно создаётся, ответ игнорируется.
      answers:     { "q1" => [ "a" ] },
      started_at:  1.minute.ago.iso8601,
      time_spent:  60
    }
  end

  it "сохраняет попытку гостя с токеном, но без пользователя" do
    complete_test_as_guest

    attempt = TestAttempt.last
    expect(attempt.user_id).to be_nil
    expect(attempt.guest_token).to be_present
  end

  it "присваивает гостевые попытки пользователю при входе" do
    complete_test_as_guest
    guest_attempt = TestAttempt.last

    sign_in(user)

    guest_attempt.reload
    expect(guest_attempt.user_id).to eq(user.id)
    expect(guest_attempt.guest_token).to be_nil
  end

  it "не трогает чужие гостевые попытки" do
    other = TestAttempt.create!(
      user_id: nil, guest_token: "чужой-токен", test_slug: meta.slug, total_questions: 1
    )

    complete_test_as_guest
    sign_in(user)

    expect(other.reload.user_id).to be_nil
  end

  it "переносит выбор тегов, сделанный до логина" do
    patch preferences_tags_path, params: { tags: [ "ruby" ] }

    sign_in(user)

    expect(user.reload.preferred_tags).to eq([ "ruby" ])
  end

  it "не затирает уже сохранённые предпочтения аккаунта" do
    user.update!(preferred_tags: [ "devops" ])
    patch preferences_tags_path, params: { tags: [ "ruby" ] }

    sign_in(user)

    expect(user.reload.preferred_tags).to eq([ "devops" ])
  end
end
