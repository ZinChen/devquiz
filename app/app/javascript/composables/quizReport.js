// Markdown-отчёт о разовом прохождении: единственный способ унести результат
// теста из файла, раз в БД он не сохраняется.

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']

function optionLetter(idx) {
  return LETTERS[idx] || String(idx + 1)
}

function formatTime(seconds) {
  if (!seconds) return '—'
  return `${Math.floor(seconds / 60)}м ${seconds % 60}с`
}

export function reportFilename(title) {
  const slug = String(title ?? 'test')
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/gi, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60) || 'test'
  return `devquiz-${slug}-${new Date().toISOString().slice(0, 10)}.md`
}

// В режиме fix ответы приходят уже разобранными на токены диффа, а не строкой.
function renderCodeAnswer(value) {
  if (typeof value === 'string') return value || '(пусто)'
  if (!Array.isArray(value) || value.length === 0) return '(без изменений)'

  return value
    .map(line => line.kind === 'removed'
      ? `- ${line.content}`
      : `+ ${line.tokens.map(t => t.text).join('')}`)
    .join('\n')
}

function renderQuestion(item, index) {
  const lines = [
    `### ${index + 1}. ${item.correct ? '✓' : '✗'} ${item.questionText}`,
    '',
  ]

  if (item.type === 'code_challenge') {
    if (item.code) {
      lines.push('```' + (item.language || ''), item.code.trimEnd(), '```', '')
    }
    lines.push('**Ваш ответ:**', '', '```', renderCodeAnswer(item.selectedAnswer), '```', '')
    if (!item.correct) {
      lines.push('**Правильный ответ:**', '', '```', renderCodeAnswer(item.correctAnswer), '```', '')
    }
  } else {
    item.options.forEach((opt, i) => {
      const isCorrect  = item.correctIds.includes(opt.id)
      const isSelected = item.selectedOptions.includes(opt.id)
      const marks = [isSelected ? 'ваш выбор' : null, isCorrect ? 'верно' : null].filter(Boolean)
      lines.push(`- ${optionLetter(i)}. ${opt.text}${marks.length ? ` — _${marks.join(', ')}_` : ''}`)
    })
    lines.push('')
  }

  if (item.explanation) lines.push(`> ${item.explanation}`, '')
  if (item.extendedExplanation) lines.push(item.extendedExplanation, '')
  if (item.recommendation) lines.push(`**Что почитать:** ${item.recommendation}`, '')

  return lines.join('\n')
}

export function buildReport({ test, attempt, answersDetail }) {
  const header = [
    `# ${test.title}`,
    '',
    `- Результат: **${attempt.score.toFixed(0)}%** (${attempt.correctCount} из ${attempt.totalQuestions})`,
    `- Время: ${formatTime(attempt.timeSpent)}`,
    attempt.challengeMode ? `- Режим кода: ${attempt.challengeMode}` : null,
    `- Дата: ${new Date().toLocaleString('ru-RU')}`,
    '',
    '_Тест пройден из файла, в статистике DevQuiz эта попытка не учитывается._',
    '',
    '## Разбор ответов',
    '',
  ].filter(line => line !== null)

  return header.join('\n') + (answersDetail ?? []).map(renderQuestion).join('\n') + '\n'
}
