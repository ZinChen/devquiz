import { ref } from 'vue'

const searchQuery      = ref('')
const selectedTags     = ref([])
const excludedTags     = ref([])
const filterDifficulty = ref(null)

// Показывать ли теги за пределами предпочтений ("Другие теги").
const showOtherTags = ref(false)

// Состояние живёт в модуле, а не в компоненте, чтобы фильтр переживал
// навигацию. Поэтому предпочтения подставляются ровно один раз за загрузку
// страницы — иначе возврат на главную затирал бы ручной сброс фильтра.
let preferencesSeeded = false

export function useTestFilters() {
  function clearFilters() {
    searchQuery.value      = ''
    selectedTags.value     = []
    excludedTags.value     = []
    filterDifficulty.value = null
  }

  // Предустановка выбора из preferred_tags при первой загрузке.
  function seedFromPreferences(tags) {
    if (preferencesSeeded) return
    preferencesSeeded = true
    if (Array.isArray(tags) && tags.length > 0) selectedTags.value = [...tags]
  }

  // Применяется сразу после экрана онбординга, минуя защиту от повторного
  // засева: пользователь только что сделал выбор явно.
  function applyPreferences(tags) {
    preferencesSeeded = true
    selectedTags.value = Array.isArray(tags) ? [...tags] : []
    showOtherTags.value = false
  }

  function toggleTag(tag) {
    // remove from excluded if present
    const exIdx = excludedTags.value.indexOf(tag)
    if (exIdx !== -1) excludedTags.value.splice(exIdx, 1)

    const idx = selectedTags.value.indexOf(tag)
    if (idx === -1) selectedTags.value.push(tag)
    else selectedTags.value.splice(idx, 1)
  }

  function toggleExcludeTag(tag) {
    // remove from selected if present
    const selIdx = selectedTags.value.indexOf(tag)
    if (selIdx !== -1) selectedTags.value.splice(selIdx, 1)

    const idx = excludedTags.value.indexOf(tag)
    if (idx === -1) excludedTags.value.push(tag)
    else excludedTags.value.splice(idx, 1)
  }

  function toggleDifficulty(d) {
    filterDifficulty.value = filterDifficulty.value === d ? null : d
  }

  function toggleOtherTags() {
    showOtherTags.value = !showOtherTags.value
  }

  return {
    searchQuery, selectedTags, excludedTags, filterDifficulty, showOtherTags,
    clearFilters, seedFromPreferences, applyPreferences,
    toggleTag, toggleExcludeTag, toggleDifficulty, toggleOtherTags
  }
}
