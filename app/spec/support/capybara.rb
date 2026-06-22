require "capybara/rails"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1280, 800 ], headless: true, process_timeout: 30)
end

Capybara.configure do |config|
  config.default_driver    = :rack_test
  config.javascript_driver = :cuprite
  config.default_max_wait_time = 5
  config.app_host = "http://127.0.0.1"
  config.server  = :puma, { Silent: true }
end
