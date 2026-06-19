<template>
  <AppLayout>
    <div class="page-header">
      <h1 class="page-header__title">Тесты для разработчиков</h1>
      <p class="page-header__subtitle">Backend-разработка, Ruby on Rails, PostgreSQL и не только</p>
    </div>

    <div class="tag-filters">
      <button
        v-for="tag in allTags" :key="tag"
        @click="toggleTag(tag)"
        class="badge badge-lg cursor-pointer transition-all"
        :class="filterTag === tag ? 'tag-badge--active' : 'tag-badge'"
      >
        {{ tag }}
      </button>
    </div>

    <div class="toolbar">
      <div class="toolbar__difficulties">
        <button
          v-for="d in difficulties" :key="d.value"
          @click="toggleDifficulty(d.value)"
          class="btn btn-sm"
          :class="{ 'btn-primary': filterDifficulty === d.value }"
        >
          {{ d.label }}
        </button>
      </div>

      <div class="toolbar__views">
        <button
          v-for="view in views" :key="view.key"
          @click="activeView = view.key"
          class="btn btn-sm btn-square"
          :class="{ 'btn-primary': activeView === view.key }"
          :title="view.label"
        >
          {{ view.icon }}
        </button>
      </div>
    </div>

    <component :is="activeViewComponent" :tests="tests" @clear-filters="clearFilters" />
  </AppLayout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import GridView from '@/components/tests/GridView.vue'
import ListView from '@/components/tests/ListView.vue'

const props = defineProps({
  tests:             Array,
  allTags:           Array,
  filterTag:         String,
  filterDifficulty:  String,
})

const filterTag        = ref(props.filterTag || null)
const filterDifficulty = ref(props.filterDifficulty || null)
const activeView       = ref('grid')

const views = [
  { key: 'grid', label: 'Сетка',  icon: '▦' },
  { key: 'list', label: 'Список', icon: '☰' },
]

const viewComponents = { grid: GridView, list: ListView }
const activeViewComponent = computed(() => viewComponents[activeView.value])

const difficulties = [
  { value: 'beginner',     label: 'Начальный' },
  { value: 'intermediate', label: 'Средний' },
  { value: 'advanced',     label: 'Продвинутый' },
]

function applyFilters() {
  router.get('/', {
    tag:        filterTag.value || undefined,
    difficulty: filterDifficulty.value || undefined,
  }, { preserveState: true })
}

function toggleTag(tag) {
  filterTag.value = filterTag.value === tag ? null : tag
  applyFilters()
}

function toggleDifficulty(d) {
  filterDifficulty.value = filterDifficulty.value === d ? null : d
  applyFilters()
}

function clearFilters() {
  filterTag.value = null
  filterDifficulty.value = null
  applyFilters()
}
</script>

<style scoped>
.page-header {
  margin-bottom: 2rem;
}

.page-header__title {
  font-size: 1.875rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.page-header__subtitle {
  color: #6B7280;
}

.tag-filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 2rem;
}

.toolbar__difficulties {
  display: flex;
  gap: 0.5rem;
}

.toolbar__views {
  display: flex;
  gap: 0.25rem;
}
</style>
