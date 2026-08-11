require "rails_helper"

RSpec.describe TagTaxonomy do
  describe "config/tag_taxonomy.yml" do
    it "не оставляет неразложенных тегов" do
      raw = YAML.safe_load(File.read(described_class::CONFIG_PATH)) || {}

      expect(Array(raw["unassigned"])).to be_empty,
        "Теги ждут раскладки по категориям: #{Array(raw['unassigned']).join(', ')}. " \
        "Запустите `rake tags:sync` и разнесите их по categories."
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
      expect(described_class.known_tags & %w[beginner intermediate advanced]).to be_empty
    end

    it "не встречается тегом ни в одном тесте" do
      with_level = TestMetadatum.active.select { |t| (t.tag_list & %w[beginner intermediate advanced]).any? }
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
end
