<template>
  <AppLayout>
    <div class="attempts-page">
      <div class="attempts-page__header">
        <Link :href="`/tests/${test.slug}/run/new`" class="attempts-page__back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
          {{ test.title }}
        </Link>
        <h1 class="attempts-page__title">Попытки</h1>
      </div>

      <div v-if="attempts.length" class="attempts-list">
        <Link
          v-for="(a, idx) in attempts" :key="a.id"
          :href="`/tests/${test.slug}/runs/${a.id}`"
          class="attempt-row"
        >
          <div class="attempt-row__left">
            <span class="attempt-row__num">#{{ attempts.length - idx }}</span>
            <span class="attempt-row__date">{{ formatDate(a.completedAt) }}</span>
          </div>
          <div class="attempt-row__right">
            <span class="attempt-row__count">{{ a.correctCount }}/{{ a.totalQuestions }}</span>
            <span class="attempt-row__time">{{ formatTime(a.timeSpent) }}</span>
            <span class="attempt-row__score" :style="{ color: scoreColor(a.score) }">
              {{ a.score.toFixed(0) }}%
            </span>
          </div>
        </Link>
      </div>

      <div v-else class="attempts-empty">
        <p>По этому тесту ещё нет попыток</p>
        <Link :href="`/tests/${test.slug}/run/new`" class="btn btn-sm btn-primary attempts-empty__btn">
          Пройти тест
        </Link>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

defineProps({
  test:     Object,
  attempts: Array,
})

function scoreColor(s) {
  if (s >= 80) return '#10B981'
  if (s >= 50) return '#F59E0B'
  return '#EF4444'
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

function formatTime(seconds) {
  if (!seconds) return '—'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}м ${s}с`
}
</script>

<style scoped>
.attempts-page {
  max-width: 42rem;
  margin: 0 auto;
}

.attempts-page__header {
  margin-bottom: 1.5rem;
}

.attempts-page__back {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.875rem;
  color: #6B7280;
  text-decoration: none;
  margin-bottom: 0.5rem;
  transition: color 0.15s;
}

.attempts-page__back:hover {
  color: #4F63F5;
}

.attempts-page__title {
  font-size: 1.5rem;
  font-weight: 700;
}

.attempts-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.attempt-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem 1.25rem;
  text-decoration: none;
  color: inherit;
  transition: box-shadow 0.15s;
}

.attempt-row:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.attempt-row__left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.attempt-row__num {
  font-size: 0.75rem;
  font-weight: 600;
  color: #9CA3AF;
  min-width: 1.5rem;
}

.attempt-row__date {
  font-size: 0.875rem;
  color: #4B5563;
}

.attempt-row__right {
  display: flex;
  align-items: center;
  gap: 1.25rem;
}

.attempt-row__count {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.attempt-row__time {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.attempt-row__score {
  font-weight: 700;
  font-size: 1.125rem;
  min-width: 3rem;
  text-align: right;
}

.attempts-empty {
  text-align: center;
  padding: 3rem 0;
  color: #9CA3AF;
}

.attempts-empty__btn {
  margin-top: 1rem;
}
</style>
