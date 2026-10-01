class StatsController < ApplicationController
  # Рейтинг имеет смысл, только когда есть на чём его строить: на двух-трёх
  # прохождениях «100% проходят» — это чей-то единственный результат, а не
  # показатель теста. Поэтому страница открывается, лишь когда наберётся
  # RANKED_TESTS_REQUIRED тестов, пройденных хотя бы MIN_ATTEMPTS раз; до тех
  # пор ссылки на неё нет и в шапке (см. ApplicationController#inertia_share).
  MIN_ATTEMPTS           = 5
  RANKED_TESTS_REQUIRED  = 10
  TOP_LIMIT              = 10

  def index
    return redirect_to root_path unless self.class.ranking_ready?

    render inertia: "Stats", props: { top_tests: top_tests }
  end

  # Тесты, набравшие достаточно прохождений, чтобы попасть в рейтинг.
  def self.ranked_scope
    TestMetadatum.active.where(attempts_count: MIN_ATTEMPTS..)
  end

  def self.ranking_ready?
    ranked_scope.count >= RANKED_TESTS_REQUIRED
  end

  private

  def top_tests
    self.class.ranked_scope
      .order(attempts_count: :desc)
      .limit(TOP_LIMIT)
      .map do |t|
        {
          slug:           t.slug,
          title:          t.title,
          attempts_count: t.attempts_count,
          pass_rate:      t.pass_rate.to_f
        }
      end
  end
end
