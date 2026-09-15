<template>
  <AppLayout>
    <nav class="topic-breadcrumbs">
      <Link href="/dashboard" class="topic-breadcrumbs__link">← Мой кабинет</Link>
    </nav>

    <div class="topic-header">
      <h1 class="topic-header__title">
        <span
          v-if="topic.color"
          class="topic-header__dot"
          :style="{ background: topic.color }"
          aria-hidden="true"
        ></span>
        {{ topic.label }}
      </h1>
      <p v-if="topic.description" class="topic-header__description">{{ topic.description }}</p>
    </div>

    <div class="topic-banner">
      Тренировка по теме: вопросы, где вы ошибались, собраны из разных тестов.
      В статистику тестов результат не идёт.
    </div>

    <!-- Результат: разбор с указанием, из какого теста вопрос. -->
    <template v-if="result">
      <div class="topic-result">
        <div class="topic-result__score">{{ result.correctCount }} из {{ result.total }}</div>
        <p class="topic-result__text">{{ resultText }}</p>
        <div class="topic-result__actions">
          <button type="button" class="btn btn-primary btn-sm" @click="restart">Ещё раз</button>
          <Link href="/dashboard" class="btn btn-ghost btn-sm">В кабинет</Link>
        </div>
      </div>

      <div
        v-for="item in result.details" :key="item.questionId"
        class="topic-item"
        :style="{ borderColor: item.correct ? '#10B98130' : '#EF444430' }"
      >
        <div class="topic-item__header">
          <span
            class="topic-item__badge"
            :style="item.correct ? 'background:#D1FAE5;color:#065F46' : 'background:#FEE2E2;color:#991B1B'"
          >{{ item.correct ? '✓' : '✗' }}</span>
          <div>
            <p class="topic-item__question">{{ item.questionText }}</p>
            <Link :href="`/tests/${item.testSlug}`" class="topic-item__source">{{ titleFor(item.testSlug) }}</Link>
          </div>
        </div>

        <div class="topic-item__options">
          <div
            v-for="opt in item.options" :key="opt.id"
            class="topic-option"
            :style="optionStyle(item, opt.id)"
          >{{ opt.text }}</div>
        </div>

        <p v-if="item.explanation" class="topic-item__explanation">{{ item.explanation }}</p>
      </div>
    </template>

    <!-- Прохождение -->
    <template v-else>
      <div
        v-for="(q, idx) in questions" :key="q.id"
        class="topic-item"
      >
        <div class="topic-item__header">
          <span class="topic-item__number">{{ idx + 1 }}</span>
          <div>
            <p class="topic-item__question">{{ q.text }}</p>
            <span class="topic-item__source">{{ titleFor(q.testSlug) }}</span>
          </div>
        </div>

        <div class="topic-item__options">
          <button
            v-for="opt in q.options" :key="opt.id"
            type="button"
            class="topic-option topic-option--clickable"
            :class="{ 'topic-option--selected': answers[q.id] === opt.id }"
            @click="answers[q.id] = opt.id"
          >{{ opt.text }}</button>
        </div>
      </div>

      <div class="topic-actions">
        <button
          type="button"
          class="btn btn-primary"
          :disabled="!answeredCount || submitting"
          @click="submit"
        >
          Проверить {{ answeredCount }} из {{ questions.length }}
        </button>
      </div>
    </template>
  </AppLayout>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({
  topic:     Object,
  questions: { type: Array, default: () => [] },
})

const answers    = reactive({})
const result     = ref(null)
const submitting = ref(false)

const answeredCount = computed(() => Object.keys(answers).length)

// Названия тестов приходят вместе с вопросами — отдельный запрос не нужен.
const testTitles = computed(() => {
  const map = {}
  props.questions.forEach(q => { map[q.testSlug] = q.testTitle || q.testSlug })
  return map
})

function titleFor(slug) {
  return testTitles.value[slug] || slug
}

const resultText = computed(() => {
  if (!result.value) return ''
  const { correctCount, total } = result.value
  if (correctCount === total) return 'Все верно — тема закрывается'
  if (correctCount === 0) return 'Пока мимо, стоит вернуться к теории'
  return 'Часть вопросов ещё требует повторения'
})

async function submit() {
  submitting.value = true

  const payload = {}
  props.questions.forEach(q => {
    const selected = answers[q.id]
    if (selected) payload[q.id] = { test_slug: q.testSlug, selected: [selected] }
  })

  try {
    const response = await fetch(`/practice/topic/${props.topic.slug}/grade`, {
      method:  'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content ?? '',
      },
      body: JSON.stringify({ answers: payload }),
    })
    const data = await response.json()
    result.value = {
      details:      data.details.map(camelizeDetail),
      correctCount: data.correct_count,
      total:        data.total,
    }
    window.scrollTo({ top: 0, behavior: 'smooth' })
  } finally {
    submitting.value = false
  }
}

// Ответ приходит из json-эндпоинта, минуя общий camelize для Inertia-пропсов.
function camelizeDetail(d) {
  return {
    questionId:   d.question_id,
    questionText: d.question_text,
    correct:      d.correct,
    explanation:  d.explanation,
    options:      d.options,
    correctIds:   d.correct_ids,
    selectedOptions: d.selected_options,
    testSlug:     d.test_slug,
  }
}

function restart() {
  router.reload()
}

function optionStyle(item, optId) {
  const isCorrect  = item.correctIds?.includes(optId)
  const isSelected = item.selectedOptions?.includes(optId)
  if (isCorrect)  return { background: '#D1FAE5', color: '#065F46' }
  if (isSelected) return { background: '#FEE2E2', color: '#991B1B' }
  return { background: '#F7F8FA', color: '#374151' }
}
</script>

<style scoped>
.topic-breadcrumbs {
  margin-bottom: 1rem;
}

.topic-breadcrumbs__link {
  font-size: 0.875rem;
  color: #6B7280;
  text-decoration: none;
}

.topic-breadcrumbs__link:hover {
  color: #4F63F5;
}

.topic-header {
  margin-bottom: 1rem;
}

.topic-header__title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.5rem;
  font-weight: 700;
}

.topic-header__dot {
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.topic-header__description {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: #6B7280;
}

.topic-banner {
  padding: 0.625rem 0.875rem;
  margin-bottom: 1.5rem;
  border: 1px solid #FDE68A;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FFFBEB;
  color: #92400E;
  font-size: 0.8125rem;
  line-height: 1.45;
}

.topic-result {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.5rem;
  margin-bottom: 1.5rem;
  text-align: center;
}

.topic-result__score {
  font-size: 2rem;
  font-weight: 700;
  color: #111827;
}

.topic-result__text {
  margin-top: 0.25rem;
  color: #6B7280;
  font-size: 0.875rem;
}

.topic-result__actions {
  display: flex;
  justify-content: center;
  gap: 0.5rem;
  margin-top: 1rem;
}

.topic-item {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  margin-bottom: 0.75rem;
}

.topic-item__header {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.topic-item__badge,
.topic-item__number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  min-width: 1.5rem;
  height: 1.5rem;
  padding: 0 0.4rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #6B7280;
  font-size: 0.75rem;
  font-weight: 600;
}

.topic-item__question {
  font-size: 0.875rem;
  font-weight: 500;
}

.topic-item__source {
  display: inline-block;
  margin-top: 0.125rem;
  font-size: 0.75rem;
  color: #9CA3AF;
  text-decoration: none;
}

a.topic-item__source:hover {
  color: #4F63F5;
}

.topic-item__options {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.topic-option {
  padding: 0.5rem 0.75rem;
  border-radius: 0.5rem;
  background: #F7F8FA;
  color: #374151;
  font-size: 0.875rem;
  text-align: left;
}

.topic-option--clickable {
  border: 1px solid transparent;
  cursor: pointer;
}

.topic-option--clickable:hover {
  border-color: #C7CDFA;
}

.topic-option--selected {
  background: #EEF0FF;
  border-color: #4F63F5;
  color: #3730A3;
}

.topic-item__explanation {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid #F3F4F6;
  font-size: 0.75rem;
  color: #6B7280;
}

.topic-actions {
  display: flex;
  justify-content: center;
  margin: 1.5rem 0;
}
</style>
