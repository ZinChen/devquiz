require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'database_cleaner/active_record'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    if example.metadata[:js]
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # TopicIndex/AchievementsCatalog кэшируются на уровне класса на весь
  # процесс (test-окружение не перечитывает их на каждый вызов, в отличие от
  # development — см. TopicIndex#current). System-спеки живут в одном Puma-
  # процессе весь прогон suite, поэтому спек, подменяющий TestSource.repo_dir/
  # custom_dir через allow(...).to receive(...) (см. custom_tests_spec),
  # может навсегда закэшировать урезанный индекс для всех спек после себя —
  # первый же visit построит TopicIndex по фейковым временным файлам.
  #
  # Сброс нужен именно здесь, а не в after конкретного спека: RSpec снимает
  # моки уже после пользовательских after-хуков, поэтому TestSource.repo_dir
  # внутри чужого after всё ещё возвращает подменённое значение — reload!
  # там пересобрал бы индекс неправильно (и один раз даже по уже удалённой
  # временной папке, из-за FileUtils.rm_rf, выполненного в том же хуке).
  config.after(:each, type: :system) do
    TopicIndex.reload!
    AchievementsCatalog.reload!
  end
end
