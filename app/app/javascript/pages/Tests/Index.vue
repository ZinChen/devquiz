<template>
  <AppLayout>
    <div class="page-header">
      <h1 class="page-header__title">Тесты для разработчиков</h1>
      <p class="page-header__subtitle">Ruby on Rails, PostgreSQL и не только</p>
    </div>

    <div class="search-bar">
      <input
        v-model="searchQuery"
        type="search"
        placeholder="Поиск"
        class="search-input"
      />
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

    <div class="tag-filters">
      <button
        v-for="tag in allTags" :key="tag"
        @click="toggleTag(tag)"
        class="badge badge-sm cursor-pointer transition-all"
        :class="selectedTags.includes(tag) ? 'tag-filter--active' : 'tag-filter'"
      >
        {{ tag }}
      </button>
    </div>

    <component :is="activeViewComponent" :tests="filteredTests" @clear-filters="clearFilters" />
  </AppLayout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import GridView from '@/components/tests/GridView.vue'
import ListView from '@/components/tests/ListView.vue'

const props = defineProps({
  tests:            Array,
  allTags:          Array,
  filterDifficulty: String,
})

const searchQuery      = ref('')
const selectedTags     = ref([])
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

const filteredTests = computed(() => {
  let result = props.tests

  const q = searchQuery.value.trim().toLowerCase()
  if (q) {
    result = result.filter(t =>
      t.title.toLowerCase().includes(q) ||
      t.description?.toLowerCase().includes(q) ||
      t.tags?.some(tag => tag.toLowerCase().includes(q))
    )
  }

  if (selectedTags.value.length > 0) {
    result = result.filter(t =>
      selectedTags.value.every(tag => t.tags?.includes(tag))
    )
  }

  return result
})

function toggleTag(tag) {
  const idx = selectedTags.value.indexOf(tag)
  if (idx === -1) {
    selectedTags.value.push(tag)
  } else {
    selectedTags.value.splice(idx, 1)
  }
}

function toggleDifficulty(d) {
  filterDifficulty.value = filterDifficulty.value === d ? null : d
  router.get('/', {
    difficulty: filterDifficulty.value || undefined,
  }, { preserveState: true })
}

function clearFilters() {
  searchQuery.value = ''
  selectedTags.value = []
  filterDifficulty.value = null
  router.get('/', {}, { preserveState: true })
}
</script>

<style scoped>
.page-header {
  margin-bottom: 1.5rem;
}

.page-header__title {
  font-size: 1.875rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.page-header__subtitle {
  color: #6B7280;
}

.search-bar {
  margin-bottom: 1.25rem;
}

.search-input {
  width: 100%;
  padding: 0.25rem 1rem;
  border: none;
  border-bottom: 1.5px solid #E5E7EB;
  border-radius: 0;
  font-size: 0.9rem;
  color: #111827;
  background: transparent;
  outline: none;
  transition: border-color 0.15s;
}

.search-input::placeholder {
  color: #9CA3AF;
}

.search-input:focus {
  border-bottom-color: #6366F1;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.25rem;
}

.toolbar__difficulties {
  display: flex;
  gap: 0.5rem;
}

.toolbar__views {
  display: flex;
  gap: 0.25rem;
}

.tag-filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1.75rem;
}
</style>
