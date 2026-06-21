import { ref } from 'vue'

const searchQuery      = ref('')
const selectedTags     = ref([])
const filterDifficulty = ref(null)
const tagCountCache    = ref({})

export function useTestFilters() {
  function clearFilters() {
    searchQuery.value      = ''
    selectedTags.value     = []
    filterDifficulty.value = null
    tagCountCache.value    = {}
  }

  function toggleTag(tag, count) {
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

  function toggleDifficulty(d) {
    filterDifficulty.value = filterDifficulty.value === d ? null : d
  }

  return { searchQuery, selectedTags, filterDifficulty, tagCountCache, clearFilters, toggleTag, toggleDifficulty }
}
