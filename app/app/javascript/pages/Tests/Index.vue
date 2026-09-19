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

    <TestDropZone>
    <div class="page-header">
      <div class="page-header__left">
        <h1 class="page-header__title">Тесты для разработчиков</h1>
        <p class="page-header__subtitle">
          Ruby on Rails, Go, PostgreSQL
          <span class="page-header__drop-hint">и не только</span>
        </p>
      </div>
      <div class="page-header__views hidden">
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
        <TagTip v-for="tag in visibleTags" :key="tag" :text="tagDescriptions[tag] || ''">
          <button
            @click="onTagClick($event, tag)"
            @mousedown="lp.start($event, tag)"
            @mouseup="lp.cancel()"
            @mouseleave="lp.cancel()"
            @touchstart.passive="lp.start($event, tag)"
            @touchend="lp.cancel()"
            @touchcancel="lp.cancel()"
            class="badge badge-sm transition-all tag-filter-btn"
            :class="[
              excludedTags.includes(tag) ? 'tag-filter--excluded' : selectedTags.includes(tag) ? 'tag-filter--active' : 'tag-filter',
              tagCount(tag) === 0 && !excludedTags.includes(tag) ? 'tag-filter--disabled' : 'cursor-pointer'
            ]"
          >
            {{ tag }} <span v-if="!excludedTags.includes(tag)" class="tag-count">{{ tagCount(tag) }}</span>
          </button>
        </TagTip>

        <button
          v-if="hasHiddenTags || showOtherTags"
          @click="toggleOtherTags"
          class="badge badge-sm tag-filter tag-filter--other cursor-pointer"
        >
          {{ showOtherTags ? 'Скрыть другие теги' : 'Другие теги' }}
        </button>

        <button
          @click="editingTags = true"
          class="badge badge-sm tag-filter tag-filter--edit cursor-pointer"
          title="Выбрать интересные темы"
        >
          Изменить
        </button>

        <!-- Разовый сброс выбора: сохранённые предпочтения остаются, при
             следующем заходе теги снова подставятся. -->
        <button
          v-if="hasTagSelection"
          @click="clearTagSelection"
          class="badge badge-sm tag-filter tag-filter--clear cursor-pointer"
          title="Снять выделение тегов на этой странице"
        >
          Снять
        </button>
      </div>

    </div>

    <div class="controls-row">
      <div class="sort-menu">
        <button
          @click.stop="sortMenuOpen = !sortMenuOpen"
          class="sort-menu__icon"
          :class="{ 'sort-menu__icon--active': sortMenuOpen }"
          title="Сортировка"
          aria-label="Сортировка"
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="4" y1="6" x2="16" y2="6"/><line x1="4" y1="12" x2="12" y2="12"/><line x1="4" y1="18" x2="8" y2="18"/>
            <path d="M18 10 L18 20 M18 20 L15 17 M18 20 L21 17"/>
          </svg>
        </button>

        <div v-if="sortMenuOpen" class="sort-menu__dropdown">
          <button
            v-for="opt in sortOptions" :key="opt.value"
            @click="onSortSelect(opt.value)"
            class="sort-menu__option"
            :class="{ 'sort-menu__option--active': sortBy === opt.value }"
          >
            {{ opt.label }}
          </button>
        </div>
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

    <component :is="activeViewComponent" :tests="filteredTests" :selected-tags="selectedTags" :excluded-tags="excludedTags" @clear-filters="clearFilters" @toggle-tag="toggleTag" @exclude-tag="toggleExcludeTag" />
    </TestDropZone>

    <TagPickerDialog
      v-if="showTagOnboarding"
      :categories="tagCategories"
      :descriptions="tagDescriptions"
      @done="onOnboardingDone"
    />

    <TagPickerDialog
      v-if="editingTags"
      editing
      :categories="tagCategories"
      :descriptions="tagDescriptions"
      :initial-tags="localPreferred || []"
      @done="onPreferencesEdited"
      @close="editingTags = false"
    />
  </AppLayout>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onUnmounted } from 'vue'

function useLongPress(onLong, delay = 500) {
  let timer = null
  let fired = false
  function start(e, ...args) {
    fired = false
    timer = setTimeout(() => { fired = true; onLong(...args) }, delay)
  }
  function cancel() { clearTimeout(timer) }
  function click(e) { if (fired) { e.preventDefault(); return true } return false }
  return { start, cancel, click }
}
import AppLayout from '@/components/AppLayout.vue'
import GridView from '@/components/tests/GridView.vue'
import ListView from '@/components/tests/ListView.vue'
import TagPickerDialog from '@/components/tests/TagPickerDialog.vue'
import TestDropZone from '@/components/tests/TestDropZone.vue'
import TagTip from '@/components/TagTip.vue'
import { useTestFilters } from '@/composables/useTestFilters'

const props = defineProps({
  tests:          Array,
  allTags:        Array,
  preferredTags:   { type: Array,  default: null },
  tagCategories:   { type: Array,  default: () => [] },
  tagDescriptions: { type: Object, default: () => ({}) },
  showTagOnboarding: { type: Boolean, default: false },
})

const {
  searchQuery, selectedTags, excludedTags, filterDifficulty, showOtherTags, sortBy,
  clearFilters, clearTagSelection, seedFromPreferences, applyPreferences,
  toggleTag, toggleExcludeTag, toggleDifficulty, toggleOtherTags, setSortBy
} = useTestFilters()

seedFromPreferences(props.preferredTags)

// Выбор из онбординга применяется сразу, не дожидаясь перезагрузки пропсов:
// оверлей растворяется над уже готовой главной.
const localPreferred = ref(props.preferredTags)

function onOnboardingDone(tags) {
  localPreferred.value = tags
  applyPreferences(tags)
}

const editingTags = ref(false)

function onPreferencesEdited(tags) {
  editingTags.value = false
  onOnboardingDone(tags)
}

const lp = useLongPress(tag => toggleExcludeTag(tag))

function onTagClick(e, tag) {
  if (lp.click(e, tag)) return
  if (e.ctrlKey || e.metaKey) { toggleExcludeTag(tag); return }
  if (excludedTags.value.includes(tag)) { toggleExcludeTag(tag); return }
  if (tagCount(tag) > 0) toggleTag(tag, tagCount(tag))
}

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
  { value: 'basic',    label: 'Базовый' },
  { value: 'advanced', label: 'Продвинутый' },
  { value: 'expert',   label: 'Эксперт' },
]

const sortMenuOpen = ref(false)

function closeSortMenu() { sortMenuOpen.value = false }
onMounted(() => document.addEventListener('click', closeSortMenu))
onUnmounted(() => document.removeEventListener('click', closeSortMenu))

function onSortSelect(value) {
  setSortBy(value)
  sortMenuOpen.value = false
}

const sortOptions = [
  { value: 'popular',  label: 'По популярности' },
  { value: 'new',      label: 'По новизне' },
  { value: 'alpha',    label: 'По алфавиту' },
  { value: 'easiest',  label: 'По сложности' },
]

const sortComparators = {
  popular: (a, b) => b.attemptsCount - a.attemptsCount,
  new:     (a, b) => new Date(b.createdAt) - new Date(a.createdAt),
  alpha:   (a, b) => a.title.localeCompare(b.title, 'ru'),
  easiest: (a, b) => DIFFICULTY_ORDER.indexOf(a.difficulty) - DIFFICULTY_ORDER.indexOf(b.difficulty),
}

const DIFFICULTY_ORDER = ['basic', 'advanced', 'expert']

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

// Выбор тегов работает по ИЛИ: теги — это темы, которые пользователь хочет
// видеть, а не последовательное сужение выдачи. Исключения остаются жёсткими:
// исключённый тег убирает тест независимо от остальных выбранных.
const filteredTests = computed(() => {
  let result = baseFilteredTests.value
  if (selectedTags.value.length > 0)
    result = result.filter(t => selectedTags.value.some(tag => t.tags?.includes(tag)))
  if (excludedTags.value.length > 0)
    result = result.filter(t => excludedTags.value.every(tag => !t.tags?.includes(tag)))

  const compare = sortComparators[sortBy.value]
  if (compare) result = [...result].sort(compare)

  return result
})

// Подтеги уже лежат в предпочтениях: выбор категории добавляет их целиком,
// а снятые вручную оттуда исключены. Дорисовывать потомков из таксономии
// нельзя — точечно снятый тег вернулся бы в список.
const preferredWithChildren = computed(() => {
  const prefs = localPreferred.value
  if (!Array.isArray(prefs) || prefs.length === 0) return null
  return new Set(prefs)
})

// Список тегов сужается до предпочтений, пока не нажаты "Другие теги".
// Выбранное вручную показываем всегда, иначе тег нельзя было бы снять.
const visibleTags = computed(() => {
  const allowed = preferredWithChildren.value
  if (!allowed || showOtherTags.value) return props.allTags

  return props.allTags.filter(tag =>
    allowed.has(tag) || selectedTags.value.includes(tag) || excludedTags.value.includes(tag)
  )
})

// Кнопка «Снять» нужна, только когда есть что снимать — и выбранные теги,
// и исключённые.
const hasTagSelection = computed(() =>
  selectedTags.value.length > 0 || excludedTags.value.length > 0
)

const hasHiddenTags = computed(() =>
  preferredWithChildren.value !== null && visibleTags.value.length < props.allTags.length
)

// При ИЛИ-логике счётчик показывает, сколько тестов добавится с этим тегом,
// поэтому он не зависит от уже выбранного и кэшировать его не нужно.
function tagCount(tag) {
  return baseFilteredTests.value.filter(t => t.tags?.includes(tag)).length
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

.page-header__drop-hint {
  color: #9CA3AF;
}

@media (max-width: 640px) {
  .page-header__drop-hint {
    display: none;
  }
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
  padding: .35rem;
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

.difficulty-dot--basic    { background-color: #22c55e; border-color: #22c55e; }
.difficulty-dot--advanced { background-color: #f59e0b; border-color: #f59e0b; }
.difficulty-dot--expert   { background-color: #ef4444; border-color: #ef4444; }

.difficulty-dot--disabled {
  opacity: 0.25;
}

.sort-menu {
  position: relative;
  flex-shrink: 0;
}

.sort-menu__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  padding: 0.35rem;
  color: #4B5563;
  cursor: pointer;
  border-radius: 0.375rem;
  transition: color 0.15s, background-color 0.15s;
}

.sort-menu__icon:hover,
.sort-menu__icon--active {
  color: #111827;
  background-color: #F3F4F6;
}

.sort-menu__dropdown {
  position: absolute;
  top: calc(100% + 0.375rem);
  left: 0;
  z-index: 20;
  min-width: 11rem;
  background: #fff;
  border: 1px solid #E5E7EB;
  border-radius: 0.5rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  padding: 0.25rem;
  display: flex;
  flex-direction: column;
}

.sort-menu__option {
  text-align: left;
  background: none;
  border: none;
  padding: 0.45rem 0.6rem;
  font-size: 0.875rem;
  color: #374151;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: background-color 0.15s;
}

.sort-menu__option:hover {
  background-color: #F3F4F6;
}

.sort-menu__option--active {
  color: #4F63F5;
  font-weight: 600;
}

.tag-filters-row {
  display: flex;
  align-items: flex-end;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.tag-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.controls-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.tag-filter-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.3em;
}

.tag-count {
  font-size: 0.9em;
  min-width: 1.1em;
  opacity: 0.65;
  text-align: right;
}

.tag-filter--disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.tag-filter--excluded {
  background: #FEE2E2;
  color: #EF4444;
  border-color: #FCA5A5;
  text-decoration: line-through;
}
</style>
