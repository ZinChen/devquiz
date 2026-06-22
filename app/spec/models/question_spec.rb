require 'rails_helper'

RSpec.describe Question, type: :model do
  describe "validations" do
    subject { build(:question) }

    it { is_expected.to validate_presence_of(:test_slug) }
    it { is_expected.to validate_presence_of(:question_id) }
    it { is_expected.to validate_presence_of(:text) }

    it "validates uniqueness of question_id scoped to test_slug" do
      create(:question, test_slug: "ror-basics", question_id: "q1")
      duplicate = build(:question, test_slug: "ror-basics", question_id: "q1")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:bookmarks).dependent(:destroy) }
  end
end
