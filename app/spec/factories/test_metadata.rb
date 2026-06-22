FactoryBot.define do
  factory :test_metadatum do
    sequence(:slug) { |n| "test-slug-#{n}" }
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    difficulty { "beginner" }
    estimated_time { 10 }
    questions_count { 5 }
  end
end
