require "rails_helper"

RSpec.describe "Общий рейтинг", type: :request do
  def ranked_test(slug, attempts: StatsController::MIN_ATTEMPTS, pass_rate: 80)
    create(:test_metadatum, slug: slug, attempts_count: attempts, pass_rate: pass_rate)
  end

  def fill_ranking(count = StatsController::RANKED_TESTS_REQUIRED)
    count.times { |i| ranked_test("ranked-#{i}") }
  end

  describe "пока прохождений мало" do
    it "не пускает на страницу" do
      fill_ranking(StatsController::RANKED_TESTS_REQUIRED - 1)

      get "/stats"

      expect(response).to redirect_to(root_path)
    end

    it "не показывает пункт в шапке" do
      get "/", headers: { "X-Inertia" => "true" }

      expect(response.parsed_body["props"]["ranking_ready"]).to be(false)
    end
  end

  describe "когда рейтинг набрался" do
    before { fill_ranking }

    it "открывается" do
      get "/stats", headers: { "X-Inertia" => "true" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["props"]["top_tests"].size).to eq(StatsController::TOP_LIMIT)
    end

    it "показывает пункт в шапке" do
      get "/", headers: { "X-Inertia" => "true" }

      expect(response.parsed_body["props"]["ranking_ready"]).to be(true)
    end

    it "не берёт тесты без достаточного числа прохождений" do
      ranked_test("too-fresh", attempts: StatsController::MIN_ATTEMPTS - 1)

      get "/stats", headers: { "X-Inertia" => "true" }

      slugs = response.parsed_body["props"]["top_tests"].map { |t| t["slug"] }
      expect(slugs).not_to include("too-fresh")
    end

    it "сортирует по числу прохождений" do
      ranked_test("most-popular", attempts: 500)

      get "/stats", headers: { "X-Inertia" => "true" }

      expect(response.parsed_body["props"]["top_tests"].first["slug"]).to eq("most-popular")
    end

    it "отдаёт только то, что показывает строка" do
      get "/stats", headers: { "X-Inertia" => "true" }

      # Средний балл убран: на нескольких попытках это чей-то единственный
      # результат, и рядом с долей прошедших два процента путали друг друга.
      expect(response.parsed_body["props"]["top_tests"].first.keys)
        .to contain_exactly("slug", "title", "attempts_count", "pass_rate")
    end

    it "не отдаёт общую статистику" do
      get "/stats", headers: { "X-Inertia" => "true" }

      expect(response.parsed_body["props"]).not_to include("global")
    end
  end
end
