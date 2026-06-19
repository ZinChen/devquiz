import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { router } from '@inertiajs/vue3'

export function useQuizSession(test, questionsSource) {
  const STORAGE_KEY = `devquiz_session_${test.slug}`

  function resolveQuestions() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null')
      if (saved?.questions?.length) return saved.questions
    } catch {}
    return questionsSource.map(q => ({ ...q }))
  }

  function resolveSavedIndex() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null')
      return saved?.currentIndex || 0
    } catch {}
    return 0
  }

  const questions    = ref(resolveQuestions())
  const answers      = ref({})
  const startedAt    = ref(new Date().toISOString())
  const elapsed      = ref(0)
  const savedIndex   = ref(resolveSavedIndex())
  let timer

  onMounted(() => {
    timer = setInterval(() => elapsed.value++, 1000)

    questions.value.forEach(q => {
      answers.value[q.id] = q.type === 'multiple' ? [] : null
    })

    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null')
      if (saved) {
        answers.value   = saved.answers   || answers.value
        startedAt.value = saved.startedAt || startedAt.value
      }
    } catch {}

    watch(answers, () => saveSession(), { deep: true })
  })

  onUnmounted(() => clearInterval(timer))

  function saveSession(extra = {}) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      questions:    questions.value,
      answers:      answers.value,
      startedAt:    startedAt.value,
      currentIndex: savedIndex.value,
      ...extra,
    }))
  }

  function updateIndex(idx) {
    savedIndex.value = idx
    saveSession()
  }

  const answeredCount = computed(() =>
    questions.value.filter(q => isAnswered(q)).length
  )

  function isAnswered(q) {
    const a = answers.value[q.id]
    return q.type === 'multiple' ? a?.length > 0 : a !== null
  }

  const timeDisplay = computed(() => {
    const m = Math.floor(elapsed.value / 60).toString().padStart(2, '0')
    const s = (elapsed.value % 60).toString().padStart(2, '0')
    return `${m}:${s}`
  })

  const timerWarning = computed(() =>
    test.estimated_time && elapsed.value > test.estimated_time * 60
  )

  function submit() {
    const normalized = {}
    questions.value.forEach(q => {
      const a = answers.value[q.id]
      normalized[q.id] = q.type === 'multiple' ? (a || []) : (a ? [a] : [])
    })
    localStorage.removeItem(STORAGE_KEY)
    router.post(`/tests/${test.slug}/run`, {
      answers:    normalized,
      started_at: startedAt.value,
      time_spent: elapsed.value,
    })
  }

  function optionStyle(q, opt) {
    const sel = answers.value[q.id]
    const selected = q.type === 'multiple' ? sel?.includes(opt.id) : sel === opt.id
    if (selected) return { background: '#EEF0FF', border: '1px solid #4F63F5' }
    return { background: '#F7F8FA', border: '1px solid transparent' }
  }

  function optionLetterStyle(q, opt) {
    const sel = answers.value[q.id]
    const selected = q.type === 'multiple' ? sel?.includes(opt.id) : sel === opt.id
    if (selected) return { background: '#4F63F5', color: '#fff', borderColor: '#4F63F5' }
    return { background: '#fff', color: '#9CA3AF', borderColor: '#E5E7EB' }
  }

  function formatText(text) {
    return text.replace(/`([^`]+)`/g, '<code class="bg-gray-100 rounded px-1 py-0.5 text-sm font-mono">$1</code>')
  }

  const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']
  function optionLetter(idx) {
    return LETTERS[idx] || String(idx + 1)
  }

  return {
    questions,
    answers,
    savedIndex,
    answeredCount,
    timeDisplay,
    timerWarning,
    isAnswered,
    optionStyle,
    optionLetterStyle,
    optionLetter,
    formatText,
    updateIndex,
    saveSession,
    submit,
  }
}
