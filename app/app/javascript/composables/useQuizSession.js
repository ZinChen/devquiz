import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { router } from '@inertiajs/vue3'

export function useQuizSession(test, questionsSource) {
  const STORAGE_KEY = `devquiz_session_${test.slug}`
  const DEFAULT_CHALLENGE_MODE = test.defaultChallengeMode || 'highlight'

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

  const questions      = ref(resolveQuestions())
  const answers        = ref({})
  const challengeMode  = ref(DEFAULT_CHALLENGE_MODE)
  const startedAt      = ref(new Date().toISOString())
  const elapsed        = ref(0)
  const savedIndex     = ref(resolveSavedIndex())
  const sessionStarted = ref(false)
  let timer
  let saveTimer

  function initAnswers() {
    questions.value.forEach(q => {
      if (q.type === 'multiple') answers.value[q.id] = []
      else if (q.type === 'code_challenge') answers.value[q.id] = initCodeAnswer(q)
      else answers.value[q.id] = null
    })
  }

  function initCodeAnswer(q) {
    if (challengeMode.value === 'highlight') return []
    if (challengeMode.value === 'fix') return q.modes?.fix?.code ?? ''
    return ''
  }

  watch(challengeMode, () => {
    questions.value.forEach(q => {
      if (q.type === 'code_challenge') answers.value[q.id] = initCodeAnswer(q)
    })
  })

  onMounted(() => {
    initAnswers()

    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null')
      if (saved) {
        const hasAnswers = saved.answers && Object.values(saved.answers).some(a =>
          Array.isArray(a) ? a.length > 0 : a !== null
        )

        if (hasAnswers) {
          answers.value   = saved.answers
          startedAt.value = saved.startedAt || startedAt.value
          elapsed.value   = saved.elapsed   || 0
        } else {
          localStorage.removeItem(STORAGE_KEY)
        }
      }
    } catch {}

    timer = setInterval(() => elapsed.value++, 1000)
    saveTimer = setInterval(() => saveSession(), 10000)
    watch(answers, () => saveSession(), { deep: true })
  })

  onUnmounted(() => {
    clearInterval(timer)
    clearInterval(saveTimer)
  })

  function saveSession(extra = {}) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      questions:    questions.value,
      answers:      answers.value,
      startedAt:    startedAt.value,
      elapsed:      elapsed.value,
      currentIndex: savedIndex.value,
      ...extra,
    }))
  }

  function updateIndex(idx) {
    if (!sessionStarted.value && idx !== savedIndex.value) {
      const prevQ = questions.value[savedIndex.value]
      if (prevQ && isAnswered(prevQ)) {
        sessionStarted.value = true
      }
    }
    savedIndex.value = idx
    saveSession()
  }

  const answeredCount = computed(() =>
    questions.value.filter(q => isAnswered(q)).length
  )

  function isAnswered(q) {
    const a = answers.value[q.id]
    if (q.type === 'multiple') return a?.length > 0
    if (q.type === 'code_challenge') {
      if (challengeMode.value === 'highlight') return Array.isArray(a) && a.length > 0
      if (challengeMode.value === 'fix') {
        const original = q.modes?.fix?.code ?? ''
        return typeof a === 'string' && a.trim() !== original.trim()
      }
      return typeof a === 'string' && a.trim().length > 0
    }
    return a !== null
  }

  const timeDisplay = computed(() => {
    const m = Math.floor(elapsed.value / 60).toString().padStart(2, '0')
    const s = (elapsed.value % 60).toString().padStart(2, '0')
    return `${m}:${s}`
  })

  const timerWarning = computed(() =>
    test.estimatedTime && elapsed.value > test.estimatedTime * 60
  )

  function submit() {
    const normalized = {}
    questions.value.forEach(q => {
      const a = answers.value[q.id]
      if (q.type === 'multiple') {
        normalized[q.id] = a || []
      } else if (q.type === 'code_challenge') {
        normalized[q.id] = Array.isArray(a) ? [a.join(',')] : [a || '']
      } else {
        normalized[q.id] = a ? [a] : []
      }
    })
    localStorage.removeItem(STORAGE_KEY)
    router.post(`/tests/${test.slug}/run`, {
      answers:        normalized,
      started_at:     startedAt.value,
      time_spent:     elapsed.value,
      challenge_mode: challengeMode.value,
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
    return text
      .replace(/```[^\n]*\n?([\s\S]*?)```/g, (_, code) => `<pre class="code-block"><code>${escapeHtml(code.trimEnd())}</code></pre>`)
      .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')
  }

  function escapeHtml(str) {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  }

  const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']
  function optionLetter(idx) {
    return LETTERS[idx] || String(idx + 1)
  }

  return {
    questions,
    answers,
    challengeMode,
    savedIndex,
    sessionStarted,
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
