require "rails_helper"

RSpec.describe WeakTopicsSummary do
  let(:user) { create(:user) }

  # q1/q2 в ror-basics.yml помечены topics: [mvc], q5 — [controllers].
  def answer(question_id, correct, slug: "ror-basics", at: Time.current)
    attempt = TestAttempt.create!(user_id: user.id, test_slug: slug, total_questions: 1, created_at: at)
    attempt.test_attempt_answers.create!(
      question_id: question_id, selected_options: [ "a" ], correct: correct, created_at: at
    )
  end

  def entries_for(user_record = user)
    described_class.for(user: user_record).entries
  end

  it "группирует слабые вопросы по темам" do
    answer("q1", false)
    answer("q5", false)

    expect(entries_for.map(&:slug)).to match_array(%w[mvc controllers])
  end

  it "складывает ошибки нескольких вопросов одной темы" do
    answer("q1", false)
    answer("q2", false)

    mvc = entries_for.find { |e| e.slug == "mvc" }
    expect(mvc.wrong_count).to eq(2)
  end

  it "ставит вперёд тему с большим числом ошибок" do
    answer("q1", false)
    answer("q2", false)
    answer("q5", false)

    expect(entries_for.map(&:slug)).to eq(%w[mvc controllers])
  end

  it "подставляет название и цвет из словаря тем" do
    answer("q1", false)

    topic = entries_for.first
    expect(topic.label).to eq("MVC & Request lifecycle")
    expect(topic.color).to be_present
  end

  it "повышает уровень с ростом числа ошибок" do
    answer("q1", false)
    expect(entries_for.first.level).to eq("low")

    answer("q2", false)
    expect(described_class.for(user: user).entries.first.level).to eq("medium")
  end

  # Вопрос уходит из WeakQuestions после двух верных подряд — тема вместе с ним.
  it "убирает тему, когда вопросы по ней закрыты" do
    answer("q1", false, at: 3.days.ago)
    answer("q1", true,  at: 2.days.ago)
    answer("q1", true,  at: 1.day.ago)

    expect(entries_for).to be_empty
  end

  it "не смешивает пользователей" do
    answer("q1", false)

    expect(entries_for(create(:user))).to be_empty
  end

  it "возвращает пусто без пользователя и токена гостя" do
    answer("q1", false)

    expect(described_class.for(user: nil, guest_token: nil).entries).to be_empty
  end
end
