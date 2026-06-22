require 'rails_helper'

RSpec.describe TestMetadatum, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:title) }
    it "validates uniqueness of slug" do
      create(:test_metadatum, slug: "existing-slug")
      duplicate = build(:test_metadatum, slug: "existing-slug")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:test_attempts).with_foreign_key(:test_slug).with_primary_key(:slug) }
  end

  describe "#tag_list" do
    it "returns tags as an array" do
      meta = build(:test_metadatum, tags: "rails,ruby,orm")
      expect(meta.tag_list).to eq([ "rails", "ruby", "orm" ])
    end

    it "returns empty array when tags is blank" do
      meta = build(:test_metadatum, tags: "")
      expect(meta.tag_list).to eq([])
    end

    it "strips whitespace from tags" do
      meta = build(:test_metadatum, tags: "rails, ruby , orm")
      expect(meta.tag_list).to eq([ "rails", "ruby", "orm" ])
    end
  end

  describe "#tag_list=" do
    it "stores tags as comma-separated string" do
      meta = build(:test_metadatum)
      meta.tag_list = [ "rails", "ruby" ]
      expect(meta.tags).to eq("rails,ruby")
    end
  end
end
