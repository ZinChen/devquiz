<template>
  <span
    v-if="custom"
    class="custom-badge"
    :class="{ 'custom-badge--override': overridesRepo }"
    :title="title"
  >
    <svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <template v-if="overridesRepo">
        <path d="M6 1.5 11 10.5H1z"/><line x1="6" y1="5" x2="6" y2="7.5"/><line x1="6" y1="9" x2="6" y2="9"/>
      </template>
      <template v-else>
        <path d="M1.5 3.5h3l1 1.5h4.5v4.5a1 1 0 0 1-1 1h-7a1 1 0 0 1-1-1z"/>
      </template>
    </svg>
    {{ overridesRepo ? 'Подменяет' : 'Локальный' }}
  </span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  custom:        { type: Boolean, default: false },
  overridesRepo: { type: Boolean, default: false },
})

const title = computed(() => props.overridesRepo
  ? 'Файл из tests_custom/ занял слаг репозиторного теста и показывается вместо него'
  : 'Тест из локальной папки tests_custom/ — его нет в репозитории и не видно у других')
</script>

<style scoped>
.custom-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.0625rem 0.4rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #6B7280;
  font-size: 0.6875rem;
  font-weight: 600;
  white-space: nowrap;
  cursor: help;
}

.custom-badge--override {
  background: #FEF3C7;
  color: #92400E;
}
</style>
