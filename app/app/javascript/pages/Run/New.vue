<template>
  <AppLayout>
    <div class="max-w-2xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <Link :href="`/tests/${test.slug}`" class="text-sm text-gray-400 hover:text-gray-600">← {{ test.title }}</Link>
        <div class="flex items-center gap-3">
          <div class="text-sm text-gray-500">
            {{ answeredCount }} / {{ questions.length }}
            <span class="ml-4 font-mono" :class="timerWarning ? 'text-red-500' : 'text-gray-600'">{{ timeDisplay }}</span>
          </div>
          <button
            @click="settingsOpen = !settingsOpen"
            class="p-2 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
            title="Настройки"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
          </button>
        </div>
      </div>

      <SettingsPanel
        v-if="settingsOpen"
        v-model:mode="mode"
      />

      <component
        :is="activeMode"
        :questions="questions"
        :answers="answers"
        :answeredCount="answeredCount"
        :isAnswered="isAnswered"
        :optionStyle="optionStyle"
        :optionLetterStyle="optionLetterStyle"
        :optionLetter="optionLetter"
        :formatText="formatText"
        :savedIndex="savedIndex"
        @submit="submit"
        @index-change="updateIndex"
      />
    </div>
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

const props = defineProps({ test: Object, questions: Array })

const settingsOpen = ref(false)
const mode         = ref(localStorage.getItem('devquiz_mode') || 'all')

watch(mode, val => localStorage.setItem('devquiz_mode', val))

const modeComponents = { one: OneByOneMode, all: AllAtOnceMode }
const activeMode = computed(() => modeComponents[mode.value])

const {
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
  submit,
} = useQuizSession(props.test, props.questions)
</script>
