import { ref } from 'vue'
import { load, CORE_SCHEMA } from 'js-yaml'

export const MAX_FILE_SIZE = 2 * 1024 * 1024 // 2 МБ
const YAML_EXTENSIONS = ['.yml', '.yaml']

const DIFFICULTIES    = ['beginner', 'intermediate', 'advanced']
const QUESTION_TYPES  = ['single', 'multiple', 'code_challenge']
const CHALLENGE_MODES = ['highlight', 'select', 'fill', 'fix']

export function isYamlFile(file) {
  if (!file) return false
  const name = file.name?.toLowerCase() ?? ''
  return YAML_EXTENSIONS.some(ext => name.endsWith(ext))
}

// Проверка структуры повторяет серверную (QuizDefinition), но нужна и здесь:
// без неё пользователь узнал бы об ошибке в файле только после отправки.
export function validateDefinition(data) {
  const errors = []

  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    return { errors: ['Файл должен содержать объект с полями теста'] }
  }

  if (!data.title) errors.push('Не заполнено поле title')

  const questions = data.questions
  if (!Array.isArray(questions) || questions.length === 0) {
    errors.push('Не найдено ни одного вопроса в поле questions')
    return { errors }
  }

  questions.forEach((q, i) => {
    const label = `Вопрос #${i + 1}`

    if (q === null || typeof q !== 'object' || Array.isArray(q)) {
      errors.push(`${label}: ожидается объект с полями вопроса`)
      return
    }

    if (!q.text) errors.push(`${label}: пустой текст вопроса`)

    const type = QUESTION_TYPES.includes(q.type) ? q.type : 'single'

    if (type === 'code_challenge') {
      validateModes(q, label, errors)
    } else {
      validateOptions(q, label, errors)
    }
  })

  return { errors }
}

function validateOptions(q, label, errors) {
  if (!Array.isArray(q.options) || q.options.length === 0) {
    errors.push(`${label}: нужен непустой список options`)
    return
  }
  if (!q.options.every(o => o !== null && typeof o === 'object' && !Array.isArray(o))) {
    errors.push(`${label}: каждый вариант должен быть объектом с полями id/text/correct`)
    return
  }
  if (!q.options.some(o => o.correct === true || String(o.correct).toLowerCase() === 'true')) {
    errors.push(`${label}: не отмечен ни один правильный вариант (correct: true)`)
  }
}

function validateModes(q, label, errors) {
  const modes = q.modes
  const present = (modes !== null && typeof modes === 'object' && !Array.isArray(modes))
    ? CHALLENGE_MODES.filter(m => modes[m] !== undefined)
    : []

  if (present.length === 0) {
    errors.push(`${label}: для code_challenge нужен блок modes хотя бы с одним из режимов: ${CHALLENGE_MODES.join(', ')}`)
    return
  }

  present.forEach(name => {
    const body = modes[name]
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      errors.push(`${label}: режим ${name} должен быть объектом`)
      return
    }
    if (!body.code) {
      errors.push(`${label}: в режиме ${name} не задано поле code`)
      return
    }
    if (name === 'highlight' && !toArray(body.correct_lines).length) {
      errors.push(`${label}: в режиме highlight не заданы correct_lines`)
    }
    if (name !== 'highlight' && !toArray(body.answer).length) {
      errors.push(`${label}: в режиме ${name} не задано поле answer`)
    }
  })
}

function toArray(value) {
  if (value === undefined || value === null) return []
  return Array.isArray(value) ? value : [value]
}

// Приводит определение к тому виду, который ждут useQuizSession и бэкенд:
// вопросы без id получают его по позиции, difficulty вне словаря отбрасывается.
export function normalizeDefinition(data) {
  return {
    slug:                   data.slug ? String(data.slug) : 'preview',
    title:                  String(data.title),
    description:            data.description ? String(data.description) : '',
    tags:                   toArray(data.tags).map(String).slice(0, 20),
    difficulty:             DIFFICULTIES.includes(data.difficulty) ? data.difficulty : null,
    estimated_time:         Number.isFinite(Number(data.estimated_time)) ? Number(data.estimated_time) : 0,
    language:               data.language ? String(data.language) : 'ruby',
    default_challenge_mode: CHALLENGE_MODES.includes(data.default_challenge_mode) ? data.default_challenge_mode : null,
    questions: data.questions.map((q, i) => ({
      ...q,
      id:   q.id ? String(q.id) : `q${i + 1}`,
      type: QUESTION_TYPES.includes(q.type) ? q.type : 'single',
    })),
  }
}

// Пропсы Inertia камелизуются на клиенте (см. entrypoints/application.js), а
// проверка ответов на сервере читает snake_case-поля исходного YAML
// (correct_lines, insert_text). Поэтому определение в исходном виде передаём
// на страницу прохождения отдельно, через sessionStorage.
const DEFINITION_KEY = 'devquiz_preview_definition'

// Отпечаток содержимого файла. Нужен, чтобы у каждого дропнутого теста был свой
// ключ сессии: иначе все они делят один `devquiz_session_preview`, и второй
// файл открылся бы с ответами первого.
export function definitionFingerprint(definition) {
  const source = JSON.stringify(definition)
  let hash = 5381
  for (let i = 0; i < source.length; i++) {
    hash = ((hash << 5) + hash + source.charCodeAt(i)) | 0
  }
  return (hash >>> 0).toString(36)
}

export function stashDefinition(definition) {
  try {
    sessionStorage.setItem(DEFINITION_KEY, JSON.stringify(definition))
  } catch {}
}

export function takeStashedDefinition() {
  try {
    const raw = sessionStorage.getItem(DEFINITION_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function useDroppedTest() {
  const parseErrors = ref([])

  function clearErrors() {
    parseErrors.value = []
  }

  // Возвращает нормализованное определение или null, положив причину отказа
  // в parseErrors.
  async function parseFile(file) {
    clearErrors()

    if (!isYamlFile(file)) {
      parseErrors.value = ['Нужен файл .yml или .yaml']
      return null
    }

    if (file.size > MAX_FILE_SIZE) {
      parseErrors.value = [`Файл больше ${MAX_FILE_SIZE / 1024 / 1024} МБ`]
      return null
    }

    let data
    try {
      // CORE_SCHEMA: только стандартные скалярные типы, без пользовательских
      // тегов — файл чужой, лишние возможности парсера ни к чему.
      data = load(await file.text(), { schema: CORE_SCHEMA })
    } catch (e) {
      parseErrors.value = [`Не удалось разобрать YAML: ${e.message}`]
      return null
    }

    const { errors } = validateDefinition(data)
    if (errors.length > 0) {
      parseErrors.value = errors
      return null
    }

    return normalizeDefinition(data)
  }

  return { parseErrors, parseFile, clearErrors }
}
