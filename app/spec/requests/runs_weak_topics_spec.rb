require "rails_helper"

RSpec.describe "Слабые темы после теста", type: :request do
  let!(:meta) { create(:test_metadatum, slug: "ror-basics", questions_count: 2, tags: "ruby,rails,backend") }
  let!(:other) { create(:test_metadatum, slug: "ror-active-record", tags: "ruby,rails,activerecord,backend") }
  let!(:unrelated) { create(:test_metadatum, slug: "postgresql-basics", tags: "postgresql,sql") }

  def complete_test(answers)
    post "/tests/#{meta.slug}/run", params: {
      answers:    answers,
      started_at: 1.minute.ago.iso8601,
      time_spent: 60
    }
    get response.location, headers: { "X-Inertia" => "true" }
  end

  # У q1/q2 в ror-basics.yml проставлен topics: [mvc] — он точнее тегов теста.
  it "показывает темы неверных вопросов и связанные тесты" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ] })

    weak = response.parsed_body["props"]["weak_topics"]
    expect(weak["tags"].map { |t| t["slug"] }).to eq([ "mvc" ])
    expect(weak["recommended_tests"].map { |t| t["slug"] }).to include("ror-active-record")
    expect(weak["recommended_tests"].map { |t| t["slug"] }).not_to include("postgresql-basics", meta.slug)
  end

  it "подставляет название и цвет темы из словаря" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ] })

    topic = response.parsed_body["props"]["weak_topics"]["tags"].first
    expect(topic["label"]).to eq("MVC & Request lifecycle")
    expect(topic["color"]).to be_present
  end

  it "откатывается на теги теста, если у вопросов нет topics" do
    allow(YamlSyncService).to receive(:load_questions).and_wrap_original do |original, slug|
      original.call(slug).map { |q| q.except("topics") }
    end

    complete_test({ "q1" => [ "wrong" ], "q2" => [ "wrong" ] })

    tags = response.parsed_body["props"]["weak_topics"]["tags"]
    expect(tags.map { |t| t["slug"] }).to match_array(%w[ruby rails backend])
  end

  it "не показывает слабые темы, если все ответы верные" do
    complete_test({ "q1" => [ "b" ], "q2" => [ "b" ] })

    weak = response.parsed_body["props"]["weak_topics"]
    expect(weak["tags"]).to eq([])
  end

  it "запоминает часто ошибаемые вопросы гостя между попытками" do
    2.times { complete_test({ "q1" => [ "wrong" ], "q2" => [ "b" ] }) }

    weak = response.parsed_body["props"]["weak_topics"]
    mistake = weak["recent_mistakes"].find { |m| m["question_id"] == "q1" }
    expect(mistake["wrong_count"]).to eq(2)
  end

  it "перестаёт считать вопрос слабым после двух верных ответов" do
    complete_test({ "q1" => [ "wrong" ], "q2" => [ "b" ] })
    2.times { complete_test({ "q1" => [ "b" ], "q2" => [ "b" ] }) }

    weak = response.parsed_body["props"]["weak_topics"]
    expect(weak["recent_mistakes"]).to be_empty
    expect(weak["has_weak_in_this_test"]).to be false
  end

  describe "работа над ошибками" do
    def start_practice
      get "/tests/#{meta.slug}/run/new?only=weak", headers: { "X-Inertia" => "true" }
      response.parsed_body["props"]
    end

    it "оставляет только вопросы, где были ошибки" do
      complete_test({ "q1" => [ "wrong" ], "q2" => [ "b" ] })

      props = start_practice
      expect(props["questions"].map { |q| q["id"] }).to eq([ "q1" ])
      expect(props["weak_only"]).to be true
    end

    it "ведёт обычное прохождение, если прорабатывать нечего" do
      complete_test({ "q1" => [ "b" ], "q2" => [ "b" ] })

      props = start_practice
      expect(props["questions"].size).to be > 1
      expect(props["weak_only"]).to be false
    end

    it "считает score от числа заданных вопросов, а не всего теста" do
      complete_test({ "q1" => [ "wrong" ], "q2" => [ "b" ] })

      post "/tests/#{meta.slug}/run", params: {
        answers: { "q1" => [ "b" ] }, started_at: 1.minute.ago.iso8601, time_spent: 30, weak_only: true
      }

      attempt = TestAttempt.last
      expect(attempt.total_questions).to eq(1)
      expect(attempt.score).to eq(100.0)
    end

    it "не влияет на статистику теста" do
      complete_test({ "q1" => [ "wrong" ], "q2" => [ "b" ] })
      stats = meta.reload.slice(:attempts_count, :avg_score, :best_score)

      post "/tests/#{meta.slug}/run", params: {
        answers: { "q1" => [ "b" ] }, started_at: 1.minute.ago.iso8601, time_spent: 30, weak_only: true
      }

      expect(meta.reload.slice(:attempts_count, :avg_score, :best_score)).to eq(stats)
    end
  end
end
