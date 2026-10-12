require "rails_helper"

RSpec.describe TagTaxonomy do
  describe "config/tag_taxonomy.yml" do
    it "не оставляет неразложенных тегов" do
      raw = YAML.safe_load(File.read(described_class::CONFIG_PATH)) || {}

      expect(Array(raw["unassigned"])).to be_empty,
        "Теги ждут раскладки по категориям: #{Array(raw['unassigned']).join(', ')}. " \
        "Запустите `rake tags:sync` и разнесите их по categories."
    end

    # Одноимённый подтег — это плитка, продублированная чипом: снятие чипа
    # снимает тег категории, плитка гаснет, и список подтегов схлопывается.
    it "не объявляет подтегом тег самой категории" do
      dup = described_class.categories.select { |c| c[:children].include?(c[:tag]) }
      expect(dup.map { |c| c[:tag] }).to be_empty
    end

    it "не повторяет тег и в категориях, и в подтегах другой категории" do
      all = described_class.categories.flat_map { |c| [ c[:tag], *c[:children] ] }
      expect(all.tally.select { |_, n| n > 1 }.keys).to be_empty
    end

    # Тест без тематического тега не покажется никому, кто выбрал темы.
    it "даёт каждому тесту хотя бы один тематический тег" do
      topic_tags = described_class.categories.flat_map { |c| [ c[:tag], *c[:children] ] }
      orphans = TestMetadatum.active.select { |t| (t.tag_list & topic_tags).empty? }
      expect(orphans.map(&:slug)).to be_empty
    end

    it "покрывает все теги, встречающиеся в тестах" do
      used = TestMetadatum.active.flat_map(&:tag_list).uniq
      expect(used - described_class.known_tags).to be_empty
    end
  end

  describe ".children_of" do
    it "возвращает подтеги категории" do
      expect(described_class.children_of("ruby")).to include("rails", "activerecord")
    end

    it "возвращает пустой список для категории без уточнений" do
      expect(described_class.children_of("go")).to eq([])
    end

    it "возвращает пустой список для неизвестного тега" do
      expect(described_class.children_of("не-существует")).to eq([])
    end
  end

  describe ".kind_of" do
    it "различает вид служебного тега" do
      expect(described_class.kind_of("hh")).to eq("source")
      expect(described_class.kind_of("backend")).to eq("broad")
    end

    it "возвращает nil для тематического тега" do
      expect(described_class.kind_of("ruby")).to be_nil
    end
  end

  # Уровень — одно взаимоисключающее значение, а не множество, поэтому живёт
  # в колонке difficulty. Тег-дублёр врал бы в фильтре.
  describe "уровень сложности" do
    it "не объявлен тегом в таксономии" do
      expect(described_class.known_tags & %w[basic advanced expert]).to be_empty
    end

    it "не встречается тегом ни в одном тесте" do
      with_level = TestMetadatum.active.select { |t| (t.tag_list & %w[basic advanced expert]).any? }
      expect(with_level.map(&:slug)).to be_empty
    end
  end

  describe "описания тегов" do
    it "есть у каждой категории" do
      without = described_class.categories.reject { |c| c[:description].present? }
      expect(without.map { |c| c[:tag] }).to be_empty
    end

    # Описание показывается подсказкой при наведении, поэтому пустых быть не должно
    # ни у подтегов, ни у служебных тегов.
    it "есть у каждого известного тега" do
      without = described_class.known_tags.reject { |tag| described_class.description_of(tag).present? }
      expect(without).to be_empty
    end
  end

  describe ".description_of" do
    it "отдаёт описание подтега" do
      expect(described_class.description_of("rails")).to be_present
    end

    it "отдаёт описание служебного тега" do
      expect(described_class.description_of("hh")).to be_present
    end

    it "возвращает nil для неизвестного тега" do
      expect(described_class.description_of("не-существует")).to be_nil
    end
  end

  describe ".sanitize" do
    it "отбрасывает неизвестные теги" do
      expect(described_class.sanitize([ "ruby", "не-существует" ])).to eq([ "ruby" ])
    end

    it "отбрасывает служебные теги" do
      expect(described_class.sanitize([ "ruby", "hh", "claude-gen" ])).to eq([ "ruby" ])
    end

    it "убирает дубликаты" do
      expect(described_class.sanitize([ "ruby", "ruby" ])).to eq([ "ruby" ])
    end

    it "переваривает мусор вместо массива" do
      expect(described_class.sanitize(nil)).to eq([])
    end
  end

  describe ".tag_counts" do
    it "считает категорию по её тегу или любому подтегу, не задваивая тест" do
      counts = described_class.tag_counts([ %w[rails activerecord], %w[ruby], %w[postgresql sql] ])

      expect(counts["ruby"]).to eq(2)
      expect(counts["rails"]).to eq(1)
      expect(counts["postgresql"]).to eq(1)
    end

    it "отдаёт ноль подтегу и категории, у которых нет тестов" do
      counts = described_class.tag_counts([ %w[ruby] ])

      expect(counts["go"]).to eq(0)
      expect(counts["grafana"]).to eq(0)
    end

    it "считает тест во всех категориях, к которым он относится" do
      counts = described_class.tag_counts([ %w[postgresql kafka] ])

      expect(counts.values_at("postgresql", "platform", "kafka")).to eq([ 1, 1, 1 ])
    end

    it "не считает служебные теги" do
      expect(described_class.tag_counts([ %w[hh backend] ]).keys).not_to include("hh", "backend")
    end
  end
end
