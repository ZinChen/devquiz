require "rails_helper"

RSpec.describe "Карточка участника активности", type: :request do
  let!(:meta)  { create(:test_metadatum, slug: "ror-basics") }
  let(:member) { create(:user, name: "Хитрая Лиса") }

  before do
    AchievementsCatalog.sync!
    %w[first_test streak_three].each do |slug|
      UserAchievement.create!(user: member, achievement: Achievement.find_by!(slug: slug), earned_at: Time.current)
    end
  end

  def be_active(user)
    ActivityPresence.join(ActivityViewer.new(user: user), test_slug: "ror-basics")
  end

  it "отдаёт имя, аватар и публичные ачивки участника из списка активности" do
    be_active(member)

    get "/activity/users/#{member.id}"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body).to include("id" => member.id, "name" => "Хитрая Лиса")
    slugs = body["achievements"]["items"].map { |i| i["slug"] }
    expect(slugs).to include("first_test")
    expect(slugs).not_to include("streak_three")
    expect(body["achievements"]["count"]).to eq(slugs.size)
  end

  it "не отдаёт почту и даты получения" do
    be_active(member)

    get "/activity/users/#{member.id}"

    expect(response.body).not_to include(member.email)
    expect(response.body).not_to include("earned_at")
  end

  it "доступна и гостю" do
    be_active(member)

    get "/activity/users/#{member.id}"

    expect(response).to have_http_status(:ok)
  end

  it "404 для пользователя, которого нет в активности" do
    get "/activity/users/#{member.id}"

    expect(response).to have_http_status(:not_found)
  end

  it "404 для скрывшего активность" do
    be_active(member)
    member.update!(activity_visible: false)

    get "/activity/users/#{member.id}"

    expect(response).to have_http_status(:not_found)
  end
end
