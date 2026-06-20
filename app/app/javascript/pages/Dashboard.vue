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

    <div v-if="attempts.length" class="flex flex-col gap-3 mb-10">
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
          <span class="font-bold text-lg" :style="{ color: scoreColor(a.score) }">{{ a.score.toFixed(0) }}%</span>
        </div>
      </div>
    </div>

    <div v-else class="text-center py-12 text-gray-400 mb-10">
      <p>Вы ещё не прошли ни одного теста</p>
      <Link href="/" class="btn btn-sm mt-4" style="background:#4F63F5;color:#fff;border:none">
        К тестам
      </Link>
    </div>

    <h2 class="font-semibold text-lg mb-4">Избранные вопросы</h2>

    <div v-if="bookmarks.length" class="flex flex-col gap-3">
      <div
        v-for="b in bookmarks" :key="b.id"
        class="bookmark-card"
      >
        <div class="bookmark-card__header">
          <span class="bookmark-card__test">{{ b.test_title }}</span>
          <button class="bookmark-remove" title="Убрать из избранного" @click="removeBookmark(b)">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
            </svg>
          </button>
        </div>
        <p class="bookmark-card__text">{{ b.question_text }}</p>
        <div class="bookmark-card__options">
          <div
            v-for="opt in b.options" :key="opt.id"
            class="bookmark-option"
            :class="b.correct_ids.includes(opt.id) ? 'bookmark-option--correct' : ''"
          >
            {{ opt.text }}
          </div>
        </div>
        <p v-if="b.explanation" class="bookmark-card__explanation">{{ b.explanation }}</p>
      </div>
    </div>

    <div v-else class="text-center py-10 text-gray-400">
      <p>Нет избранных вопросов</p>
      <p class="text-xs mt-1">Добавляйте вопросы в избранное во время прохождения теста</p>
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
  { label: 'Попыток',           value: props.stats.total_attempts },
  { label: 'Средний балл',      value: props.stats.avg_score.toFixed(1) + '%' },
  { label: 'Лучший результат',  value: props.stats.best_score.toFixed(0) + '%' },
  { label: 'Тестов пройдено',   value: props.stats.tests_completed },
])

async function removeBookmark(b) {
  try {
    await axios.delete('/bookmarks', { data: { question_id: b.question_id } })
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
