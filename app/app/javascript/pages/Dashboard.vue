<template>
  <AppLayout>
    <h1 class="dashboard-title">Мой кабинет</h1>

    <div class="dashboard-cards">
      <div v-for="s in summaryCards" :key="s.label" class="stat-card">
        <div class="stat-card__value">{{ s.value }}</div>
        <div class="stat-card__label">{{ s.label }}</div>
      </div>
    </div>

    <h2 class="dashboard-section-title">История прохождений</h2>

    <div v-if="attempts.length" class="attempts-list">
      <div
        v-for="a in attempts" :key="a.id"
        class="attempt-row"
      >
        <div>
          <p class="attempt-row__title">{{ a.testTitle }}</p>
          <p class="attempt-row__date">{{ formatDate(a.completedAt) }}</p>
        </div>
        <div class="attempt-row__score-wrap">
          <span class="attempt-row__count">{{ a.correctCount }}/{{ a.totalQuestions }}</span>
          <span class="attempt-row__score" :style="{ color: scoreColor(a.score) }">{{ a.score.toFixed(0) }}%</span>
        </div>
      </div>
    </div>

    <div v-else class="dashboard-empty">
      <p>Вы ещё не прошли ни одного теста</p>
      <Link href="/" class="btn btn-sm btn-primary dashboard-empty__btn">
        К тестам
      </Link>
    </div>

    <h2 class="dashboard-section-title">Избранные вопросы</h2>

    <div v-if="bookmarks.length" class="bookmarks-list">
      <div
        v-for="b in bookmarks" :key="b.id"
        class="bookmark-card"
      >
        <div class="bookmark-card__header">
          <span class="bookmark-card__test">{{ b.testTitle }}</span>
          <button class="bookmark-remove" title="Убрать из избранного" @click="removeBookmark(b)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
            </svg>
          </button>
        </div>
        <p class="bookmark-card__text">{{ b.questionText }}</p>
        <div class="bookmark-card__options">
          <div
            v-for="opt in b.options" :key="opt.id"
            class="bookmark-option"
            :class="b.correctIds.includes(opt.id) ? 'bookmark-option--correct' : ''"
          >
            {{ opt.text }}
          </div>
        </div>
        <p v-if="b.explanation" class="bookmark-card__explanation">{{ b.explanation }}</p>
      </div>
    </div>

    <div v-else class="dashboard-empty dashboard-empty--sm">
      <p>Нет избранных вопросов</p>
      <p class="dashboard-empty__hint">Добавляйте вопросы в избранное во время прохождения теста</p>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import axios from 'axios'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({
  attempts:  Array,
  stats:     Object,
  bookmarks: { type: Array, default: () => [] },
})

const bookmarks = ref(props.bookmarks)

const summaryCards = computed(() => [
  { label: 'Попыток',           value: props.stats.totalAttempts },
  { label: 'Средний балл',      value: props.stats.avgScore.toFixed(1) + '%' },
  { label: 'Лучший результат',  value: props.stats.bestScore.toFixed(0) + '%' },
  { label: 'Тестов пройдено',   value: props.stats.testsCompleted },
])

async function removeBookmark(b) {
  try {
    await axios.delete('/bookmarks', { data: { question_id: b.questionId } })
    bookmarks.value = bookmarks.value.filter(x => x.id !== b.id)
  } catch {}
}

function scoreColor(s) {
  if (s >= 80) return '#10B981'
  if (s >= 50) return '#F59E0B'
  return '#EF4444'
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
}
</script>

<style scoped>
.dashboard-title {
  font-size: 1.5rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
}

.dashboard-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

@media (min-width: 768px) {
  .dashboard-cards { grid-template-columns: repeat(4, 1fr); }
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

.dashboard-section-title {
  font-weight: 600;
  font-size: 1.125rem;
  margin-bottom: 1rem;
}

.attempts-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 2.5rem;
}

.attempt-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem;
}

.attempt-row__title {
  font-weight: 500;
  font-size: 0.875rem;
}

.attempt-row__date {
  font-size: 0.75rem;
  color: #9CA3AF;
  margin-top: 0.125rem;
}

.attempt-row__score-wrap {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.attempt-row__count {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.attempt-row__score {
  font-weight: 700;
  font-size: 1.125rem;
}

.dashboard-empty {
  text-align: center;
  padding: 3rem 0;
  color: #9CA3AF;
  margin-bottom: 2.5rem;
}

.dashboard-empty--sm {
  padding: 2.5rem 0;
  margin-bottom: 0;
}

.dashboard-empty__btn {
  margin-top: 1rem;
}

.dashboard-empty__hint {
  font-size: 0.75rem;
  margin-top: 0.25rem;
}

.bookmarks-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.bookmark-card {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: 0.75rem;
  padding: 1.25rem;
}

.bookmark-card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.bookmark-card__test {
  font-size: 0.75rem;
  color: #6366F1;
  font-weight: 500;
}

.bookmark-remove {
  background: none;
  border: none;
  cursor: pointer;
  color: #6366F1;
  padding: 0.125rem;
  display: flex;
  align-items: center;
  opacity: 0.7;
  transition: opacity 0.15s;
}

.bookmark-remove:hover {
  opacity: 1;
}

.bookmark-card__text {
  font-size: 0.9rem;
  font-weight: 500;
  line-height: 1.5;
  margin-bottom: 0.75rem;
}

.bookmark-card__options {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  margin-bottom: 0.75rem;
}

.bookmark-option {
  font-size: 0.8rem;
  color: #6B7280;
  padding: 0.35rem 0.6rem;
  border-radius: 0.4rem;
  background: #F9FAFB;
}

.bookmark-option--correct {
  background: #ECFDF5;
  color: #059669;
  font-weight: 500;
}

.bookmark-card__explanation {
  font-size: 0.8rem;
  color: #9CA3AF;
  border-top: 1px solid #F3F4F6;
  padding-top: 0.6rem;
  margin-top: 0.25rem;
}
</style>
