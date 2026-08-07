FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    avatar_url { Faker::Internet.url }

    trait :with_github do
      after(:create) do |user|
        create(:identity, user: user, provider: "github")
      end
    end

    trait :with_google do
      after(:create) do |user|
        create(:identity, user: user, provider: "google_oauth2")
      end
    end
  end

  factory :identity do
    user
    provider { "github" }
    sequence(:uid) { |n| "uid_#{n}" }
  end
end
