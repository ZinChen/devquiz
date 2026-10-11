require "rails_helper"

RSpec.describe "Блоки новых достижений на странице результата", type: :system, js: true do
  let(:repo_dir) { Rails.root.join("tmp/blocks_repo") }
  let(:user)     { create(:user, :with_github) }

  before do
    FileUtils.mkdir_p(repo_dir)
    File.write(repo_dir.join("blocks-test.yml"), {
      "slug" => "blocks-test", "title" => "Тест блоков", "description" => "описание", "difficulty" => "basic",
      "questions" => [ { "id" => "q1", "text" => "Вопрос?", "type" => "single",
        "options" => [ { "id" => "a", "text" => "Да", "correct" => true },
                       { "id" => "b", "text" => "Нет", "correct" => false } ] } ]
    }.to_yaml)
    allow(TestSource).to receive(:repo_dir).and_return(repo_dir)
    allow(TestSource).to receive(:custom_dir).and_return(Rails.root.join("tmp/blocks_custom_none"))
    YamlSyncService.sync_all
    AchievementsCatalog.sync!

    @attempt = TestAttempt.create!(
      user_id: user.id, test_slug: "blocks-test", total_questions: 1, correct_count: 1, score: 100,
      started_at: 1.minute.ago, completed_at: Time.current, time_spent: 30
    )

    identity = user.identities.first
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: identity.provider, uid: identity.uid,
      info: { email: user.email, name: user.name, image: user.avatar_url }
    )
    visit "/auth/github/callback"
  end

  after do
    OmniAuth.config.test_mode = false
    FileUtils.rm_rf(repo_dir)
  end

  def open_result(query)
    visit "/tests/blocks-test/runs/#{@attempt.id}?#{query}"
    expect(page).to have_css(".result-achievements")
  end

  it "выводит отдельный блок на каждый металл, золото первым" do
    open_result("preview_achievements=medals")

    blocks = all(".result-achievements").map { |b| b[:class][/result-achievements--(\w+)/, 1] }
    expect(blocks).to eq(%w[gold silver bronze])
  end

  it "ачивки одного металла собираются в один блок" do
    open_result("preview_achievements[]=ten_tests&preview_achievements[]=twenty_tests")

    expect(page).to have_css(".result-achievements", count: 1)
    expect(page).to have_css(".result-achievements--silver .result-achievement", count: 2)
    expect(page).to have_css(".result-achievements__title", text: "Новые достижения")
  end

  it "заголовок в единственном числе, если в блоке одна ачивка" do
    open_result("preview_achievements=medals")

    titles = all(".result-achievements__title").map(&:text)
    expect(titles).to all(eq("Новое достижение"))
  end

  it "ссылка «Все достижения» только в последнем блоке" do
    open_result("preview_achievements=medals")

    expect(page).to have_css(".result-achievements__link", count: 1)
    expect(page).to have_css(".result-achievements--bronze .result-achievements__link", text: "Все достижения")
  end

  it "блик есть только у золотого блока" do
    open_result("preview_achievements=medals")

    gold_shine = page.evaluate_script(
      "getComputedStyle(document.querySelector('.result-achievements--gold'), '::after').animationName"
    )
    silver_shine = page.evaluate_script(
      "getComputedStyle(document.querySelector('.result-achievements--silver'), '::after').animationName"
    )
    # Vue дописывает к имени анимации хэш скоупа, поэтому сравниваем по префиксу.
    expect(gold_shine).to start_with("achievement-shine")
    expect(silver_shine).to eq("none")
  end
end
