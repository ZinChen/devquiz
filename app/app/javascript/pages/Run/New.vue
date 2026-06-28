<template>
  <AppLayout>
    <div class="run-header">
      <nav class="run-breadcrumbs">
        <Link href="/" class="run-breadcrumbs__link">Все тесты</Link>
        <Link :href="`/tests/${test.slug}`" class="run-breadcrumbs__link">← {{ test.title }}</Link>
      </nav>
      <div class="run-header__right">
        <div class="run-header__progress">
          {{ answeredCount }} / {{ questions.length }}
          <span class="run-header__timer" :class="{ 'run-header__timer--warn': timerWarning }">{{ timeDisplay }}</span>
        </div>
        <button
          @click="settingsOpen = !settingsOpen"
          class="run-header__settings-btn"
          title="Настройки"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
        </button>
      </div>
    </div>

    <div class="run-settings-wrap">
      <SettingsPanel
        v-if="settingsOpen"
        v-model:mode="mode"
        v-model:challengeMode="challengeMode"
        :hasCodeChallenge="hasCodeChallenge"
      />
    </div>

    <component
      :is="activeMode"
      :questions="questions"
      :answers="answers"
      :answeredCount="answeredCount"
      :bookmarkedIds="bookmarkedIds"
      :isAnswered="isAnswered"
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
import AppLayout from '@/components/AppLayout.vue'
import SettingsPanel from '@/components/run/SettingsPanel.vue'
import OneByOneMode from '@/components/run/OneByOneMode.vue'
import AllAtOnceMode from '@/components/run/AllAtOnceMode.vue'
import { useQuizSession } from '@/composables/useQuizSession.js'

const props = defineProps({ test: Object, questions: Array, bookmarkedIds: { type: Array, default: () => [] } })

const settingsOpen = ref(false)
const mode         = ref(localStorage.getItem('devquiz_mode') || 'all')

watch(mode, val => localStorage.setItem('devquiz_mode', val))

const modeComponents = { one: OneByOneMode, all: AllAtOnceMode }
const activeMode = computed(() => modeComponents[mode.value])

const {
  questions,
  answers,
  challengeMode,
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
  submit,
} = useQuizSession(props.test, props.questions)

const hasCodeChallenge = computed(() =>
  props.questions.some(q => q.type === 'code_challenge')
)
</script>

<style scoped>
.run-header {
  margin: 0 auto 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.run-settings-wrap {
  margin-bottom: 0;
}

.run-breadcrumbs {
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 0.875rem;
}

.run-breadcrumbs__link {
  color: #9CA3AF;
  transition: color 0.15s;
}

.run-breadcrumbs__link:hover {
  color: #4B5563;
}

.run-header__right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.run-header__progress {
  font-size: 0.875rem;
  color: #6B7280;
}

.run-header__timer {
  margin-left: 1rem;
  font-family: monospace;
  color: #4B5563;
}

.run-header__timer--warn {
  color: #EF4444;
}

.run-header__settings-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  color: #9CA3AF;
  background: transparent;
  border: none;
  cursor: pointer;
  transition: color 0.15s, background-color 0.15s;
}

.run-header__settings-btn:hover {
  color: #4B5563;
  background: #F3F4F6;
}
</style>
