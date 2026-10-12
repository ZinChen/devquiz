<template>
  <span
    class="achievement-badge"
    :class="[rank ? `achievement-badge--${rank}` : '', { 'achievement-badge--locked': locked, 'achievement-badge--fill': fill }]"
    :style="style"
    aria-hidden="true"
  >{{ icon || '🏅' }}</span>
</template>

<script setup>
import { computed } from 'vue'

// Единый вид ачивки везде: профиль, мини-карточки, карточка участника и блок
// «Новое достижение». Иконка в круге цвета своей группы, вокруг — кольцо
// «металла» (золото — финал лесенки, серебро, бронза — см.
// AchievementsCatalog#rank_for). У невзятой ачивки цвета и кольца нет: яркое
// пятно читалось бы как «получено».
//
// Кольцо рисуется снаружи круга (box-shadow), поэтому у бейджа есть внешний
// отступ 4px — раскладка родителя учитывает его без подгонки.
const props = defineProps({
  icon:   { type: String, default: '' },
  // { bg, fg } группы ачивки — приходит с сервера (AchievementsCatalog#color_for).
  color:  { type: Object, default: null },
  rank:   { type: String, default: null },
  locked: { type: Boolean, default: false },
  // Диаметр круга без кольца, px. Игнорируется при fill.
  size:   { type: Number, default: 40 },
  // Занять всю ширину ячейки (сетка плиток в карточке участника).
  fill:   { type: Boolean, default: false },
})

const style = computed(() => {
  const css = { fontSize: props.fill ? '1.25rem' : `${Math.round(props.size * 0.5)}px` }
  if (!props.fill) {
    css.width = `${props.size}px`
    css.height = `${props.size}px`
  }
  if (!props.locked && props.color?.bg) css.background = props.color.bg
  return css
})
</script>

<style scoped>
.achievement-badge {
  --ring: #D1D5DB;

  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  box-sizing: border-box;
  margin: 4px;
  border-radius: 50%;
  background: #F3F4F6;
  line-height: 1;
  /* Белый зазор между цветом группы и кольцом, чтобы они не сливались. */
  box-shadow: 0 0 0 2px #fff, 0 0 0 4px var(--ring), 0 2px 8px color-mix(in srgb, var(--ring) 40%, transparent);
}

.achievement-badge--fill {
  width: calc(100% - 8px);
  aspect-ratio: 1;
}

.achievement-badge--gold   { --ring: #FBBF24; }
.achievement-badge--silver { --ring: #8EA6D8; }
.achievement-badge--bronze { --ring: #CD8B57; }

.achievement-badge--locked {
  filter: grayscale(1);
  opacity: 0.55;
  box-shadow: 0 0 0 2px #fff, 0 0 0 3px #E5E7EB;
}
</style>
