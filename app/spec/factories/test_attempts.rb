FactoryBot.define do
  factory :test_attempt do
    association :user
    test_slug { "ror-basics" }
    total_questions { 10 }
    correct_count { 7 }
    started_at { 1.hour.ago }

    trait :completed do
      completed_at { Time.current }
      score { 70.0 }
    end
  end
end
