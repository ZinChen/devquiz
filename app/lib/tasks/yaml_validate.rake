namespace :yaml_sync do
  desc "Validate every YAML test file without touching the database"
  task :validate do
    # Deliberately not :environment — this runs in CI without a database, and
    # keeping it dependency-free makes it a few seconds instead of a boot cycle.
    require "yaml"
    require "pathname"

    # Stands in for ActiveSupport's blank?, which is unavailable without :environment.
    blank = ->(value) { value.nil? || value.to_s.strip.empty? }

    tests_dir = Pathname.new(__dir__).join("../../../tests").expand_path
    paths     = Dir.glob(tests_dir.join("*.yml")).sort

    # Types YamlSyncService knows how to store. Unknown types are reported as
    # warnings, not errors, so introducing a new one is never blocked here.
    known_types = %w[single multiple code_challenge]

    errors    = []
    warnings  = []
    seen_slugs = {}

    abort "No .yml files found in #{tests_dir}" if paths.empty?

    checked = 0

    paths.each do |path|
      name = File.basename(path)

      begin
        data = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ])
      rescue Psych::SyntaxError => e
        errors << "#{name}: invalid YAML — #{e.message}"
        next
      end

      unless data.is_a?(Hash)
        errors << "#{name}: top level must be a mapping"
        next
      end

      # topics.yml is the shared topic dictionary, not a quiz. YamlSyncService
      # skips anything without a slug, so shape-check it and move on.
      if data.key?("topics") && !data.key?("slug")
        unless data["topics"].is_a?(Hash) && data["topics"].any?
          errors << "#{name}: 'topics' must be a non-empty mapping"
        end
        next
      end

      checked += 1
      slug = data["slug"]
      # A missing slug makes YamlSyncService skip the file silently, so the test
      # would just vanish from the site with nothing in the logs.
      if blank.(slug)
        errors << "#{name}: missing 'slug'"
      else
        if (first = seen_slugs[slug])
          errors << "#{name}: slug '#{slug}' already used by #{first}"
        else
          seen_slugs[slug] = name
        end

        expected = File.basename(path, ".yml")
        if slug != expected
          warnings << "#{name}: slug '#{slug}' does not match the filename"
        end
      end

      %w[title description difficulty].each do |field|
        errors << "#{name}: missing '#{field}'" if blank.(data[field])
      end

      questions = data["questions"]
      unless questions.is_a?(Array) && questions.any?
        errors << "#{name}: 'questions' must be a non-empty list"
        next
      end

      seen_qids = {}

      questions.each_with_index do |q, index|
        where = "#{name} q[#{index}]"

        unless q.is_a?(Hash)
          errors << "#{where}: must be a mapping"
          next
        end

        qid = q["id"].to_s
        if blank.(qid)
          # sync_questions skips these, so the question never reaches the database.
          errors << "#{where}: missing 'id'"
        elsif seen_qids[qid]
          errors << "#{where}: duplicate question id '#{qid}'"
        else
          seen_qids[qid] = true
        end

        label = qid.empty? ? "index #{index}" : qid
        errors << "#{name} #{label}: missing 'text'" if blank.(q["text"])

        type = q["type"].to_s.empty? ? "single" : q["type"].to_s
        unless known_types.include?(type)
          warnings << "#{name} #{label}: unrecognised type '#{type}'"
        end

        # code_challenge carries its own payload rather than options.
        next if type == "code_challenge"

        options = q["options"]
        unless options.is_a?(Array) && options.size >= 2
          errors << "#{name} #{label}: needs at least two options"
          next
        end

        seen_oids = {}
        options.each_with_index do |opt, opt_index|
          unless opt.is_a?(Hash)
            errors << "#{name} #{label}: option #{opt_index} must be a mapping"
            next
          end

          oid = opt["id"].to_s
          if blank.(oid)
            errors << "#{name} #{label}: option #{opt_index} missing 'id'"
          elsif seen_oids[oid]
            errors << "#{name} #{label}: duplicate option id '#{oid}'"
          else
            seen_oids[oid] = true
          end

          errors << "#{name} #{label}: option '#{oid}' missing 'text'" if blank.(opt["text"])
        end

        correct = options.select { |o| o.is_a?(Hash) && o["correct"] }

        case type
        when "single"
          # Zero correct answers makes the question unanswerable; more than one
          # is almost certainly a mistake in a single-choice question.
          if correct.empty?
            errors << "#{name} #{label}: no option marked correct"
          elsif correct.size > 1
            errors << "#{name} #{label}: #{correct.size} options marked correct, but type is 'single'"
          end
        when "multiple"
          errors << "#{name} #{label}: no option marked correct" if correct.empty?
        end
      end
    end

    warnings.each { |w| puts "  warning: #{w}" }

    if errors.any?
      puts
      errors.each { |e| puts "  error: #{e}" }
      abort "\n#{errors.size} error(s) in #{paths.size} file(s)."
    end

    summary = "#{checked} quiz file(s) of #{paths.size} — all valid"
    summary += ", #{warnings.size} warning(s)" if warnings.any?
    puts summary
  end
end
