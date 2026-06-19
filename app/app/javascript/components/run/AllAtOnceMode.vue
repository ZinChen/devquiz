<template>
  <form @submit.prevent="$emit('submit')">
    <div
      v-for="(q, idx) in questions" :key="q.id"
      class="question-item"
    >
      <p class="question-item__counter">Вопрос {{ idx + 1 }}</p>
      <p class="question-item__text" v-html="formatText(q.text)"></p>

      <QuestionOptions
        :question="q"
        :answers="answers"
        :optionStyle="optionStyle"
        :optionLetterStyle="optionLetterStyle"
        :optionLetter="optionLetter"
      />
    </div>

    <div class="submit-row">
      <button
        type="submit"
        class="btn px-8 btn-primary"
        :disabled="answeredCount < questions.length"
      >Завершить тест</button>
    </div>
    <p v-if="answeredCount < questions.length" class="submit-hint">
      Ответьте на все вопросы
    </p>
  </form>
</template>

<script setup>
import QuestionOptions from '@/components/run/QuestionOptions.vue'

defineProps({
  questions:         Array,
  answers:           Object,
  answeredCount:     Number,
  optionStyle:       Function,
  optionLetterStyle: Function,
  optionLetter:      Function,
  formatText:        Function,
})

defineEmits(['submit'])
</script>

<style scoped>
.question-item {
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  background: #fff;
  border-radius: var(--rounded-box, 1rem);
  padding: 1.5rem;
  margin-bottom: 1rem;
}

.question-item__counter {
  font-weight: 500;
  font-size: 0.75rem;
  color: #9CA3AF;
  margin-bottom: 0.25rem;
}

.question-item__text {
  font-size: 1rem;
  line-height: 1.6;
  margin-bottom: 1rem;
}

.submit-row {
  display: flex;
  justify-content: flex-end;
  margin-top: 1.5rem;
}

.submit-hint {
  font-size: 0.75rem;
  color: #9CA3AF;
  text-align: right;
  margin-top: 0.5rem;
}
</style>
