FactoryBot.define do
  factory :question do
    sequence(:test_slug) { |n| "test-slug-#{n}" }
    sequence(:question_id) { |n| "q#{n}" }
    text { Faker::Lorem.question }
    type_field { "single" }
    options { [ { "id" => "a", "text" => "Option A" }, { "id" => "b", "text" => "Option B" } ] }
    correct_ids { [ "a" ] }
  end
end
