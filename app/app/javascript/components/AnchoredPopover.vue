<template>
  <Teleport to="body">
    <!-- Телепорт в body: карточки тестов — ссылки (<a>) и обрезают содержимое,
         поповер внутри них уходил бы под соседей или кликом по нему открывал
         бы тест. -->
    <!-- Прозрачная подложка на весь экран: клик мимо поповера попадает в неё,
         закрывает его и больше ничего не делает — элементы под курсором
         (ссылки, теги, кнопки) события не получают. Так же ведёт себя и касание. -->
    <div class="anchored-popover__backdrop" @click.stop.prevent="emit('close')"></div>
    <div
      ref="el"
      class="anchored-popover"
      :class="popoverClass"
      :style="style"
      role="dialog"
      :aria-label="label"
      @click.stop
    >
      <slot />
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

// Поповер, привязанный к элементу-якорю: карточка участника над аватаркой,
// настройки прохождения под шестерёнкой. Закрывается кликом мимо, Esc, прокруткой
// страницы и изменением размера окна — всё это здесь, а не в каждом потребителе.
const props = defineProps({
  // Положение якоря в окне (getBoundingClientRect): { top, left, width, height }.
  anchor:       { type: Object, required: true },
  width:        { type: Number, default: 288 },
  // 'center' — по центру якоря, 'end' — правым краем к правому краю якоря.
  align:        { type: String, default: 'center' },
  // 'above' — над якорем, а если места нет — под ним; 'below' — всегда под.
  prefer:       { type: String, default: 'above' },
  padding:      { type: String, default: '0.875rem' },
  label:        { type: String, default: '' },
  popoverClass: { type: String, default: '' },
})
const emit = defineEmits(['close'])

const GAP    = 8
const MARGIN = 8

const el     = ref(null)
const height = ref(0)

// Над якорем поповер крепится нижним краем (bottom), а не верхним: так его
// высота не участвует в расчёте, и он встаёт вплотную к якорю с первого кадра
// и при любом содержимом — иначе пришлось бы полагаться на замеренную высоту, а
// устаревший замер уносил его далеко вверх. Высота нужна только чтобы понять,
// влезает ли он сверху; её держит в актуальном виде ResizeObserver.
const placeBelow = computed(() =>
  props.prefer === 'below' || props.anchor.top - GAP - height.value < MARGIN
)

const style = computed(() => {
  const width = Math.min(props.width, window.innerWidth - MARGIN * 2)
  const wanted = props.align === 'end'
    ? props.anchor.left + props.anchor.width - width
    : props.anchor.left + props.anchor.width / 2 - width / 2
  const left = Math.min(Math.max(wanted, MARGIN), window.innerWidth - width - MARGIN)
  const base = { left: `${left}px`, width: `${width}px`, padding: props.padding }

  if (!placeBelow.value) {
    return { ...base, bottom: `${window.innerHeight - props.anchor.top + GAP}px` }
  }

  const top = props.anchor.top + props.anchor.height + GAP
  // Под якорем места может не хватить — тогда поповер прокручивается сам.
  return { ...base, top: `${top}px`, maxHeight: `${window.innerHeight - top - MARGIN}px`, overflowY: 'auto' }
})

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}

// Якорь уезжает при прокрутке страницы, а поповер зафиксирован в окне — проще
// закрыть, чем гоняться за ним. Но не при прокрутке внутри самого поповера:
// у длинного списка есть свой скролл, а слушатель на window в фазе перехвата
// ловит и его.
function onScroll(e) {
  if (el.value?.contains(e.target)) return
  emit('close')
}
const onResize = () => emit('close')

let resizeObserver = null

onMounted(() => {
  resizeObserver = new ResizeObserver(() => { height.value = el.value?.offsetHeight ?? 0 })
  resizeObserver.observe(el.value)
  document.addEventListener('keydown', onKey)
  window.addEventListener('scroll', onScroll, true)
  window.addEventListener('resize', onResize)
})
onUnmounted(() => {
  resizeObserver?.disconnect()
  document.removeEventListener('keydown', onKey)
  window.removeEventListener('scroll', onScroll, true)
  window.removeEventListener('resize', onResize)
})
</script>

<style scoped>
.anchored-popover__backdrop {
  position: fixed;
  inset: 0;
  z-index: 999;
}

.anchored-popover {
  position: fixed;
  z-index: 1000;
  box-sizing: border-box;
  border: 1px solid #E5E7EB;
  border-radius: var(--rounded-box, 0.75rem);
  background: #fff;
  box-shadow: 0 10px 30px rgba(17, 24, 39, 0.12);
  animation: anchored-popover-in 0.18s ease both;
}

@keyframes anchored-popover-in {
  from { opacity: 0; transform: translateY(4px) scale(0.98); }
  to   { opacity: 1; transform: translateY(0) scale(1); }
}

@media (prefers-reduced-motion: reduce) {
  .anchored-popover { animation: none; }
}
</style>
