require "rails_helper"

RSpec.describe WeakQuestions do
  let(:user) { create(:user) }

  # Ответы задаются от старых к новым, как они и накапливались бы в жизни.
  def answer(question_id, correct, slug: "ror-basics", at: Time.current)
    attempt = TestAttempt.create!(user_id: user.id, test_slug: slug, total_questions: 1, created_at: at)
    attempt.test_attempt_answers.create!(
      question_id: question_id, selected_options: [ "a" ], correct: correct, created_at: at
    )
  end

  def entries_for(user_record = user)
    described_class.for(user: user_record).entries
  end

  it "возвращает вопрос, на котором ошибались" do
    answer("q1", false)

    expect(entries_for.map(&:question_id)).to eq([ "q1" ])
    expect(entries_for.first.wrong_count).to eq(1)
  end

  it "не возвращает вопрос, на который всегда отвечали верно" do
    answer("q1", true)

    expect(entries_for).to be_empty
  end

  it "убирает вопрос после двух верных ответов подряд" do
    answer("q1", false, at: 3.days.ago)
    answer("q1", true,  at: 2.days.ago)
    answer("q1", true,  at: 1.day.ago)

    expect(entries_for).to be_empty
  end

  it "оставляет вопрос, если верный ответ пока один" do
    answer("q1", false, at: 2.days.ago)
    answer("q1", true,  at: 1.day.ago)

    expect(entries_for.map(&:question_id)).to eq([ "q1" ])
  end

  it "учитывает только последние попытки" do
    6.times { |i| answer("q1", false, at: (10 - i).days.ago) }
    answer("q1", true, at: 2.days.ago)
    answer("q1", true, at: 1.day.ago)

    # Две свежие верные закрывают тему, несмотря на шесть старых ошибок.
    expect(entries_for).to be_empty
  end

  it "ставит вперёд вопрос с большим числом ошибок" do
    answer("q1", false, at: 2.days.ago)
    2.times { |i| answer("q2", false, at: (2 - i).days.ago) }

    expect(entries_for.map(&:question_id)).to eq([ "q2", "q1" ])
  end

  it "фильтрует по тесту, если задан slug" do
    answer("q1", false, slug: "ror-basics")
    answer("q2", false, slug: "postgresql-basics")

    entries = described_class.for(user: user, test_slug: "ror-basics").entries
    expect(entries.map(&:question_id)).to eq([ "q1" ])
  end

  it "не смешивает вопросы разных пользователей" do
    answer("q1", false)

    expect(entries_for(create(:user))).to be_empty
  end

  it "возвращает пусто без пользователя и токена гостя" do
    answer("q1", false)

    expect(described_class.for(user: nil, guest_token: nil).entries).to be_empty
  end
end
