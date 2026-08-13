<template>
  <!-- Результат приходит от /preview/grade и рисуется тем же компонентом, что
       и обычная попытка: разбор ответов должен выглядеть одинаково. -->
  <RunShow
    v-if="result"
    preview
    :test="test"
    :attempt="result.attempt"
    :answers-detail="result.answersDetail"
    @retry="retry"
  />

  <AppLayout v-else>
    <div class="preview-header">
      <nav class="preview-breadcrumbs">
        <Link href="/" class="preview-breadcrumbs__link">Все тесты</Link>
        <span class="preview-breadcrumbs__badge">Тест из файла</span>
      </nav>
      <div class="preview-header__right">
        <span v-if="hasCodeChallenge" class="preview-header__mode-badge">
          {{ CHALLENGE_MODE_LABELS[challengeMode] }}
        </span>
        <div class="preview-header__progress">
          {{ answeredCount }} / {{ questions.length }}
          <span class="preview-header__timer" :class="{ 'preview-header__timer--warn': timerWarning }">{{ timeDisplay }}</span>
        </div>
        <button
          type="button"
          @click="settingsOpen = !settingsOpen"
          class="preview-header__settings-btn"
          title="Настройки"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
        </button>
      </div>
    </div>

    <div class="preview-banner">
      <span class="preview-banner__title">{{ test.title }}</span>
      <span class="preview-banner__text">Прохождение разовое: результат не попадёт в статистику, но в конце его можно скачать.</span>
    </div>

    <div class="preview-settings-wrap">
      <SettingsPanel
        v-if="settingsOpen"
        v-model:mode="mode"
        v-model:challengeMode="challengeMode"
        :hasCodeChallenge="hasCodeChallenge"
        :locked="sessionStarted"
        :completedChallengeModes="[]"
        @reset="resetChallenge"
      />
    </div>

    <p v-if="gradeError" class="preview-error" role="alert">{{ gradeError }}</p>

    <component
      :is="activeMode"
      :questions="questions"
      :answers="answers"
      :answeredCount="answeredCount"
      :bookmarkedIds="[]"
      :isAnswered="isAnswered"
      :isHintShown="isHintShown"
      :markHintUsed="markHintUsed"
      :optionStyle="optionStyle"
      :optionLetterStyle="optionLetterStyle"
      :optionLetter="optionLetter"
      :formatText="formatText"
      :savedIndex="savedIndex"
      :challengeMode="challengeMode"
      @submit="submit"
      @index-change="updateIndex"
    />
  </AppLayout>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Link } from '@inertiajs/vue3'
import axios from 'axios'
import AppLayout from '@/components/AppLayout.vue'
import RunShow from '@/pages/Run/Show.vue'
import SettingsPanel from '@/components/run/SettingsPanel.vue'
import OneByOneMode from '@/components/run/OneByOneMode.vue'
import AllAtOnceMode from '@/components/run/AllAtOnceMode.vue'
import { useQuizSession } from '@/composables/useQuizSession.js'
import { CHALLENGE_MODE_LABELS } from '@/composables/challengeModes.js'
import { takeStashedDefinition, definitionFingerprint } from '@/composables/useDroppedTest.js'

const props = defineProps({ test: Object, questions: Array })

const settingsOpen = ref(false)
const mode         = ref(localStorage.getItem('devquiz_mode') || 'all')
const result       = ref(null)
const gradeError   = ref('')

watch(mode, val => localStorage.setItem('devquiz_mode', val))

const modeComponents = { one: OneByOneMode, all: AllAtOnceMode }
const activeMode = computed(() => modeComponents[mode.value])

// Определение берём из sessionStorage в исходном snake_case: пропсы, которыми
// нарисована эта страница, уже камелизованы, и по ним сервер не нашёл бы
// correct_lines/insert_text у code_challenge.
const definition = takeStashedDefinition()

// Определение теста живёт только здесь, поэтому уходит на сервер вместе с
// ответами: проверять их по нему — единственный способ не дублировать
// правила подсчёта на клиенте.
async function gradeAnswers(payload) {
  gradeError.value = ''

  if (!definition) {
    gradeError.value = 'Файл теста потерялся — перетащите его на список тестов ещё раз.'
    return
  }

  try {
    const { data } = await axios.post('/preview/grade', {
      ...payload,
      test: definition,
    })
    result.value = data
    window.scrollTo({ top: 0 })
  } catch (e) {
    gradeError.value = e.response?.data?.errors?.join('; ')
      || 'Не удалось проверить ответы. Попробуйте ещё раз.'
  }
}

const {
  questions,
  answers,
  challengeMode,
  savedIndex,
  sessionStarted,
  answeredCount,
  timeDisplay,
  timerWarning,
  isAnswered,
  isHintShown,
  markHintUsed,
  optionStyle,
  optionLetterStyle,
  optionLetter,
  formatText,
  updateIndex,
  resetChallenge,
  submit,
} = useQuizSession(props.test, props.questions, {
  onSubmit:   gradeAnswers,
  // Свой ключ на каждый файл: у разовых тестов нет slug, и на общем ключе
  // следующий дропнутый файл подхватил бы ответы предыдущего.
  storageKey: `devquiz_session_preview_${definition ? definitionFingerprint(definition) : 'unknown'}`,
})

const hasCodeChallenge = computed(() =>
  props.questions.some(q => q.type === 'code_challenge')
)

function retry() {
  result.value = null
  resetChallenge()
}
</script>

<style scoped>
.preview-header {
  margin: 0 auto 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.preview-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.875rem;
}

.preview-breadcrumbs__link {
  color: #9CA3AF;
  transition: color 0.15s;
}

.preview-breadcrumbs__link:hover {
  color: #4B5563;
}

.preview-breadcrumbs__badge {
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: #FEF3C7;
  color: #92400E;
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
}

.preview-header__right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.preview-header__mode-badge {
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: #EEF0FF;
  color: #4F46E5;
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
}

.preview-header__progress {
  font-size: 0.875rem;
  color: #6B7280;
}

.preview-header__timer {
  margin-left: 1rem;
  font-family: monospace;
  color: #4B5563;
}

.preview-header__timer--warn {
  color: #EF4444;
}

.preview-header__settings-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  color: #9CA3AF;
  background: transparent;
  border: none;
  cursor: pointer;
  transition: color 0.15s, background-color 0.15s;
}

.preview-header__settings-btn:hover {
  color: #4B5563;
  background: #F3F4F6;
}

.preview-banner {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  margin-bottom: 1.25rem;
  border: 1px solid #FDE68A;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FFFBEB;
}

.preview-banner__title {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #92400E;
}

.preview-banner__text {
  font-size: 0.8125rem;
  color: #B45309;
}

.preview-settings-wrap {
  margin-bottom: 0;
}

.preview-error {
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  border: 1px solid #FCA5A5;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FEF2F2;
  color: #991B1B;
  font-size: 0.875rem;
}
</style>
