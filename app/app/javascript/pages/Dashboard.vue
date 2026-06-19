<template>
  <AppLayout>
    <h1 class="text-2xl font-bold mb-6">Мой кабинет</h1>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <div v-for="s in summaryCards" :key="s.label" class="card border border-gray-100 shadow-sm p-5 text-center">
        <div class="text-2xl font-bold" style="color:#4F63F5">{{ s.value }}</div>
        <div class="text-xs text-gray-500 mt-1">{{ s.label }}</div>
      </div>
    </div>

    <h2 class="font-semibold text-lg mb-4">История прохождений</h2>

    <div v-if="attempts.length" class="flex flex-col gap-3">
      <div
        v-for="a in attempts" :key="a.id"
        class="card border border-gray-100 shadow-sm p-4 flex items-center justify-between"
      >
        <div>
          <p class="font-medium text-sm">{{ a.test_title }}</p>
          <p class="text-xs text-gray-400 mt-0.5">{{ formatDate(a.completed_at) }}</p>
        </div>
        <div class="flex items-center gap-6">
          <span class="text-xs text-gray-400">{{ a.correct_count }}/{{ a.total_questions }}</span>
          <span
            class="font-bold text-lg"
            :style="{ color: scoreColor(a.score) }"
          >{{ a.score.toFixed(0) }}%</span>
        </div>
      </div>
    </div>

    <div v-else class="text-center py-12 text-gray-400">
      <p>Вы ещё не прошли ни одного теста</p>
      <Link href="/" class="btn btn-sm mt-4" style="background:#4F63F5;color:#fff;border:none">
        К тестам
      </Link>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({
  attempts: Array,
  stats:    Object,
})

const summaryCards = computed(() => [
  { label: 'Попыток',        value: props.stats.total_attempts },
  { label: 'Средний балл',   value: props.stats.avg_score.toFixed(1) + '%' },
  { label: 'Лучший результат', value: props.stats.best_score.toFixed(0) + '%' },
  { label: 'Тестов пройдено',  value: props.stats.tests_completed },
])

function scoreColor(s) {
  if (s >= 80) return '#10B981'
  if (s >= 50) return '#F59E0B'
  return '#EF4444'
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
}
</script>
