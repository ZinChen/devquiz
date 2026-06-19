<template>
  <div class="all-at-once">
    <aside class="question-sidebar">
      <div class="question-sidebar__grid">
        <button
          v-for="(q, idx) in questions" :key="q.id"
          @click="scrollTo(idx)"
          class="question-sidebar__cell"
          :class="{ 'question-sidebar__cell--answered': isAnswered(q) }"
        >{{ idx + 1 }}</button>
      </div>
    </aside>

    <form class="all-at-once__content" @submit.prevent="$emit('submit')">
      <div
        v-for="(q, idx) in questions" :key="q.id"
        class="question-item"
        :ref="el => { if (el) questionEls[idx] = el }"
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
  </div>
</template>

<script setup>
import { ref } from 'vue'
import QuestionOptions from '@/components/run/QuestionOptions.vue'

const props = defineProps({
  questions:         Array,
  answers:           Object,
  answeredCount:     Number,
  isAnswered:        Function,
  optionStyle:       Function,
  optionLetterStyle: Function,
  optionLetter:      Function,
  formatText:        Function,
})

defineEmits(['submit'])

const questionEls = ref([])

function scrollTo(idx) {
  const el = questionEls.value[idx]
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<style scoped>
.all-at-once {
  display: flex;
  gap: 1.5rem;
  align-items: flex-start;
}

.question-sidebar {
  width: 3rem;
  flex-shrink: 0;
  position: sticky;
  top: 1rem;
}

.question-sidebar__grid {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.question-sidebar__cell {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 6px;
  font-size: 0.7rem;
  font-weight: 600;
  background: #F3F4F6;
  color: #9CA3AF;
  border: none;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.question-sidebar__cell--answered {
  background: #C7D2FE;
  color: #3730A3;
}

.question-sidebar__cell:hover {
  background: #E0E7FF;
  color: #4F63F5;
}

.all-at-once__content {
  flex: 1;
  min-width: 0;
}

.question-item {
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  background: #fff;
  border-radius: var(--rounded-box, 1rem);
  padding: 1.5rem;
  margin-bottom: 1rem;
  scroll-margin-top: 1rem;
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
