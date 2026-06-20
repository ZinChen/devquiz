<template>
  <button
    class="bookmark-btn"
    :class="{ 'bookmark-btn--active': isBookmarked }"
    :title="isBookmarked ? 'Убрать из избранного' : 'В избранное'"
    @click.prevent.stop="toggle"
  >
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path v-if="isBookmarked" d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" fill="currentColor" stroke="currentColor"/>
      <path v-else d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
    </svg>
  </button>
</template>

<script setup>
import { ref } from 'vue'
import axios from 'axios'

const props = defineProps({
  questionId: { type: Number, required: true },
  initial:    { type: Boolean, default: false },
})

const isBookmarked = ref(props.initial)

async function toggle() {
  const wasBookmarked = isBookmarked.value
  isBookmarked.value = !wasBookmarked

  try {
    if (wasBookmarked) {
      await axios.delete('/bookmarks', { data: { question_id: props.questionId } })
    } else {
      await axios.post('/bookmarks', { question_id: props.questionId })
    }
  } catch {
    isBookmarked.value = wasBookmarked
  }
}
</script>

<style scoped>
.bookmark-btn {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;
  color: #D1D5DB;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.25rem;
  transition: color 0.15s;
  flex-shrink: 0;
}

.bookmark-btn:hover {
  color: #6366F1;
}

.bookmark-btn--active {
  color: #6366F1;
}
</style>
