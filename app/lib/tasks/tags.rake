namespace :tags do
  desc "Сбросить выбор тем, чтобы снова увидеть экран онбординга (EMAIL=... или все)"
  task reset_preferences: :environment do
    # NULL, а не [] — только так TestsController#show_tag_onboarding? считает,
    # что экран ещё не показывали.
    scope = ENV["EMAIL"].present? ? User.where(email: ENV["EMAIL"]) : User.all
    count = scope.update_all(preferred_tags: nil)

    puts "Сброшено пользователей: #{count}"
    puts "Гостю: удалите куки preferred_tags (и guest_token, если попыток ещё нет)."
  end

  desc "Сверить теги из tests/*.yml с config/tag_taxonomy.yml и дописать новые в unassigned"
  task :sync do
    # Без :environment — как и yaml_sync:validate, задача должна работать в CI
    # без базы и загрузки Rails.
    require "yaml"
    require "pathname"

    root         = Pathname.new(__dir__).join("../..").expand_path
    tests_dir    = root.join("../tests").expand_path
    taxonomy_path = root.join("config/tag_taxonomy.yml")

    taxonomy = YAML.safe_load(File.read(taxonomy_path)) || {}

    known = (taxonomy["categories"] || {}).flat_map { |tag, cfg|
      [ tag, *((cfg || {})["children"] || {}).keys ]
    } + (taxonomy["service"] || {}).values.flat_map { |tags| (tags || {}).keys } +
            Array(taxonomy["unassigned"])

    used = Dir.glob(tests_dir.join("*.yml")).sort.flat_map { |path|
      data = begin
        YAML.safe_load(File.read(path))
      rescue Psych::SyntaxError => e
        abort "#{File.basename(path)}: invalid YAML — #{e.message}"
      end
      # topics.yml — общий словарь тем, а не тест.
      next [] unless data.is_a?(Hash) && data["slug"]
      Array(data["tags"]).map(&:to_s)
    }.uniq.sort

    missing = used - known
    stale   = Array(taxonomy["unassigned"]) & used

    if missing.empty?
      puts "✓ Все #{used.size} тегов разложены по категориям."
    else
      # Родителя по имени тега надёжно не угадать (sql может быть и потомком
      # postgresql, и самостоятельной категорией), поэтому новые теги только
      # складываются в unassigned — разложить их должен человек.
      updated = (Array(taxonomy["unassigned"]) + missing).uniq.sort

      # Переписываем только строку unassigned, а не дампим весь хэш через
      # to_yaml — иначе потеряются комментарии, ради которых файл и заведён.
      source = File.read(taxonomy_path)
      line   = "unassigned: [#{updated.join(', ')}]"
      source = if source.match?(/^unassigned:.*$/)
                 source.sub(/^unassigned:.*$/, line)
      else
                 "#{source.rstrip}\n\n#{line}\n"
      end
      File.write(taxonomy_path, source)
      puts "Добавлено в unassigned (#{missing.size}): #{missing.join(', ')}"
      puts "Разложите их по categories в config/tag_taxonomy.yml."
    end

    unused = known - used - Array(taxonomy["unassigned"])
    puts "Объявлены в таксономии, но не встречаются в тестах: #{unused.join(', ')}" if unused.any?
    puts "Ждут раскладки в unassigned: #{stale.join(', ')}" if stale.any?
  end
end
