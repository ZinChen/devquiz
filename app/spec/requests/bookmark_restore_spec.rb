require "rails_helper"

RSpec.describe "Возврат закладки", type: :request do
  let(:user)     { create(:user, :with_github) }
  let(:question) { create(:question) }

  def sign_in(u)
    identity = u.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: u.email, name: u.name }
    )
    get "/auth/github/callback"
  end

  after { OmniAuth.config.test_mode = false }

  before do
    sign_in(user)
    post "/bookmarks", params: { question_id: question.id }
  end

  it "возвращает удалённую закладку" do
    delete "/bookmarks", params: { question_id: question.id }
    expect(user.bookmarks.count).to eq(0)

    post "/bookmarks", params: { question_id: question.id }

    expect(user.bookmarks.count).to eq(1)
    expect(response.parsed_body["bookmarked"]).to be true
  end

  # find_or_create_by! не должен падать, если закладка ещё на месте.
  it "не дублирует закладку при повторном добавлении" do
    post "/bookmarks", params: { question_id: question.id }

    expect(user.bookmarks.count).to eq(1)
  end
end
