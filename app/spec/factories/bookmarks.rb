FactoryBot.define do
  factory :bookmark do
    association :user
    association :question
  end
end
