<template>
  <div class="options-list">
    <label
      v-for="(opt, oi) in question.options" :key="opt.id"
      class="option"
      :style="optionStyle(question, opt)"
      @click="question.type !== 'multiple' && $emit('pick', opt.id)"
    >
      <span
        class="option__letter"
        :style="optionLetterStyle(question, opt)"
      >
        {{ optionLetter(oi) }}
      </span>
      <div class="option__body">
        <input
          v-if="question.type === 'multiple'"
          type="checkbox"
          :value="opt.id"
          v-model="answers[question.id]"
          class="hidden"
        />
        <input
          v-else
          type="radio"
          :name="question.id"
          :value="opt.id"
          v-model="answers[question.id]"
          class="hidden"
        />
        <span class="option__text">{{ opt.text }}</span>
      </div>
    </label>
  </div>
</template>

<script setup>
defineProps({
  question:         Object,
  answers:          Object,
  optionStyle:      Function,
  optionLetterStyle: Function,
  optionLetter:     Function,
})

defineEmits(['pick'])
</script>

<style scoped>
.options-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.option {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 0.75rem;
  border-radius: 0.75rem;
  cursor: pointer;
  transition: background-color 0.15s;
}

.option__letter {
  flex-shrink: 0;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
  margin-top: 0.125rem;
}

.option__body {
  flex: 1;
}

.option__text {
  font-size: 0.875rem;
}
</style>
