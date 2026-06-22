require 'rails_helper'

RSpec.describe TestAttempt, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:test_slug) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:test_attempt_answers).with_foreign_key(:attempt_id) }
  end

  describe "#completed?" do
    it "returns true when completed_at is set" do
      attempt = build(:test_attempt, :completed)
      expect(attempt.completed?).to be true
    end

    it "returns false when completed_at is nil" do
      attempt = build(:test_attempt)
      expect(attempt.completed?).to be false
    end
  end

  describe "#percentage" do
    it "calculates correct percentage" do
      attempt = build(:test_attempt, correct_count: 7, total_questions: 10)
      expect(attempt.percentage).to eq(70.0)
    end

    it "returns 0 when total_questions is 0" do
      attempt = build(:test_attempt, correct_count: 0, total_questions: 0)
      expect(attempt.percentage).to eq(0)
    end

    it "rounds to one decimal place" do
      attempt = build(:test_attempt, correct_count: 1, total_questions: 3)
      expect(attempt.percentage).to eq(33.3)
    end
  end
end
