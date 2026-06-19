<template>
  <div v-if="tests.length" class="tests-grid">
    <Link
      v-for="test in tests" :key="test.slug"
      :href="`/tests/${test.slug}`"
      class="test-card"
    >
      <div class="test-card__header">
        <h2 class="test-card__title">{{ test.title }}</h2>
        <DifficultyBadge :difficulty="test.difficulty" class="test-card__badge" />
      </div>
      <p class="test-card__desc">{{ test.description }}</p>
      <div class="test-card__tags">
        <span
          v-for="tag in test.tags" :key="tag"
          class="badge badge-sm tag-badge"
        >{{ tag }}</span>
      </div>
      <div class="test-card__meta">
        <span>{{ test.questions_count }} вопросов</span>
        <span>~{{ test.estimated_time }} мин</span>
        <span v-if="test.attempts_count > 0">{{ test.attempts_count }} попыток</span>
        <span v-if="test.attempts_count > 0">avg {{ test.avg_score.toFixed(0) }}%</span>
      </div>
    </Link>
  </div>

  <EmptyState v-else @clear="$emit('clear-filters')" />
</template>

<script setup>
import { Link } from '@inertiajs/vue3'
import DifficultyBadge from '@/components/DifficultyBadge.vue'
import EmptyState from '@/components/tests/EmptyState.vue'

defineProps({ tests: Array })
defineEmits(['clear-filters'])
</script>

<style scoped>
.tests-grid {
  display: grid;
  grid-template-columns: repeat(1, 1fr);
  gap: 1rem;
}

@media (min-width: 768px) {
  .tests-grid { grid-template-columns: repeat(2, 1fr); }
}

.test-card {
  display: block;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 1rem);
  padding: 1.25rem;
  transition: box-shadow 0.15s;
}

.test-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.test-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.test-card__title {
  font-weight: 600;
  font-size: 1rem;
}

.test-card__badge {
  margin-left: 0.5rem;
  flex-shrink: 0;
}

.test-card__desc {
  font-size: 0.875rem;
  color: #6B7280;
  margin-bottom: 0.75rem;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.test-card__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
}

.test-card__meta {
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 0.75rem;
  color: #9CA3AF;
}
</style>
