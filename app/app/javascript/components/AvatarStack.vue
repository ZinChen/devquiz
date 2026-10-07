<template>
  <div v-if="viewers.length" class="avatar-stack" :title="allNames">
    <span
      v-for="v in shown" :key="v.key"
      class="avatar-stack__item"
      :style="{ width: size + 'px', height: size + 'px' }"
      :title="v.name"
    >
      <img v-if="v.avatarUrl" :src="v.avatarUrl" alt="" class="avatar-stack__img" />
      <GeneratedAvatar v-else :seed="v.avatarSeed || ''" :name="v.name || ''" />
    </span>
    <span
      v-if="hiddenCount > 0"
      class="avatar-stack__item avatar-stack__more"
      :style="{ width: size + 'px', height: size + 'px' }"
    >+{{ hiddenCount }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import GeneratedAvatar from '@/components/GeneratedAvatar.vue'

// Стопка перекрывающихся аватарок с «+N» — как в карточках команды: видно, что
// здесь кто-то есть, не занимая места под каждого.
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
const allNames    = computed(() => props.viewers.map(v => v.name).join(', '))
</script>

<style scoped>
.avatar-stack {
  display: inline-flex;
  align-items: center;
}

.avatar-stack__item {
  display: inline-flex;
  flex-shrink: 0;
  border-radius: 50%;
  overflow: hidden;
  /* Белое кольцо отделяет соседние аватарки при перекрытии. */
  box-shadow: 0 0 0 2px #fff;
  background: #F3F4F6;
}

.avatar-stack__item + .avatar-stack__item {
  margin-left: -8px;
}

.avatar-stack__img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-stack__more {
  align-items: center;
  justify-content: center;
  font-size: 0.6875rem;
  font-weight: 600;
  color: #4B5563;
}
</style>
