<template>
  <AppLayout>
    <template #search>
      <div class="search-toggle" :class="{ 'search-toggle--open': searchOpen }">
        <button class="search-toggle__icon" @click="openSearch" :aria-label="searchOpen ? '' : 'Поиск'">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
        </button>
        <input
          ref="searchInputRef"
          v-model="searchQuery"
          type="search"
          placeholder="Поиск..."
          class="search-input"
          @blur="onSearchBlur"
        />
      </div>
    </template>

    <div class="page-header">
      <div class="page-header__left">
        <h1 class="page-header__title">Тесты для разработчиков</h1>
        <p class="page-header__subtitle">Ruby on Rails, PostgreSQL и не только</p>
      </div>
      <div class="page-header__views">
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

    <div class="tag-filters-row">
      <div class="tag-filters">
        <button
          v-for="tag in allTags" :key="tag"
          @click="tagCount(tag) > 0 && toggleTag(tag, tagCount(tag))"
          class="badge badge-sm transition-all tag-filter-btn"
          :class="[
            selectedTags.includes(tag) ? 'tag-filter--active' : 'tag-filter',
            tagCount(tag) === 0 ? 'tag-filter--disabled' : 'cursor-pointer'
          ]"
        >
          {{ tag }} <span class="tag-count">{{ tagCount(tag) }}</span>
        </button>
      </div>

      <div class="difficulty-dots">
        <button
          v-for="d in difficulties" :key="d.value"
          @click="toggleDifficulty(d.value)"
          class="difficulty-dot"
          :class="[`difficulty-dot--${d.value}`, { 'difficulty-dot--disabled': filterDifficulty && filterDifficulty !== d.value }]"
          :title="d.label"
        />
      </div>
    </div>

    <component :is="activeViewComponent" :tests="filteredTests" @clear-filters="clearFilters" />
  </AppLayout>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue'
import AppLayout from '@/components/AppLayout.vue'
import GridView from '@/components/tests/GridView.vue'
import ListView from '@/components/tests/ListView.vue'
import { useTestFilters } from '@/composables/useTestFilters'

const props = defineProps({
  tests:   Array,
  allTags: Array,
})

const { searchQuery, selectedTags, filterDifficulty, tagCountCache, clearFilters, toggleTag, toggleDifficulty } = useTestFilters()

const searchOpen = ref(false)
const searchInputRef = ref(null)

function openSearch() {
  if (searchOpen.value) {
    searchOpen.value = false
    searchQuery.value = ''
  } else {
    searchOpen.value = true
    nextTick(() => searchInputRef.value?.focus())
  }
}

function onSearchBlur() {
  if (!searchQuery.value) {
    searchOpen.value = false
  }
}

const activeView = ref('grid')

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

const baseFilteredTests = computed(() => {
  let result = props.tests

  const q = searchQuery.value.trim().toLowerCase()
  if (q) {
    result = result.filter(t =>
      t.title.toLowerCase().includes(q) ||
      t.description?.toLowerCase().includes(q) ||
      t.tags?.some(tag => tag.toLowerCase().includes(q))
    )
  }

  if (filterDifficulty.value) {
    result = result.filter(t => t.difficulty === filterDifficulty.value)
  }

  return result
})

const filteredTests = computed(() => {
  if (selectedTags.value.length === 0) return baseFilteredTests.value
  return baseFilteredTests.value.filter(t =>
    selectedTags.value.every(tag => t.tags?.includes(tag))
  )
})

function tagCount(tag) {
  if (selectedTags.value.includes(tag)) {
    return tagCountCache.value[tag] ?? 0
  }
  const combined = [...selectedTags.value, tag]
  return baseFilteredTests.value.filter(t => combined.every(s => t.tags?.includes(s))).length
}
</script>

<style scoped>
.page-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.page-header__left {
  flex: 1;
}

.page-header__title {
  font-size: 1.875rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.page-header__subtitle {
  color: #6B7280;
}

.page-header__views {
  display: flex;
  gap: 0.25rem;
  flex-shrink: 0;
  align-self: flex-end;
}

.search-toggle {
  display: flex;
  align-items: center;
  gap: 0;
}

.search-toggle__icon {
  background: none;
  border: none;
  cursor: pointer;
  color: #6B7280;
  display: flex;
  align-items: center;
  padding: 0.25rem;
  border-radius: 0.25rem;
  transition: color 0.15s;
  flex-shrink: 0;
}

.search-toggle__icon:hover {
  color: #4F63F5;
}

.search-input {
  width: 0;
  padding: 0.25rem 0;
  border: none;
  border-bottom: 1.5px solid transparent;
  border-radius: 0;
  font-size: 0.9rem;
  color: #111827;
  background: transparent;
  outline: none;
  overflow: hidden;
  opacity: 0;
  transition: width 0.25s ease, opacity 0.2s ease, border-color 0.15s, padding 0.25s ease;
}

.search-toggle--open .search-input {
  width: 14rem;
  padding: 0.25rem 0.5rem;
  border-bottom-color: #E5E7EB;
  opacity: 1;
}

.search-input::placeholder {
  color: #9CA3AF;
}

.search-input:focus {
  border-bottom-color: #6366F1;
}

.difficulty-dots {
  display: flex;
  gap: 0.4rem;
  align-items: center;
}

.difficulty-dot {
  width: 1rem;
  height: 1rem;
  border-radius: 50%;
  border: 2px solid transparent;
  cursor: pointer;
  transition: background-color 0.15s, border-color 0.15s;
  padding: 0;
  flex-shrink: 0;
}

.difficulty-dot--beginner     { background-color: #22c55e; border-color: #22c55e; }
.difficulty-dot--intermediate { background-color: #f59e0b; border-color: #f59e0b; }
.difficulty-dot--advanced     { background-color: #ef4444; border-color: #ef4444; }

.difficulty-dot--disabled {
  opacity: 0.25;
}

.tag-filters-row {
  display: flex;
  align-items: flex-end;
  gap: 1rem;
  margin-bottom: 1.75rem;
}

.tag-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.tag-filter-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.3em;
}

.tag-count {
  font-size: 0.7em;
  opacity: 0.65;
  min-width: 1.4em;
  text-align: right;
}

.tag-filter--disabled {
  opacity: 0.35;
  cursor: not-allowed;
}
</style>
