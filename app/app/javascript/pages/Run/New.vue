<template>
  <AppLayout>
    <div class="run-header">
      <nav class="run-breadcrumbs">
        <Link href="/" class="run-breadcrumbs__link">Все тесты</Link>
        <Link :href="`/tests/${test.slug}`" class="run-breadcrumbs__link">← {{ test.title }}</Link>
      </nav>
      <div class="run-header__right">
        <span v-if="hasCodeChallenge" class="run-header__mode-badge-wrap" :class="{ 'run-header__mode-badge-wrap--open': modeTooltipOpen }">
          <span class="run-header__mode-badge">
            {{ CHALLENGE_MODE_LABELS[challengeMode] }}
            <button
              type="button"
              class="run-header__mode-badge-icon"
              @click.stop="modeTooltipOpen = !modeTooltipOpen"
            >i</button>
          </span>
          <div class="run-header__mode-tooltip">
            Режим кода: {{ CHALLENGE_MODE_HINTS[challengeMode] }}
          </div>
        </span>
        <div class="run-header__progress">
          {{ answeredCount }} / {{ questions.length }}
          <span class="run-header__timer" :class="{ 'run-header__timer--warn': timerWarning }">{{ timeDisplay }}</span>
        </div>
        <button
          type="button"
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
        :locked="sessionStarted"
        :completedChallengeModes="test.completedChallengeModes || []"
        @reset="resetChallenge"
      />
    </div>

    <component
      :is="activeMode"
      :questions="questions"
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
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import SettingsPanel from '@/components/run/SettingsPanel.vue'
import OneByOneMode from '@/components/run/OneByOneMode.vue'
import AllAtOnceMode from '@/components/run/AllAtOnceMode.vue'
import { useQuizSession } from '@/composables/useQuizSession.js'
import { CHALLENGE_MODE_LABELS, CHALLENGE_MODE_HINTS } from '@/composables/challengeModes.js'

const props = defineProps({ test: Object, questions: Array, bookmarkedIds: { type: Array, default: () => [] } })

const settingsOpen     = ref(false)
const modeTooltipOpen  = ref(false)
const mode             = ref(localStorage.getItem('devquiz_mode') || 'all')

function closeModeTooltip() { modeTooltipOpen.value = false }
onMounted(() => document.addEventListener('click', closeModeTooltip))
onUnmounted(() => document.removeEventListener('click', closeModeTooltip))

watch(mode, val => localStorage.setItem('devquiz_mode', val))

const modeComponents = { one: OneByOneMode, all: AllAtOnceMode }
const activeMode = computed(() => modeComponents[mode.value])

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

.run-header__mode-badge-wrap {
  position: relative;
}

.run-header__mode-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: #EEF0FF;
  color: #4F46E5;
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
}

.run-header__mode-badge-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1rem;
  height: 1rem;
  padding: 0;
  border-radius: 50%;
  border: 1px solid #b9b6f8;
  font-size: 0.625rem;
  font-style: italic;
  font-weight: 700;
  font-family: Georgia, 'Times New Roman', serif;
  line-height: 1;
  cursor: pointer;
}

.run-header__mode-badge-icon:hover {
  background: #4338CA;
  color: #fff;
}

.run-header__mode-tooltip {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  z-index: 10;
  width: max-content;
  max-width: 16rem;
  padding: 0.5rem 0.75rem;
  border-radius: 0.5rem;
  background: #1F2937;
  color: #fff;
  font-size: 0.75rem;
  font-weight: 400;
  line-height: 1.4;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  opacity: 0;
  visibility: hidden;
  pointer-events: none;
}

@media (hover: hover) {
  .run-header__mode-badge-wrap:has(.run-header__mode-badge-icon:hover) .run-header__mode-tooltip,
  .run-header__mode-badge-wrap:has(.run-header__mode-badge-icon:focus-visible) .run-header__mode-tooltip {
    opacity: 1;
    visibility: visible;
  }
}

@media (hover: none) {
  .run-header__mode-badge-wrap--open .run-header__mode-tooltip {
    opacity: 1;
    visibility: visible;
  }
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
