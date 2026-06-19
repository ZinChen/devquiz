<template>
  <div v-if="tests.length" class="tests-list">
    <Link
      v-for="test in tests" :key="test.slug"
      :href="`/tests/${test.slug}`"
      class="test-row"
    >
      <div class="test-row__body">
        <div class="test-row__header">
          <h2 class="test-row__title">{{ test.title }}</h2>
          <DifficultyBadge :difficulty="test.difficulty" class="test-row__badge" />
        </div>
        <p class="test-row__desc">{{ test.description }}</p>
      </div>
      <div class="test-row__meta">
        <span>{{ test.questions_count }} вопросов</span>
        <span>~{{ test.estimated_time }} мин</span>
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
.tests-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.test-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 1rem);
  padding: 1rem;
  transition: box-shadow 0.15s;
}

.test-row:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.test-row__body {
  flex: 1;
  min-width: 0;
}

.test-row__header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}

.test-row__title {
  font-weight: 600;
  font-size: 1rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.test-row__badge {
  flex-shrink: 0;
}

.test-row__desc {
  font-size: 0.875rem;
  color: #6B7280;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.test-row__meta {
  display: flex;
  align-items: center;
  gap: 1rem;
  font-size: 0.75rem;
  color: #9CA3AF;
  flex-shrink: 0;
}
</style>
