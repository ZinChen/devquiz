<template>
  <div v-if="viewers.length" class="avatar-stack">
    <!-- Имя — в той же подсказке, что у тегов (TagTip), а не в нативном title. -->
    <TagTip v-for="v in shown" :key="v.key" :text="v.name">
      <button
        type="button"
        class="avatar-stack__item"
        :style="{ width: size + 'px', height: size + 'px' }"
        :aria-label="`${v.name}: открыть карточку`"
        @click.prevent.stop="openCard(v, $event)"
      >
        <span class="avatar-stack__face">
          <img v-if="v.avatarUrl" :src="v.avatarUrl" alt="" class="avatar-stack__img" />
          <GeneratedAvatar v-else :seed="v.avatarSeed || ''" :name="v.name || ''" />
        </span>
      </button>
    </TagTip>
    <TagTip v-if="hiddenCount > 0" :text="hiddenNames">
      <span
        class="avatar-stack__item avatar-stack__more"
        :style="{ width: size + 'px', height: size + 'px' }"
      >+{{ hiddenCount }}</span>
    </TagTip>

    <!-- :key — обязателен: при клике по другой аватарке карточка должна
         создаться заново. Иначе меняются только пропсы (имя, аватар), а
         onMounted с загрузкой ачивок не срабатывает, и в карточке остаются
         ачивки (или их отсутствие) предыдущего человека. -->
    <ViewerCard v-if="selected" :key="selected.viewer.key" :viewer="selected.viewer" :anchor="selected.rect" @close="selected = null" />
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import GeneratedAvatar from '@/components/GeneratedAvatar.vue'
import ViewerCard from '@/components/ViewerCard.vue'
import TagTip from '@/components/TagTip.vue'

// Стопка перекрывающихся аватарок с «+N» — как в карточках команды: видно, что
// здесь кто-то есть, не занимая места под каждого. Клик по аватарке открывает
// карточку участника (имя, аватар, ачивки).
const props = defineProps({
  viewers: { type: Array, default: () => [] },
  max:     { type: Number, default: 4 },
  size:    { type: Number, default: 28 },
})

// Если не влезают все, последний слот отдаём под «+N», а не под ещё одну
// аватарку: иначе при max=4 и 5 людях получилось бы 4 лица и «+1» — на пять
// элементов в ряду, а не на четыре.
const overflow    = computed(() => props.viewers.length > props.max)
const shown       = computed(() => overflow.value ? props.viewers.slice(0, props.max - 1) : props.viewers)
const hiddenCount = computed(() => overflow.value ? props.viewers.length - shown.value.length : 0)
const hiddenNames = computed(() => props.viewers.slice(shown.value.length).map(v => v.name).join(', '))

// В карточку уезжает копия участника и положение аватарки на момент клика:
// снимок активности обновляется по сети, и открытая карточка не должна
// пропадать или прыгать, если этот человек вышел из списка.
const selected = ref(null)

function openCard(viewer, event) {
  const rect = event.currentTarget.getBoundingClientRect()
  selected.value = selected.value?.viewer.key === viewer.key
    ? null
    : { viewer: { ...viewer }, rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height } }
}
</script>

<style scoped>
.avatar-stack {
  display: inline-flex;
  align-items: center;
}

.avatar-stack__item {
  position: relative;
  display: inline-flex;
  flex-shrink: 0;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  font: inherit;
}

button.avatar-stack__item {
  cursor: pointer;
}

button.avatar-stack__item:focus-visible {
  outline: 2px solid #4F63F5;
  outline-offset: 2px;
}

/* Каждая аватарка обёрнута в TagTip — перекрытие считается по обёрткам. */
.avatar-stack > * + * {
  margin-left: -8px;
}

.avatar-stack__face {
  display: inline-flex;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  overflow: hidden;
  /* Белое кольцо отделяет соседние аватарки при перекрытии. */
  box-shadow: 0 0 0 2px #fff;
  background: #F3F4F6;
}

.avatar-stack__img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-stack__more {
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: #F3F4F6;
  box-shadow: 0 0 0 2px #fff;
  font-size: 0.6875rem;
  font-weight: 600;
  color: #4B5563;
}
</style>
