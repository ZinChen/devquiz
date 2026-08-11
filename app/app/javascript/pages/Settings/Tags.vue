<template>
  <AppLayout>
    <div class="settings">
      <Link href="/" class="settings__back">← Все тесты</Link>

      <h1 class="settings__title">Мои темы</h1>
      <p class="settings__subtitle">
        Главная страница показывает тесты по выбранным темам.
        Остальные всегда доступны через «Другие теги».
      </p>

      <TagPicker v-model="selected" :categories="tagCategories" :descriptions="tagDescriptions" />

      <div class="settings__actions">
        <button
          class="btn btn-primary"
          :disabled="!changed || saving"
          @click="save"
        >
          {{ saving ? 'Сохранение…' : 'Сохранить' }}
        </button>
        <button
          v-if="selected.length > 0"
          class="btn btn-ghost btn-sm"
          @click="selected = []"
        >
          Сбросить всё
        </button>
        <span v-if="!changed && !saving" class="settings__hint">Изменений нет</span>
      </div>

      <p v-if="selected.length === 0" class="settings__empty-note">
        Без выбранных тем на главной показываются все тесты.
      </p>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import TagPicker from '@/components/tests/TagPicker.vue'
import { useTestFilters } from '@/composables/useTestFilters'

const { applyPreferences } = useTestFilters()

const props = defineProps({
  preferredTags:   { type: Array,  default: () => [] },
  tagCategories:   { type: Array,  default: () => [] },
  tagDescriptions: { type: Object, default: () => ({}) },
})

const selected = ref([...props.preferredTags])
const saving   = ref(false)

// Порядок выбора не важен, поэтому сравниваем как множества.
const changed = computed(() => {
  const a = [...selected.value].sort()
  const b = [...props.preferredTags].sort()
  return a.length !== b.length || a.some((tag, i) => tag !== b[i])
})

function save() {
  if (saving.value) return
  saving.value = true

  // Фильтр на главной засевается один раз за загрузку страницы, поэтому
  // новый выбор применяем к нему явно — иначе главная в этой же SPA-сессии
  // осталась бы со старыми тегами.
  applyPreferences(selected.value)

  router.patch('/preferences/tags', { tags: selected.value }, {
    preserveScroll: true,
    onFinish: () => { saving.value = false }
  })
}
</script>

<style scoped>
.settings {
  max-width: 46rem;
}

.settings__back {
  display: inline-block;
  margin-bottom: 1.25rem;
  font-size: 0.875rem;
  color: #6B7280;
  text-decoration: none;
}

.settings__back:hover {
  color: #4F63F5;
}

.settings__title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1F2937;
  margin-bottom: 0.375rem;
}

.settings__subtitle {
  color: #6B7280;
  margin-bottom: 1.75rem;
}

.settings__actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.settings__hint,
.settings__empty-note {
  font-size: 0.8125rem;
  color: #9CA3AF;
}

.settings__empty-note {
  margin-top: 1rem;
}

@media (prefers-color-scheme: dark) {
  .settings__title {
    color: #F9FAFB;
  }
}
</style>
