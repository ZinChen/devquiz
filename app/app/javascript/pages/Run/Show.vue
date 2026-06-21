<template>
  <AppLayout>
    <div class="result-wrap">
      <div class="result-summary">
        <p class="result-summary__label">Тест завершён: {{ test.title }}</p>
        <div class="result-summary__score" :style="{ color: scoreColor }">
          {{ attempt.score.toFixed(0) }}%
        </div>
        <p class="result-summary__correct">
          {{ attempt.correctCount }} правильных из {{ attempt.totalQuestions }}
        </p>
        <p class="result-summary__time">Время: {{ formatTime(attempt.timeSpent) }}</p>

        <div class="result-summary__actions">
          <Link :href="`/tests/${test.slug}/run/new`" class="btn btn-primary">
            Пройти снова
          </Link>
          <Link href="/" class="btn btn-ghost">Все тесты</Link>
        </div>
      </div>

      <h2 class="result-breakdown-title">Разбор ответов</h2>

      <div
        v-for="(item, idx) in answersDetail" :key="item.questionId"
        class="result-item"
        :style="{ borderColor: item.correct ? '#10B98130' : '#EF444430' }"
      >
        <div class="result-item__header">
          <span
            class="result-item__badge"
            :style="item.correct ? 'background:#D1FAE5;color:#065F46' : 'background:#FEE2E2;color:#991B1B'"
          >
            {{ item.correct ? '✓' : '✗' }}
          </span>
          <p class="result-item__question" v-html="formatText(item.questionText)"></p>
        </div>

        <div class="result-item__options">
          <div
            v-for="(opt, oi) in item.options" :key="opt.id"
            class="result-option"
            :style="optionStyle(item, opt.id)"
          >
            <span class="result-option__letter" :style="optionLetterStyle(item, opt.id)">
              {{ optionLetter(oi) }}
            </span>
            {{ opt.text }}
          </div>
        </div>

        <p v-if="item.explanation" class="result-item__explanation">
          {{ item.explanation }}
        </p>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({
  test:           Object,
  attempt:        Object,
  answersDetail:  Array,
})

const scoreColor = computed(() => {
  if (props.attempt.score >= 80) return '#10B981'
  if (props.attempt.score >= 50) return '#F59E0B'
  return '#EF4444'
})

function formatTime(seconds) {
  if (!seconds) return '—'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}м ${s}с`
}

function formatText(text) {
  return text?.replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>') || ''
}

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']
function optionLetter(idx) { return LETTERS[idx] || String(idx + 1) }

function optionStyle(item, optId) {
  const isCorrect  = item.correctIds.includes(optId)
  const isSelected = item.selectedOptions.includes(optId)
  if (isCorrect)  return { background: '#D1FAE5', color: '#065F46' }
  if (isSelected) return { background: '#FEE2E2', color: '#991B1B' }
  return { background: '#F7F8FA', color: '#374151' }
}

function optionLetterStyle(item, optId) {
  const isCorrect  = item.correctIds.includes(optId)
  const isSelected = item.selectedOptions.includes(optId)
  if (isCorrect)  return { background: '#10B981', color: '#fff', borderColor: '#10B981' }
  if (isSelected) return { background: '#EF4444', color: '#fff', borderColor: '#EF4444' }
  return { background: '#fff', color: '#9CA3AF', borderColor: '#E5E7EB' }
}
</script>

<style scoped>
.result-wrap {
  max-width: 42rem;
  margin: 0 auto;
}

.result-summary {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 2rem;
  margin-bottom: 1.5rem;
  text-align: center;
}

.result-summary__label {
  color: #6B7280;
  margin-bottom: 0.25rem;
}

.result-summary__score {
  font-size: 3.75rem;
  font-weight: 700;
  margin: 1rem 0;
}

.result-summary__correct {
  color: #4B5563;
  margin-bottom: 0.5rem;
}

.result-summary__time {
  font-size: 0.875rem;
  color: #9CA3AF;
}

.result-summary__actions {
  display: flex;
  justify-content: center;
  gap: 0.75rem;
  margin-top: 1.5rem;
}

.result-breakdown-title {
  font-weight: 600;
  font-size: 1.125rem;
  margin-bottom: 1rem;
}

.result-item {
  background: #fff;
  border: 1px solid;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  margin-bottom: 0.75rem;
}

.result-item__header {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.result-item__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.125rem 0.4rem;
  border-radius: 999px;
  flex-shrink: 0;
  margin-top: 0.125rem;
}

.result-item__question {
  font-size: 0.875rem;
  font-weight: 500;
}

.result-item__options {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  font-size: 0.875rem;
  margin-bottom: 0.75rem;
}

.result-option {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
}

.result-option__letter {
  flex-shrink: 0;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid;
  margin-top: 0.125rem;
}

.result-item__explanation {
  font-size: 0.75rem;
  color: #6B7280;
  border-top: 1px solid #F3F4F6;
  padding-top: 0.75rem;
  margin-top: 0.25rem;
}

:deep(.inline-code) {
  background: #F3F4F6;
  border-radius: 0.25rem;
  padding: 0.125rem 0.25rem;
  font-size: 0.875rem;
  font-family: monospace;
}
</style>
