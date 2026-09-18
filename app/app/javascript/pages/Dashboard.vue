<template>
  <AppLayout>
    <h1 class="dashboard-title">Мой кабинет</h1>

    <!-- Слева факты о пройденном, справа — что с этим делать. -->
    <div class="dashboard-grid">
      <section class="dashboard-col">
        <h2 class="dashboard-section-title">Статистика</h2>
        <dl class="stat-list">
          <div v-for="s in summaryCards" :key="s.label" class="stat-list__row">
            <dt class="stat-list__label">{{ s.label }}</dt>
            <dd class="stat-list__value">{{ s.value }}</dd>
          </div>
        </dl>
      </section>

      <section class="dashboard-col">
        <h2 class="dashboard-section-title">Слабые темы</h2>
        <template v-if="weakTopics.length">
          <div class="weak-summary">
            <!-- Фон кодирует число ошибок, точка слева — саму тему. -->
            <Link
              v-for="topic in weakTopics" :key="topic.slug"
              :href="`/practice/topic/${topic.slug}`"
              class="weak-summary__tag"
              :class="`weak-summary__tag--${topic.level}`"
              :title="topicTitle(topic)"
            >
              <span
                v-if="topic.color"
                class="weak-summary__dot"
                :style="{ background: topic.color }"
                aria-hidden="true"
              ></span>
              {{ topic.label }}
              <span v-if="topic.wrongCount > 1" class="weak-summary__count">{{ topic.wrongCount }}</span>
            </Link>
          </div>
        </template>
        <p v-else class="dashboard-col__empty">
          Пока нечего подтягивать — пройдите тест, и слабые темы появятся здесь.
        </p>
      </section>
    </div>

    <div class="dashboard-grid dashboard-grid--bottom">
      <section class="dashboard-col">
    <h2 class="dashboard-section-title">История прохождений</h2>

    <div v-if="attempts.length" class="attempts-list">
      <!-- Ведёт на страницу результата этой попытки: там разбор ответов
           и слабые темы — отдельное окно дублировало бы её. -->
      <Link
        v-for="a in attempts" :key="a.id"
        :href="`/tests/${a.testSlug}/runs/${a.id}`"
        class="attempt-row"
      >
        <div>
          <p class="attempt-row__title">
            {{ a.testTitle }}
            <!-- Тренировка идёт по части вопросов, поэтому счёт вида 3/3
                 рядом с обычными попытками иначе читался бы как полный тест. -->
            <span v-if="a.weakOnly" class="attempt-row__badge">тренировка</span>
          </p>
          <p class="attempt-row__date">{{ formatDate(a.completedAt) }}</p>
        </div>
        <div class="attempt-row__score-wrap">
          <span class="attempt-row__count">{{ a.correctCount }}/{{ a.totalQuestions }}</span>
          <span class="attempt-row__score" :style="{ color: scoreColor(a.score) }">{{ a.score.toFixed(0) }}%</span>
        </div>
      </Link>

      <button
        v-if="hasMoreAttemptsRef"
        type="button"
        class="load-more"
        :disabled="loadingAttempts"
        @click="loadMoreAttempts"
      >
        {{ loadingAttempts ? 'Загружаем…' : `Показать ещё ${pageSize}` }}
      </button>
    </div>

    <div v-else class="dashboard-empty">
      <p>Вы ещё не прошли ни одного теста</p>
      <Link href="/" class="btn btn-sm btn-primary dashboard-empty__btn">
        К тестам
      </Link>
    </div>

      </section>

      <section class="dashboard-col">
    <template v-if="recommendedTests.length">
      <h2 class="dashboard-section-title">Рекомендуемые тесты</h2>
      <div class="recommended-tests">
        <Link
          v-for="t in recommendedTests" :key="t.slug"
          :href="`/tests/${t.slug}`"
          class="recommended-tests__item"
        >
          <span class="recommended-tests__title">{{ t.title }}</span>
          <span v-if="t.topics?.length" class="recommended-tests__topics">{{ t.topics.join(', ') }}</span>
          <span v-if="t.completed" class="recommended-tests__badge">пройден</span>
        </Link>
      </div>
    </template>

      </section>
    </div>

    <h2 class="dashboard-section-title">Избранные вопросы</h2>

    <div v-if="bookmarks.length" class="bookmarks-list">
      <!-- Удалённая закладка не исчезает сразу: пока страница открыта, её
           можно вернуть — удаление в один клик иначе необратимо. -->
      <div
        v-for="b in bookmarks" :key="b.id"
        class="bookmark-card"
        :class="{ 'bookmark-card--removed': removedIds.has(b.id) }"
      >
        <div class="bookmark-card__header">
          <span class="bookmark-card__test">{{ b.testTitle }}</span>
          <button
            v-if="removedIds.has(b.id)"
            type="button"
            class="bookmark-restore"
            @click="restoreBookmark(b)"
          >
            Вернуть
          </button>
          <button
            v-else
            type="button"
            class="bookmark-remove"
            title="Убрать из избранного"
            @click="removeBookmark(b)"
          >
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

      <button
        v-if="hasMoreBookmarksRef"
        type="button"
        class="load-more"
        :disabled="loadingBookmarks"
        @click="loadMoreBookmarks"
      >
        {{ loadingBookmarks ? 'Загружаем…' : `Показать ещё ${pageSize}` }}
      </button>
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
  attempts:           Array,
  stats:              Object,
  bookmarks:          { type: Array, default: () => [] },
  weakTopics:         { type: Array, default: () => [] },
  recommendedTests:   { type: Array, default: () => [] },
  hasMoreAttempts:    { type: Boolean, default: false },
  hasMoreBookmarks:   { type: Boolean, default: false },
  pageSize:           { type: Number, default: 5 },
})

const bookmarks = ref(props.bookmarks)

// Списки догружаются страницами, поэтому живут в локальном состоянии,
// а не читаются из пропов напрямую.
const attempts           = ref(props.attempts ?? [])
const hasMoreAttemptsRef = ref(props.hasMoreAttempts)
const hasMoreBookmarksRef = ref(props.hasMoreBookmarks)
const loadingAttempts    = ref(false)
const loadingBookmarks   = ref(false)

async function loadMoreAttempts() {
  if (loadingAttempts.value) return
  loadingAttempts.value = true
  try {
    const { data } = await axios.get('/dashboard/attempts', {
      params: { offset: attempts.value.length },
    })
    attempts.value = [...attempts.value, ...data.attempts]
    hasMoreAttemptsRef.value = data.hasMore
  } catch {} finally {
    loadingAttempts.value = false
  }
}

async function loadMoreBookmarks() {
  if (loadingBookmarks.value) return
  loadingBookmarks.value = true
  try {
    const { data } = await axios.get('/dashboard/bookmarks', {
      params: { offset: bookmarks.value.length },
    })
    bookmarks.value = [...bookmarks.value, ...data.bookmarks]
    hasMoreBookmarksRef.value = data.hasMore
  } catch {} finally {
    loadingBookmarks.value = false
  }
}


// В тултипе описание темы и число ошибок: на самом теге число показано
// только при повторных промахах, чтобы не зашумлять строку единицами.
function topicTitle(topic) {
  const parts = []
  if (topic.description) parts.push(topic.description)
  // Из каких тестов набралась тема — иначе непонятно, откуда она взялась.
  if (topic.sources?.length) {
    parts.push(topic.sources.map(s => `${s.title}: ${s.wrongCount}`).join(', '))
  } else if (topic.wrongCount > 0) {
    parts.push(`Ошибок: ${topic.wrongCount}`)
  }
  return parts.join(' • ')
}

// Лучший балл убран намеренно: у любого, кто прошёл пару тестов, там 100%,
// и строка ничего не сообщает.
const summaryCards = computed(() => [
  { label: 'Всего попыток',   value: props.stats.totalAttempts },
  { label: 'Тестов пройдено', value: props.stats.testsCompleted },
  { label: 'Средний балл',    value: props.stats.avgScore.toFixed(1) + '%' },
])

// Карточка остаётся в списке, помеченная как удалённая: из БД запись уже
// убрана, но вернуть её можно, пока страница не перезагружена.
const removedIds = ref(new Set())

async function removeBookmark(b) {
  try {
    await axios.delete('/bookmarks', { data: { question_id: b.questionId } })
    removedIds.value = new Set(removedIds.value).add(b.id)
  } catch {}
}

async function restoreBookmark(b) {
  try {
    await axios.post('/bookmarks', { question_id: b.questionId })
    const next = new Set(removedIds.value)
    next.delete(b.id)
    removedIds.value = next
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
  color: inherit;
  text-decoration: none;
}

.attempt-row:hover {
  background: #F7F8FA;
  border-color: #4F63F5;
}

.attempt-row:hover .attempt-row__title {
  color: #4F63F5;
}

.attempt-row__title {
  font-weight: 500;
  font-size: 0.875rem;
}

/* Пометка, а не акцент: приглушённая, как дата и счётчик рядом. */
.attempt-row__badge {
  display: inline-block;
  margin-left: 0.375rem;
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #9CA3AF;
  font-size: 0.6875rem;
  font-weight: 600;
  vertical-align: middle;
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

/* Слабые темы и рекомендации: та же карточка и та же градация,
   что в отчёте после теста, чтобы язык интерфейса не разъезжался. */
.weak-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem;
}

.weak-summary__tag {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.1875rem 0.625rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #4B5563;
  font-size: 0.75rem;
  font-weight: 600;
}

.weak-summary__tag--low {
  background: #F3F4F6;
  color: #4B5563;
}

.weak-summary__tag--medium {
  background: #FEF3C7;
  color: #92400E;
}

.weak-summary__tag--high {
  background: #FEE2E2;
  color: #991B1B;
}

.weak-summary__dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.weak-summary__count {
  padding: 0 0.3125rem;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.65);
  font-size: 0.6875rem;
  font-weight: 700;
}

.recommended-tests {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 2rem;
}

.recommended-tests__item {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.875rem;
  border-radius: 0.5rem;
  background: #fff;
  border: 1px solid #E5E7EB;
  color: #374151;
  font-size: 0.8125rem;
  font-weight: 500;
  text-decoration: none;
}

.recommended-tests__item:hover {
  background: #F7F8FA;
  border-color: #4F63F5;
  color: #4F63F5;
}

/* Уже пройденные показываем последними и помечаем, чтобы не выглядели новыми. */
.recommended-tests__badge {
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #9CA3AF;
  font-size: 0.6875rem;
  font-weight: 600;
}

.weak-summary__tag {
  text-decoration: none;
  cursor: pointer;
}

.weak-summary__tag:hover {
  filter: brightness(0.95);
}

.recommended-tests__topics {
  color: #9CA3AF;
  font-size: 0.75rem;
}

/* Две колонки: слева факты о пройденном, справа — куда двигаться.
   На узком экране схлопываются в одну, порядок задан в разметке. */
.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 2rem;
  align-items: start;
}

.dashboard-grid--bottom {
  gap: 1rem 2rem;
}

@media (max-width: 48rem) {
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}

.dashboard-col__empty {
  font-size: 0.8125rem;
  color: #9CA3AF;
  line-height: 1.5;
}

/* Подпись слева, значение справа — плотнее и читается быстрее плиток.
   Карточка такая же, как у строк истории, чтобы секции были однородны. */
.stat-list {
  margin: 0;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 0.25rem 1rem;
}

.stat-list__row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.625rem 0;
  border-bottom: 1px solid #F3F4F6;
}

.stat-list__row:last-child {
  border-bottom: none;
}

.stat-list__label {
  font-size: 0.8125rem;
  color: #6B7280;
}

.stat-list__value {
  margin: 0;
  font-size: 0.9375rem;
  font-weight: 600;
  color: #111827;
  text-align: right;
}

/* В колонке панели идут друг под другом, без общей высоты. */
.dashboard-col {
  min-width: 0;
}

/* Удалённая, но ещё возвращаемая закладка: видно, что её больше нет,
   но карточка остаётся на месте, чтобы список не прыгал. */
.bookmark-card--removed {
  opacity: 0.55;
}

.bookmark-card--removed .bookmark-card__text,
.bookmark-card--removed .bookmark-card__options {
  text-decoration: line-through;
  text-decoration-color: #D1D5DB;
}

.bookmark-restore {
  padding: 0.125rem 0.5rem;
  border: 1px solid #C7CDFA;
  border-radius: 999px;
  background: #fff;
  color: #4F63F5;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.bookmark-restore:hover {
  background: #EEF0FF;
}

/* Догрузка следующей страницы списка. */
.load-more {
  align-self: center;
  margin-top: 0.25rem;
  padding: 0.5rem 1rem;
  border: 1px solid #E5E7EB;
  border-radius: 0.5rem;
  background: #fff;
  color: #4B5563;
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
}

.load-more:hover:not(:disabled) {
  background: #F7F8FA;
  border-color: #4F63F5;
  color: #4F63F5;
}

.load-more:disabled {
  opacity: 0.6;
  cursor: default;
}
</style>
