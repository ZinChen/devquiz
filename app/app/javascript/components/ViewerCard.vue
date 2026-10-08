<template>
  <AnchoredPopover
    :anchor="anchor"
    :width="288"
    popover-class="viewer-card"
    :label="`Карточка: ${viewer.name}`"
    @close="emit('close')"
  >
    <div class="viewer-card__head">
      <span class="viewer-card__avatar">
        <img v-if="viewer.avatarUrl" :src="viewer.avatarUrl" alt="" class="viewer-card__img" />
        <GeneratedAvatar v-else :seed="viewer.avatarSeed || ''" :name="viewer.name || ''" />
      </span>
      <div class="viewer-card__who">
        <p class="viewer-card__name">{{ viewer.name }}</p>
        <p class="viewer-card__sub">{{ viewer.userId ? 'Участник' : 'Гость' }}</p>
      </div>
    </div>

    <template v-if="viewer.userId">
      <p class="viewer-card__title">
        Ачивки
        <span class="viewer-card__count">{{ shownCount }}</span>
      </p>

      <p v-if="failed" class="viewer-card__hint">Не удалось загрузить ачивки</p>

      <!-- Пока ачивки грузятся, а число известно из снимка активности,
           рисуем столько же серых плиток: карточка с первого кадра нужного
           размера, и когда придут данные, плитки просто окрашиваются — без
           «Загружаем…», которое мигало и дёргало высоту. -->
      <div v-else-if="!loaded && expected > 0" class="viewer-card__list" aria-busy="true">
        <span v-for="n in expected" :key="n" class="viewer-card__tile viewer-card__tile--skeleton"></span>
      </div>

      <!-- Название и описание — в подсказке, как у тегов. -->
      <div v-else-if="loaded && achievements.items.length" class="viewer-card__list">
        <TagTip
          v-for="(item, i) in achievements.items" :key="item.slug"
          class="viewer-card__cell"
          :text="tipText(item)"
          over-modal
        >
          <span
            class="viewer-card__tile"
            :style="{ background: item.color?.bg, animationDelay: `${Math.min(i, 14) * 18}ms` }"
          >{{ item.icon || '🏅' }}</span>
        </TagTip>
      </div>

      <p v-else class="viewer-card__hint">Пока нет открытых ачивок</p>
    </template>
  </AnchoredPopover>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import AnchoredPopover from '@/components/AnchoredPopover.vue'
import GeneratedAvatar from '@/components/GeneratedAvatar.vue'
import TagTip from '@/components/TagTip.vue'

const props = defineProps({
  viewer: { type: Object, required: true },
  // Положение аватарки в окне (getBoundingClientRect): карточка встаёт над ней.
  anchor: { type: Object, required: true },
})
const emit = defineEmits(['close'])

function tipText(item) {
  return item.description ? `${item.title} — ${item.description}` : item.title
}

const achievements = ref({ count: 0, items: [] })
const loaded       = ref(false)
const failed       = ref(false)
// Сколько плиток будет, известно ещё до запроса — из снимка активности.
const expected     = computed(() => props.viewer.achievementsCount || 0)
const shownCount   = computed(() => loaded.value ? achievements.value.count : expected.value)

async function load() {
  if (!props.viewer.userId) return

  try {
    const { data } = await axios.get(`/activity/users/${props.viewer.userId}`)
    achievements.value = data.achievements
    loaded.value = true
  } catch {
    failed.value = true
  }
}

onMounted(load)
</script>

<style scoped>
.viewer-card__head {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

/* Отступ вниз — только когда под шапкой что-то есть: у гостя шапка единственная,
   и пустое поле под ней делало карточку несимметричной. */
.viewer-card__head:not(:last-child) {
  margin-bottom: 0.75rem;
}

.viewer-card__avatar {
  display: inline-flex;
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
  background: #F3F4F6;
}

.viewer-card__img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.viewer-card__who {
  min-width: 0;
}

.viewer-card__name {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #111827;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.viewer-card__sub {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.viewer-card__title {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  margin-bottom: 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #6B7280;
}

.viewer-card__count {
  padding: 0 0.375rem;
  border-radius: 999px;
  background: #EEF0FE;
  color: #4F63F5;
  font-size: 0.6875rem;
}

.viewer-card__list {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 0.5rem;
  max-height: 14rem;
  overflow-y: auto;
  /* Тень плитки не должна резаться краем прокручиваемой области. */
  padding: 2px;
}

.viewer-card__cell {
  display: flex;
}

.viewer-card__tile {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: center;
  aspect-ratio: 1;
  border-radius: 0.5rem;
  background: #F1F0FB;
  font-size: 1.25rem;
  line-height: 1;
  cursor: default;
  animation: viewer-tile-in 0.25s ease both;
}

/* Серая плитка-заглушка с мягким «дыханием», пока ачивки грузятся. */
.viewer-card__tile--skeleton {
  background: #F3F4F6;
  animation: viewer-tile-pulse 1.1s ease-in-out infinite;
}

@keyframes viewer-tile-in {
  from { opacity: 0; transform: scale(0.8); }
  to   { opacity: 1; transform: scale(1); }
}

@keyframes viewer-tile-pulse {
  0%, 100% { opacity: 1; }
  50%      { opacity: 0.45; }
}

@media (prefers-reduced-motion: reduce) {
  .viewer-card__tile { animation: none; }
}

.viewer-card__hint {
  font-size: 0.8125rem;
  color: #9CA3AF;
}
</style>
