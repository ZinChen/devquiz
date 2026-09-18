# Откуда берутся YAML-тесты.
#
# Две папки: `tests/` в репозитории и `tests_custom/` рядом с ней — не трекается
# гитом и нужна, чтобы проходить свои тесты локально с сохранением статистики.
# Единственное место, которое знает про эти пути: всё остальное спрашивает slug.
class TestSource
  REPO   = "repo".freeze
  CUSTOM = "custom".freeze

  # topics.yml — словарь тем, а не тест; его слаг никогда не попадает в каталог.
  RESERVED_SLUGS = %w[topics].freeze

  class << self
    def repo_dir
      Rails.root.join("../tests").expand_path
    end

    def custom_dir
      Rails.root.join("../tests_custom").expand_path
    end

    # Порядок важен: кастомная папка идёт последней, и при совпадении слагов
    # её файл переопределяет репозиторный (см. `files_by_slug`).
    def dirs
      [ repo_dir, custom_dir ].select { |dir| Dir.exist?(dir) }
    end

    def custom_dir?
      Dir.exist?(custom_dir)
    end

    def source_of(dir)
      File.expand_path(dir.to_s) == custom_dir.to_s ? CUSTOM : REPO
    end

    # { slug => { path:, source:, overrides_repo: } } — по одной записи на слаг,
    # победитель уже выбран.
    def files_by_slug
      dirs.each_with_object({}) do |dir, acc|
        Dir.glob(File.join(dir.to_s, "*.yml")).sort.each do |path|
          slug = File.basename(path, ".yml")
          next if RESERVED_SLUGS.include?(slug)

          acc[slug] = {
            path:           path,
            source:         source_of(dir),
            # Кастомный файл встал на место уже найденного репозиторного:
            # это законная подмена, но пользователю о ней стоит сказать.
            overrides_repo: acc.key?(slug)
          }
        end
      end
    end

    def entry_for(slug)
      files_by_slug[slug.to_s]
    end

    def path_for(slug)
      entry_for(slug)&.fetch(:path)
    end
  end
end
