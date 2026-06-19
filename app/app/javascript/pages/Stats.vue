<template>
  <AppLayout>
    <h1 class="text-2xl font-bold mb-6">Общая статистика</h1>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-10">
      <div v-for="s in globalCards" :key="s.label" class="card border border-gray-100 shadow-sm p-5 text-center">
        <div class="text-2xl font-bold" style="color:#4F63F5">{{ s.value }}</div>
        <div class="text-xs text-gray-500 mt-1">{{ s.label }}</div>
      </div>
    </div>

    <h2 class="font-semibold text-lg mb-4">Топ тестов по популярности</h2>
    <div class="flex flex-col gap-3 mb-10">
      <Link
        v-for="(t, i) in topTests" :key="t.slug"
        :href="`/tests/${t.slug}`"
        class="card border border-gray-100 shadow-sm p-4 flex items-center gap-4 hover:shadow-md transition-shadow"
      >
        <span class="text-2xl font-bold w-8 text-gray-200">{{ i + 1 }}</span>
        <div class="flex-1">
          <p class="font-medium text-sm">{{ t.title }}</p>
          <p class="text-xs text-gray-400">{{ t.attempts_count }} попыток · avg {{ t.avg_score.toFixed(0) }}%</p>
        </div>
        <div class="text-right">
          <div class="text-sm font-semibold" :style="{ color: passColor(t.pass_rate) }">
            {{ t.pass_rate.toFixed(0) }}%
          </div>
          <div class="text-xs text-gray-400">проходят</div>
        </div>
      </Link>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({
  global:          Object,
  topTests:        Array,
  recentAttempts:  Array,
})

const globalCards = computed(() => [
  { label: 'Всего попыток',  value: props.global.total_attempts },
  { label: 'Пользователей',  value: props.global.total_users },
  { label: 'Тестов',         value: props.global.total_tests },
  { label: 'Средний балл',   value: props.global.avg_score.toFixed(1) + '%' },
])

function passColor(r) {
  if (r >= 70) return '#10B981'
  if (r >= 40) return '#F59E0B'
  return '#EF4444'
}
</script>
