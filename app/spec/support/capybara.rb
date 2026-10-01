require "capybara/rails"
require "capybara/cuprite"

# Опции браузера для системных тестов.
#
# Лежат здесь, а не в Capybara.register_driver: `driven_by :cuprite` в Rails
# перерегистрирует драйвер с таким же именем своими опциями, затирая чужую
# регистрацию вместе с размером окна и таймаутом. Поэтому опции передаются в
# driven_by, а не задаются один раз при регистрации.
# Браузер в тестах не ходит наружу. Единственный внешний ресурс страницы —
# шрифт Inter, который app.css тянет с fonts.googleapis.com: его загрузка
# делала E2E флейкующими (Ferrum::PendingConnectionsError на visit, каждый раз
# в другой спеке), а без интернета роняла их все. Резолвер отдаёт NOTFOUND
# сразу, поэтому запрос не висит, а приложение и CDP остаются доступными по
# локальному адресу.
CUPRITE_RESOLVER_RULES = "MAP * ~NOTFOUND, EXCLUDE 127.0.0.1, EXCLUDE localhost".freeze

RSpec.configure do |config|
  # Хэш собирается заново на каждый вызов: и Rails, и Cuprite дописывают в
  # переданные опции свои ключи, поэтому общий замороженный объект здесь
  # падает с FrozenError.
  config.before(:each, type: :system, js: true) do
    driven_by :cuprite, screen_size: [ 1280, 800 ], options: {
      headless:        true,
      process_timeout: 30,
      browser_options: { "host-resolver-rules" => CUPRITE_RESOLVER_RULES }
    }
  end
end

Capybara.configure do |config|
  config.default_driver    = :rack_test
  config.javascript_driver = :cuprite
  config.default_max_wait_time = 5
  config.app_host = "http://127.0.0.1"
  config.server  = :puma, { Silent: true }
end
