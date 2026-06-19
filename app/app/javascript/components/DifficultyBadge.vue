<template>
  <span class="badge badge-sm" :style="style">{{ label }}</span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ difficulty: String })

const map = {
  beginner:     { label: 'Начальный',     color: '#10B981' },
  intermediate: { label: 'Средний',       color: '#F59E0B' },
  advanced:     { label: 'Продвинутый',   color: '#EF4444' },
}

const info  = computed(() => map[props.difficulty] || { label: props.difficulty, color: '#6B7280' })
const label = computed(() => info.value.label)
const style = computed(() => ({ background: info.value.color + '20', color: info.value.color, border: 'none', fontWeight: 500 }))
</script>
