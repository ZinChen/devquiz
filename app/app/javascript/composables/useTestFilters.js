import { ref } from 'vue'

const searchQuery      = ref('')
const selectedTags     = ref([])
const excludedTags     = ref([])
const filterDifficulty = ref(null)
const tagCountCache    = ref({})

export function useTestFilters() {
  function clearFilters() {
    searchQuery.value      = ''
    selectedTags.value     = []
    excludedTags.value     = []
    filterDifficulty.value = null
    tagCountCache.value    = {}
  }

  function toggleTag(tag, count) {
    // remove from excluded if present
    const exIdx = excludedTags.value.indexOf(tag)
    if (exIdx !== -1) excludedTags.value.splice(exIdx, 1)

    const idx = selectedTags.value.indexOf(tag)
    if (idx === -1) {
      selectedTags.value.push(tag)
      tagCountCache.value = { ...tagCountCache.value, [tag]: count }
    } else {
      selectedTags.value.splice(idx, 1)
      const next = { ...tagCountCache.value }
      delete next[tag]
      tagCountCache.value = next
    }
  }

  function toggleExcludeTag(tag) {
    // remove from selected if present
    const selIdx = selectedTags.value.indexOf(tag)
    if (selIdx !== -1) {
      selectedTags.value.splice(selIdx, 1)
      const next = { ...tagCountCache.value }
      delete next[tag]
      tagCountCache.value = next
    }

    const idx = excludedTags.value.indexOf(tag)
    if (idx === -1) excludedTags.value.push(tag)
    else excludedTags.value.splice(idx, 1)
  }

  function toggleDifficulty(d) {
    filterDifficulty.value = filterDifficulty.value === d ? null : d
  }

  return { searchQuery, selectedTags, excludedTags, filterDifficulty, tagCountCache, clearFilters, toggleTag, toggleExcludeTag, toggleDifficulty }
}
