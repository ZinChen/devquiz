FactoryBot.define do
  factory :user do
    provider { "github" }
    sequence(:uid) { |n| "uid_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    avatar_url { Faker::Internet.url }
  end
end
