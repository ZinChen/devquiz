<template>
  <AppLayout>
    <div class="test-detail">
      <Link href="/" class="test-detail__back">← Все тесты</Link>

      <div class="test-detail__card">
        <div class="test-detail__header">
          <h1 class="test-detail__title">{{ test.title }}</h1>
          <CustomSourceBadge :custom="test.custom" :overrides-repo="test.overridesRepo" />
          <DifficultyBadge :difficulty="test.difficulty" />
        </div>

        <p class="test-detail__desc">{{ test.description }}</p>

        <div class="test-detail__tags">
          <span
            v-for="tag in test.tags" :key="tag"
            class="badge tag-badge"
          >{{ tag }}</span>
        </div>

        <div class="test-detail__meta-grid">
          <div class="test-detail__meta-cell">
            <div class="test-detail__meta-value test-detail__meta-value--accent">{{ test.questionsCount }}</div>
            <div class="test-detail__meta-label">вопросов</div>
          </div>
          <div class="test-detail__meta-cell">
            <div class="test-detail__meta-value">~{{ test.estimatedTime }}<span class="test-detail__meta-unit"> мин</span></div>
            <div class="test-detail__meta-label">примерно</div>
          </div>
          <div v-if="currentUser" class="test-detail__meta-cell">
            <div class="test-detail__meta-value">{{ test.attemptsCount }}</div>
            <div class="test-detail__meta-label">ваших попыток</div>
          </div>
        </div>

        <!-- Только личные цифры и только для вошедшего: общая статистика по
             всем прохождениям здесь не показывается (см. UserTestStats). -->
        <div v-if="currentUser && test.attemptsCount > 0" class="test-detail__stats">
          <span>Ваш средний балл: <b>{{ test.avgScore.toFixed(1) }}%</b></span>
          <span>Лучший результат: <b>{{ test.bestScore.toFixed(0) }}%</b></span>
        </div>

        <Link :href="`/tests/${test.slug}/run/new`" class="btn btn-primary test-detail__start">
          {{ hasStartedSession ? 'Продолжить тест' : 'Начать тест' }}
        </Link>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { computed } from 'vue'
import { Link, usePage } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import DifficultyBadge from '@/components/DifficultyBadge.vue'
import CustomSourceBadge from '@/components/tests/CustomSourceBadge.vue'

const props = defineProps({ test: Object })
const currentUser = computed(() => usePage().props.currentUser)

// Ключ и формат совпадают с useQuizSession.js — там же сессия и сохраняется.
const hasStartedSession = ref(false)

onMounted(() => {
  try {
    const raw = localStorage.getItem(`devquiz_session_${props.test.slug}`)
    const saved = raw ? JSON.parse(raw) : null
    const answers = saved?.answers || {}
    hasStartedSession.value = Object.values(answers).some(a =>
      Array.isArray(a) ? a.length > 0 : (a !== null && a !== '')
    )
  } catch {}
})
</script>

<style scoped>
.test-detail {
  max-width: 42rem;
  margin: 0 auto;
}

.test-detail__back {
  display: inline-block;
  font-size: 0.875rem;
  color: #9CA3AF;
  margin-bottom: 1.5rem;
  transition: color 0.15s;
}

.test-detail__back:hover {
  color: #4B5563;
}

.test-detail__card {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 2rem;
}

.test-detail__header {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.test-detail__title {
  font-size: 1.5rem;
  font-weight: 700;
  flex: 1;
}

.test-detail__desc {
  color: #4B5563;
  margin-bottom: 1.5rem;
}

.test-detail__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  margin-bottom: 1.5rem;
}

.test-detail__meta-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.test-detail__meta-cell {
  text-align: center;
  padding: 1rem;
  border-radius: 0.75rem;
  background: #F7F8FA;
}

.test-detail__meta-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #374151;
}

.test-detail__meta-value--accent {
  color: #4F63F5;
}

.test-detail__meta-unit {
  font-size: 0.875rem;
  font-weight: 400;
}

.test-detail__meta-label {
  font-size: 0.75rem;
  color: #6B7280;
  margin-top: 0.25rem;
}

.test-detail__stats {
  display: flex;
  gap: 1.5rem;
  font-size: 0.875rem;
  color: #6B7280;
  margin-bottom: 2rem;
}

.test-detail__start {
  width: 100%;
}
</style>
