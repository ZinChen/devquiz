require "rails_helper"

RSpec.describe TopicAchievements do
  describe ".topics" do
    it "берёт только темы, по которым хватает вопросов" do
      pools = described_class.topics.map { |_slug, _label, pool| pool }

      expect(pools).to all(be >= described_class::MIN_POOL)
    end

    it "не берёт тему, по которой вопросов почти нет" do
      # caching и background-jobs есть в словаре, но вопросов по ним единицы —
      # «Знаток» по ним был бы недостижимой целью в каталоге.
      slugs = described_class.topics.map(&:first)
      tiny  = TopicDictionary.slugs.select { |s| described_class.pool_size(s) < described_class::MIN_POOL }

      expect(tiny).not_to be_empty, "ожидались мелкие темы, иначе проверка ничего не значит"
      expect(slugs).not_to include(*tiny)
    end
  end

  describe ".entries" do
    it "делает по ступени на тему, пока хватает вопросов" do
      queries = described_class.entries.select { |e| e[:group] == "topic_queries" }

      expect(queries.map { |e| e[:threshold] }).to eq(described_class::TIERS.map { |t| t[:threshold] })
    end

    it "не создаёт ступень, которой не хватает вопросов в каталоге" do
      small = described_class.topics.min_by { |_slug, _label, pool| pool }
      slug, _label, pool = small
      entries = described_class.entries.select { |e| e[:group] == described_class.group_for(slug) }

      expect(entries.map { |e| e[:threshold] }).to all(be <= pool)
      expect(entries.size).to be < described_class::TIERS.size
    end

    it "называет ачивку ступенью и человеческим именем темы" do
      entry = described_class.entries.find { |e| e[:slug] == "topic_queries_guru" }

      expect(entry[:title]).to eq("Гуру: #{TopicDictionary.find('queries').label}")
    end

    it "складывает ступени одной темы в общую группу" do
      groups = described_class.entries.group_by { |e| e[:group] }

      expect(groups["topic_queries"].size).to eq(3)
      expect(groups.keys).to all(start_with("topic_"))
    end

    it "даёт уникальные слаги и позиции" do
      entries = described_class.entries

      expect(entries.map { |e| e[:slug] }.uniq.size).to eq(entries.size)
      expect(entries.map { |e| e[:position] }.uniq.size).to eq(entries.size)
    end
  end

  describe ".topic_of" do
    it "достаёт слаг темы из имени группы" do
      expect(described_class.topic_of("topic_queries")).to eq("queries")
    end

    it "возвращает nil для групп, не связанных с темами" do
      expect(described_class.topic_of("tests_passed")).to be_nil
      expect(described_class.topic_of(nil)).to be_nil
    end
  end

  describe "каталог целиком" do
    it "подхватывает тематические ачивки наравне с описанными в yml" do
      slugs = AchievementsCatalog.entries.map(&:slug)

      expect(slugs).to include("first_test", "topic_queries_known")
    end

    it "красит плитку темы её собственным цветом из словаря" do
      color = AchievementsCatalog.color_for("topic_queries")

      expect(color["fg"]).to eq(TopicDictionary.find("queries").color)
    end
  end
end
