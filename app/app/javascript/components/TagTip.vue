<template>
  <!-- Обёртка нужна, чтобы поймать наведение на теге. -->
  <span
    ref="root"
    class="tag-tip"
    :class="{ 'tag-tip--has-text': !!text }"
    @mouseenter="show"
    @mouseleave="hide"
    @focusin="show"
    @focusout="hide"
  >
    <slot />

    <!-- Попап в body: внутри ряда тегов его обрезал бы overflow соседей,
         а fixed-координаты позволяют прижать его к краю узкого экрана. -->
    <Teleport to="body">
      <span
        v-if="text && mounted"
        class="tag-tip__bubble"
        :class="{ 'tag-tip__bubble--visible': visible }"
        :style="style"
        role="tooltip"
      >{{ text }}</span>
    </Teleport>
  </span>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
  text: { type: String, default: '' },
})

// Задержка перед показом: подсказка не должна выскакивать, когда курсор
// просто проходит по ряду тегов.
const SHOW_DELAY = 1200
const MARGIN     = 8

const root    = ref(null)
const visible = ref(false)
const mounted = ref(false)
const style   = ref({})

let timer = null

onMounted(() => { mounted.value = true })
onBeforeUnmount(() => clearTimeout(timer))

function place() {
  const el = root.value
  if (!el) return

  const r = el.getBoundingClientRect()
  // Ширину знаем только после вставки в DOM, поэтому ограничиваем ту же
  // максимальную ширину, что и в стилях.
  const maxWidth = Math.min(240, window.innerWidth - MARGIN * 2)

  style.value = {
    top:      `${r.bottom + 6}px`,
    left:     `${r.left + r.width / 2}px`,
    maxWidth: `${maxWidth}px`,
    // translateX(-50%) центрирует по тегу, clamp не даёт уехать за край окна.
    '--tip-shift': `${shift(r, maxWidth)}px`,
  }
}

// Насколько сдвинуть попап, чтобы он остался в пределах окна.
function shift(rect, maxWidth) {
  const center = rect.left + rect.width / 2
  const half   = maxWidth / 2

  const overflowLeft  = MARGIN - (center - half)
  const overflowRight = (center + half) - (window.innerWidth - MARGIN)

  if (overflowLeft > 0) return overflowLeft
  if (overflowRight > 0) return -overflowRight
  return 0
}

function show() {
  if (!props.text) return
  clearTimeout(timer)
  timer = setTimeout(() => {
    place()
    visible.value = true
  }, SHOW_DELAY)
}

// Прячем сразу: иначе подсказка тянется за курсором по всему ряду тегов.
function hide() {
  clearTimeout(timer)
  visible.value = false
}
</script>

<style scoped>
.tag-tip {
  display: inline-flex;
}
</style>

<style>
/* Не scoped: попап телепортируется в body и до него не дошли бы data-атрибуты. */
.tag-tip__bubble {
  position: fixed;
  z-index: 60;
  width: max-content;
  padding: 0.4rem 0.625rem;
  border-radius: 0.5rem;
  /* Альфа-канал в hex: подложка просвечивает, текст остаётся тёмным. */
  background: #9e9e9e21;
  color: #6B7280;
  font-size: 0.75rem;
  font-weight: 400;
  line-height: 1.4;
  text-align: left;
  white-space: normal;
  backdrop-filter: blur(2px);
  opacity: 0;
  pointer-events: none;
  transform: translateX(calc(-50% + var(--tip-shift, 0px))) translateY(-0.25rem);
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.tag-tip__bubble--visible {
  opacity: 1;
  transform: translateX(calc(-50% + var(--tip-shift, 0px))) translateY(0);
}

/* На тёмном фоне тёмный текст на полупрозрачной подложке нечитаем. */
@media (prefers-color-scheme: dark) {
  .tag-tip__bubble {
    background: #e5e7eb21;
    color: #F3F4F6;
  }
}
</style>
