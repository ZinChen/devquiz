<template>
  <!-- Разбор рисует тот же компонент, что и обычную попытку: тренировка
       отличается только источником вопросов, а не тем, как читается
       результат. -->
  <RunShow
    v-if="result"
    practice
    :test="test"
    :attempt="result.attempt"
    :answers-detail="result.answersDetail"
    :bookmarked-ids="bookmarkedIds"
    @retry="retry"
  />

  <AppLayout v-else>
    <div class="practice-header">
      <nav class="practice-breadcrumbs">
        <Link href="/dashboard" class="practice-breadcrumbs__link">← Мой кабинет</Link>
      </nav>
      <div class="practice-header__right">
        <div class="practice-header__progress">
          {{ answeredCount }} / {{ sessionQuestions.length }}
          <span class="practice-header__timer">{{ timeDisplay }}</span>
        </div>
        <button
          type="button"
          @click="settingsOpen = !settingsOpen"
          class="practice-header__settings-btn"
          title="Настройки"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
        </button>
      </div>
    </div>

    <h1 class="practice-title">
      <span
        v-if="topic.color"
        class="practice-title__dot"
        :style="{ background: topic.color }"
        aria-hidden="true"
      ></span>
      {{ topic.label }}
    </h1>
    <p v-if="topic.description" class="practice-title__description">{{ topic.description }}</p>

    <div class="practice-banner">
      Тренировка по теме: вопросы, где вы ошибались, собраны из разных тестов.
      В статистику тестов результат не идёт.
    </div>

    <div class="practice-settings-wrap">
      <SettingsPanel
        v-if="settingsOpen"
        v-model:mode="mode"
        v-model:challengeMode="challengeMode"
        :hasCodeChallenge="false"
        :locked="sessionStarted"
        :completedChallengeModes="[]"
        @reset="resetChallenge"
      />
    </div>

    <p v-if="gradeError" class="practice-error" role="alert">{{ gradeError }}</p>

    <component
      :is="activeMode"
      :questions="sessionQuestions"
      :answers="answers"
      :answeredCount="answeredCount"
      :bookmarkedIds="bookmarkedIds"
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

const props = defineProps({
  topic:         Object,
  questions:     { type: Array, default: () => [] },
  bookmarkedIds: { type: Array, default: () => [] },
})

const settingsOpen = ref(false)
const mode         = ref(localStorage.getItem('devquiz_mode') || 'all')
const result       = ref(null)
const gradeError   = ref('')

watch(mode, val => localStorage.setItem('devquiz_mode', val))

const modeComponents = { one: OneByOneMode, all: AllAtOnceMode }
const activeMode = computed(() => modeComponents[mode.value])

// Вопросы приходят из разных тестов, а id в YAML уникален только внутри
// своего (q1 есть почти в каждом). Ключом вопроса на всё прохождение
// становится сквозной uid: на голом id два вопроса делили бы один слот в
// answers — ответ на один отмечался бы и у другого.
const questions = computed(() =>
  props.questions.map(q => ({ ...q, id: q.uid }))
)

// Тема подставляется вместо теста: общим компонентам нужен только slug,
// заголовок и признаки, от которых зависит шапка результата. Code challenge
// в тренировку не попадает — вопросы такого типа отфильтрованы на бэкенде.
const test = computed(() => ({
  slug:                      props.topic.slug,
  title:                     props.topic.label,
  hasCodeChallenge:          false,
  completedChallengeModes:   [],
}))

// Ответы уходят на свой grade: попытку по тренировке приписать одному тесту
// нельзя, их пишется по одной на каждый исходный.
async function gradeAnswers(payload) {
  gradeError.value = ''

  try {
    // Через axios, а не fetch: его интерцептор уже приводит ключи ответа
    // к camelCase и подставляет CSRF-токен.
    const { data } = await axios.post(`/practice/topic/${props.topic.slug}/grade`, payload)
    result.value = data
    window.scrollTo({ top: 0 })
  } catch (e) {
    gradeError.value = 'Не удалось проверить ответы. Попробуйте ещё раз.'
  }
}

const {
  questions: sessionQuestions,
  answers,
  challengeMode,
  savedIndex,
  sessionStarted,
  answeredCount,
  timeDisplay,
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
} = useQuizSession(test.value, questions.value, {
  onSubmit: gradeAnswers,
  // Свой ключ на тему: набор вопросов здесь сквозной, и на ключе теста
  // незаконченная тренировка подменяла бы его обычное прохождение. v2 —
  // потому что черновики до перехода на uid ключуются по голым id и к
  // восстановлению уже не годятся.
  storageKey: `devquiz_session_practice_v2_${props.topic.slug}`,
})

function retry() {
  result.value = null
  resetChallenge()
}
</script>

<style scoped>
.practice-header {
  margin: 0 auto 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.practice-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.875rem;
}

.practice-breadcrumbs__link {
  color: #9CA3AF;
  transition: color 0.15s;
}

.practice-breadcrumbs__link:hover {
  color: #4B5563;
}

.practice-header__right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.practice-header__progress {
  font-size: 0.875rem;
  color: #6B7280;
}

.practice-header__timer {
  margin-left: 1rem;
  font-family: monospace;
  color: #4B5563;
}

.practice-header__settings-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  color: #9CA3AF;
  background: transparent;
  border: none;
  cursor: pointer;
  transition: color 0.15s, background-color 0.15s;
}

.practice-header__settings-btn:hover {
  color: #4B5563;
  background: #F3F4F6;
}

.practice-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.5rem;
  font-weight: 700;
}

.practice-title__dot {
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.practice-title__description {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: #6B7280;
}

.practice-banner {
  padding: 0.625rem 0.875rem;
  margin: 1rem 0 1.25rem;
  border: 1px solid #FDE68A;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FFFBEB;
  color: #92400E;
  font-size: 0.8125rem;
  line-height: 1.45;
}

.practice-settings-wrap {
  margin-bottom: 0;
}

.practice-error {
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  border: 1px solid #FCA5A5;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FEF2F2;
  color: #991B1B;
  font-size: 0.875rem;
}
</style>
