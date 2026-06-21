<template>
  <AppLayout>
    <h1 class="stats-title">Общая статистика</h1>

    <div class="stats-cards">
      <div v-for="s in globalCards" :key="s.label" class="stat-card">
        <div class="stat-card__value">{{ s.value }}</div>
        <div class="stat-card__label">{{ s.label }}</div>
      </div>
    </div>

    <h2 class="stats-section-title">Топ тестов по популярности</h2>
    <div class="top-tests">
      <Link
        v-for="(t, i) in topTests" :key="t.slug"
        :href="`/tests/${t.slug}`"
        class="top-test-row"
      >
        <span class="top-test-row__rank">{{ i + 1 }}</span>
        <div class="top-test-row__info">
          <p class="top-test-row__title">{{ t.title }}</p>
          <p class="top-test-row__meta">{{ t.attemptsCount }} попыток · avg {{ (t.avgScore ?? 0).toFixed(0) }}%</p>
        </div>
        <div class="top-test-row__pass">
          <div class="top-test-row__pass-rate" :style="{ color: passColor(t.passRate) }">
            {{ (t.passRate ?? 0).toFixed(0) }}%
          </div>
          <div class="top-test-row__pass-label">проходят</div>
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
  global:         Object,
  topTests:       Array,
  recentAttempts: Array,
})

const globalCards = computed(() => [
  { label: 'Всего попыток',  value: props.global.totalAttempts },
  { label: 'Пользователей',  value: props.global.totalUsers },
  { label: 'Тестов',         value: props.global.totalTests },
  { label: 'Средний балл',   value: (props.global.avgScore ?? 0).toFixed(1) + '%' },
])

function passColor(r) {
  if (r >= 70) return '#10B981'
  if (r >= 40) return '#F59E0B'
  return '#EF4444'
}
</script>

<style scoped>
.stats-title {
  font-size: 1.5rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
}

.stats-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
  margin-bottom: 2.5rem;
}

@media (min-width: 768px) {
  .stats-cards { grid-template-columns: repeat(4, 1fr); }
}

.stat-card {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  text-align: center;
}

.stat-card__value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #4F63F5;
}

.stat-card__label {
  font-size: 0.75rem;
  color: #6B7280;
  margin-top: 0.25rem;
}

.stats-section-title {
  font-weight: 600;
  font-size: 1.125rem;
  margin-bottom: 1rem;
}

.top-tests {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 2.5rem;
}

.top-test-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem;
  transition: box-shadow 0.15s;
}

.top-test-row:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.top-test-row__rank {
  font-size: 1.5rem;
  font-weight: 700;
  color: #E5E7EB;
  width: 2rem;
  flex-shrink: 0;
}

.top-test-row__info {
  flex: 1;
}

.top-test-row__title {
  font-weight: 500;
  font-size: 0.875rem;
}

.top-test-row__meta {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.top-test-row__pass {
  text-align: right;
}

.top-test-row__pass-rate {
  font-size: 0.875rem;
  font-weight: 600;
}

.top-test-row__pass-label {
  font-size: 0.75rem;
  color: #9CA3AF;
}
</style>
