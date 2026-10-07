require "rails_helper"

RSpec.describe ActivityChannel, type: :channel do
  let!(:test_meta) { create(:test_metadatum, slug: "ruby-basics") }
  let(:user)       { create(:user) }
  let(:viewer)     { ActivityViewer.new(user: user) }

  before { stub_connection(viewer: viewer) }

  it "при подписке сразу отдаёт текущий снимок" do
    other = create(:user)
    ActivityPresence.join(ActivityViewer.new(user: other), test_slug: "ruby-basics")

    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(ActivityPresence::STREAM)
    expect(transmissions.last["activity"]["ruby-basics"].first["name"]).to eq(other.name)
  end

  it "сообщает зрителю его собственный ключ" do
    subscribe

    expect(transmissions.last["me"]).to eq("u:#{user.id}")
  end

  it "join добавляет зрителя и рассылает снимок подписчикам" do
    subscribe

    expect { perform :join, test_slug: "ruby-basics" }
      .to have_broadcasted_to(ActivityPresence::STREAM)
  end

  it "focus запоминает вопрос в фокусе" do
    subscribe
    perform :join, test_slug: "ruby-basics"
    perform :focus, test_slug: "ruby-basics", question_id: "q2"

    expect(ActivityPresence.last.question_id).to eq("q2")
  end

  it "отписка убирает зрителя" do
    subscribe
    perform :join, test_slug: "ruby-basics"
    unsubscribe

    expect(ActivityPresence.count).to eq(0)
  end

  it "скрытый пользователь join'ом в список не попадает" do
    user.update!(activity_visible: false)
    subscribe
    perform :join, test_slug: "ruby-basics"

    expect(ActivityPresence.count).to eq(0)
  end
end
