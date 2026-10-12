// Склонение существительного по числу: pluralize(n, ['тест', 'теста', 'тестов']).
// Правила русского языка: 1, 21, 101 — «тест»; 2–4, 22–24 — «теста»; остальное,
// включая 11–14, — «тестов». Для дробных и отрицательных чисел берётся
// целая часть по модулю, чего для счётчиков здесь достаточно.
export function pluralize(count, [one, few, many]) {
  const n = Math.abs(Math.trunc(count))
  const lastTwo = n % 100
  const last = n % 10

  if (lastTwo >= 11 && lastTwo <= 14) return many
  if (last === 1) return one
  if (last >= 2 && last <= 4) return few
  return many
}

const TESTS_FORMS = ['тест', 'теста', 'тестов']

// «1 тест», «3 теста», «14 тестов».
export function testsLabel(count) {
  return `${count} ${pluralize(count, TESTS_FORMS)}`
}
