<template>
  <svg
    class="generated-avatar"
    viewBox="0 0 40 40"
    role="img"
    :aria-label="name || 'Аватар'"
  >
    <rect width="40" height="40" rx="20" :fill="background" />
    <svg
      v-if="animalIcon"
      x="6.5" y="6.5" width="27" height="27"
      :viewBox="animalIcon.viewBox"
      overflow="visible"
    >
      <!-- markup: иконка из нескольких фигур (контур+глаза и т.п.). Линии
           красятся в currentColor (=foreground); основной контур, если он
           без заливки, красится в var(--fill-bg) (=background) — иначе сквозь
           пустой контур просвечивал бы фон страницы, а не круг аватара.
           d: обычный случай, один силуэт-путь. -->
      <g
        v-if="animalIcon.markup"
        :style="{ color: foreground, '--fill-bg': background }"
        v-html="animalIcon.markup"
      />
      <path v-else :d="animalIcon.d" :fill="foreground" />
    </svg>
    <text
      v-else
      x="20" y="21"
      text-anchor="middle"
      dominant-baseline="central"
      :fill="foreground"
      font-size="16"
      font-weight="600"
      font-family="inherit"
    >{{ initials }}</text>
  </svg>
</template>

<script setup>
import { computed } from 'vue'
import { ANIMAL_ICON_VARIANTS, detectAnimal } from '@/assets/animalIconPaths'

const props = defineProps({
  // Стабильный ключ для выбора цвета — не зависит от имени, чтобы кнопка
  // «случайный цвет» под аватаром меняла только фон, не трогая распознанное
  // животное (см. RandomIdentity.avatar_seed). Тем же ключом выбирается
  // конкретный вариант иконки, если их для животного несколько — иначе
  // выбор "мигал" бы случайным образом на каждый ре-рендер компонента.
  seed: { type: String, default: '' },
  name: { type: String, default: '' },
})

// Тёплая/холодная пара на фон и текст — без чёрного/белого, чтобы выглядело
// как продуманная палитра, а не как плейсхолдер.
const PALETTE = [
  ['#FEE2E2', '#991B1B'], ['#FEF3C7', '#92400E'], ['#D1FAE5', '#065F46'],
  ['#DBEAFE', '#1E40AF'], ['#EDE9FE', '#5B21B6'], ['#FCE7F3', '#9D174D'],
  ['#E0E7FF', '#3730A3'], ['#CFFAFE', '#155E75'], ['#FFEDD5', '#9A3412'],
  ['#ECFCCB', '#3F6212'],
]

function hashOf(str) {
  let h = 0
  for (let i = 0; i < str.length; i++) {
    h = (h * 31 + str.charCodeAt(i)) >>> 0
  }
  return h
}

const seedKey = computed(() => props.seed || props.name || '?')

const palette = computed(() => PALETTE[hashOf(seedKey.value) % PALETTE.length])

const background = computed(() => palette.value[0])
const foreground = computed(() => palette.value[1])

// Животное распознаётся по имени (подстрока, без регистра): у кого есть
// готовая иконка — рисуем её, иначе остаются инициалы.
const animalIcon = computed(() => {
  const match = detectAnimal(props.name)
  if (!match) return null

  const variants = ANIMAL_ICON_VARIANTS[match]
  return variants[hashOf(seedKey.value) % variants.length]
})

const initials = computed(() => {
  const words = (props.name || '').trim().split(/\s+/).filter(Boolean)
  if (words.length === 0) return '?'
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase()
  return (words[0][0] + words[1][0]).toUpperCase()
})
</script>

<style scoped>
.generated-avatar {
  width: 100%;
  height: 100%;
  display: block;
}
</style>
