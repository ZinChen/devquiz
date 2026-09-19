<template>
  <span class="badge badge-sm" :style="style">{{ label }}</span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ difficulty: String })

const map = {
  basic:    { label: 'Базовый',     color: '#10B981' },
  advanced: { label: 'Продвинутый', color: '#F59E0B' },
  expert:   { label: 'Эксперт',     color: '#EF4444' },
}

const info  = computed(() => map[props.difficulty] || { label: props.difficulty, color: '#6B7280' })
const label = computed(() => info.value.label)
const style = computed(() => ({ background: info.value.color + '20', color: info.value.color, border: 'none', fontWeight: 500 }))
</script>
