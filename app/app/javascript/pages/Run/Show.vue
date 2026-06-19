<template>
  <AppLayout>
    <div class="max-w-2xl mx-auto">
      <div class="card border border-gray-100 shadow-sm p-8 mb-6 text-center">
        <p class="text-gray-500 mb-1">Тест завершён: {{ test.title }}</p>
        <div class="text-6xl font-bold my-4" :style="{ color: scoreColor }">
          {{ attempt.score.toFixed(0) }}%
        </div>
        <p class="text-gray-600 mb-2">
          {{ attempt.correct_count }} правильных из {{ attempt.total_questions }}
        </p>
        <p class="text-sm text-gray-400">Время: {{ formatTime(attempt.time_spent) }}</p>

        <div class="flex justify-center gap-3 mt-6">
          <Link :href="`/tests/${test.slug}/run/new`" class="btn" style="background:#4F63F5;color:#fff;border:none">
            Пройти снова
          </Link>
          <Link href="/" class="btn btn-ghost">Все тесты</Link>
        </div>
      </div>

      <h2 class="font-semibold text-lg mb-4">Разбор ответов</h2>

      <div
        v-for="(item, idx) in answersDetail" :key="item.question_id"
        class="card border shadow-sm p-5 mb-3"
        :style="{ borderColor: item.correct ? '#10B98130' : '#EF444430' }"
      >
        <div class="flex items-start gap-2 mb-3">
          <span
            class="badge badge-sm shrink-0 mt-0.5"
            :style="item.correct ? 'background:#D1FAE5;color:#065F46;border:none' : 'background:#FEE2E2;color:#991B1B;border:none'"
          >
            {{ item.correct ? '✓' : '✗' }}
          </span>
          <p class="text-sm font-medium" v-html="formatText(item.question_text)"></p>
        </div>

        <div class="flex flex-col gap-1 text-sm mb-3">
          <div
            v-for="opt in item.options" :key="opt.id"
            class="px-3 py-1.5 rounded-lg"
            :style="optionStyle(item, opt.id)"
          >
            {{ opt.text }}
          </div>
        </div>

        <p v-if="item.explanation" class="text-xs text-gray-500 border-t border-gray-100 pt-3 mt-1">
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
  return text?.replace(/`([^`]+)`/g, '<code class="bg-gray-100 rounded px-1 py-0.5 text-sm font-mono">$1</code>') || ''
}

function optionStyle(item, optId) {
  const isCorrect  = item.correct_ids.includes(optId)
  const isSelected = item.selected_options.includes(optId)
  if (isCorrect)  return { background: '#D1FAE5', color: '#065F46' }
  if (isSelected) return { background: '#FEE2E2', color: '#991B1B' }
  return { background: '#F7F8FA', color: '#374151' }
}
</script>
