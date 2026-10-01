<template>
  <AppLayout>
    <h1 class="stats-title">Общий рейтинг</h1>
    <p class="stats-subtitle">Тесты, которые проходят чаще всего</p>

    <div class="top-tests">
      <Link
        v-for="(t, i) in topTests" :key="t.slug"
        :href="`/tests/${t.slug}`"
        class="top-test-row"
      >
        <span class="top-test-row__rank">{{ i + 1 }}</span>
        <p class="top-test-row__title">{{ t.title }}</p>

        <div class="top-test-row__metric">
          <div class="top-test-row__value">{{ t.attemptsCount }}</div>
          <div class="top-test-row__label">{{ attemptsLabel(t.attemptsCount) }}</div>
        </div>

        <div class="top-test-row__metric">
          <div class="top-test-row__value" :style="{ color: passColor(t.passRate) }">
            {{ (t.passRate ?? 0).toFixed(0) }}%
          </div>
          <div class="top-test-row__label">проходят</div>
        </div>
      </Link>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

defineProps({
  topTests: { type: Array, default: () => [] }
})

function attemptsLabel(count) {
  const n = Math.abs(count) % 100
  if (n >= 11 && n <= 14) return 'прохождений'

  switch (n % 10) {
    case 1:  return 'прохождение'
    case 2:
    case 3:
    case 4:  return 'прохождения'
    default: return 'прохождений'
  }
}

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
}

.stats-subtitle {
  margin: 0.25rem 0 1.5rem;
  font-size: 0.875rem;
  color: #6B7280;
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

.top-test-row__title {
  flex: 1;
  min-width: 0;
  font-weight: 500;
  font-size: 0.875rem;
}

/* Две цифры одной высоты и в фиксированных колонках: иначе числа разной
   длины («5» и «128») сдвигали бы процент от строки к строке. */
.top-test-row__metric {
  flex-shrink: 0;
  width: 6.5rem;
  text-align: right;
}

.top-test-row__value {
  font-size: 1.25rem;
  font-weight: 700;
  color: #374151;
  line-height: 1.2;
}

.top-test-row__label {
  font-size: 0.75rem;
  color: #9CA3AF;
}
</style>
