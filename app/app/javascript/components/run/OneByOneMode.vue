<template>
  <div class="one-by-one-wrap">
    <div class="question-nav">
      <button
        v-for="(q, idx) in questions" :key="q.id"
        @click="goTo(idx)"
        class="question-nav__cell"
        :class="{
          'question-nav__cell--active':   idx === currentIndex,
          'question-nav__cell--answered': idx !== currentIndex && isAnswered(q),
        }"
      >{{ idx + 1 }}</button>
    </div>

    <div class="question-card-container" :style="{ height: containerHeight + 'px' }">
      <TransitionGroup name="card-slide" tag="div" class="question-card-inner" @enter="onCardEnter">
        <div
          v-if="currentQuestion"
          :key="currentQuestion.id"
          class="question-card"
          ref="cardEl"
        >
          <div class="question-card__progress-track">
            <div class="question-card__progress-fill" :style="{ width: progressPercent + '%', transition: progressAnimated ? 'width 0.3s ease' : 'none' }"></div>
          </div>

          <p class="question-card__counter">Вопрос {{ currentIndex + 1 }} из {{ questions.length }}</p>
          <p class="question-card__text" v-html="formatText(currentQuestion.text)"></p>

          <QuestionOptions
            :question="currentQuestion"
            :answers="answers"
            :optionStyle="optionStyle"
            :optionLetterStyle="optionLetterStyle"
            :optionLetter="optionLetter"
            @pick="onRadioPick(currentQuestion, $event)"
          />

          <div class="question-card__footer">
            <button
              v-if="currentIndex > 0"
              @click="goTo(currentIndex - 1)"
              class="btn btn-ghost btn-sm question-card__btn-back"
            >← Назад</button>
            <div v-else></div>

            <button
              v-if="currentIndex < questions.length - 1"
              @click="goTo(currentIndex + 1)"
              class="btn btn-sm question-card__btn-next"
              :disabled="!isAnswered(currentQuestion)"
            >Далее →</button>
            <button
              v-else
              @click="$emit('submit')"
              class="btn btn-sm question-card__btn-next"
              :disabled="answeredCount < questions.length"
            >Завершить</button>
          </div>
        </div>
      </TransitionGroup>
    </div>

    <p v-if="answeredCount < questions.length" class="question-nav__status">
      Отвечено {{ answeredCount }} из {{ questions.length }}
    </p>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, watch, onMounted, onUnmounted } from 'vue'
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
  savedIndex:        { type: Number, default: 0 },
})

const emit = defineEmits(['submit', 'index-change'])

const currentIndex      = ref(props.savedIndex)
const cardEl            = ref(null)
const containerHeight   = ref(300)
const focusedOptIdx     = ref(0)
const progressAnimated  = ref(false)

const currentQuestion = computed(() => props.questions[currentIndex.value])

const progressPercent = computed(() =>
  Math.round((props.answeredCount / props.questions.length) * 100)
)

function goTo(idx) {
  if (cardEl.value) {
    const el = Array.isArray(cardEl.value) ? cardEl.value[0] : cardEl.value
    if (el) containerHeight.value = el.offsetHeight
  }
  currentIndex.value = idx
  focusedOptIdx.value = 0
  emit('index-change', idx)
}

function onCardEnter(el) {
  nextTick(() => { containerHeight.value = el.offsetHeight })
}

function onRadioPick(q, optId, autoAdvance = true) {
  props.answers[q.id] = optId
  if (autoAdvance) {
    const nextIdx = currentIndex.value + 1
    if (nextIdx < props.questions.length) {
      setTimeout(() => goTo(nextIdx), 400)
    }
  }
}

watch(() => props.savedIndex, val => { currentIndex.value = val }, { immediate: false })

function handleKeydown(e) {
  const q = currentQuestion.value
  if (!q) return

  if (e.key === 'ArrowRight') {
    e.preventDefault()
    goTo((currentIndex.value + 1) % props.questions.length)
  } else if (e.key === 'ArrowLeft') {
    e.preventDefault()
    goTo((currentIndex.value - 1 + props.questions.length) % props.questions.length)
  } else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    e.preventDefault()
    const opts = q.options
    if (!opts?.length) return
    if (q.type === 'multiple') {
      if (e.key === 'ArrowUp') {
        focusedOptIdx.value = focusedOptIdx.value <= 0 ? opts.length - 1 : focusedOptIdx.value - 1
      } else {
        focusedOptIdx.value = focusedOptIdx.value >= opts.length - 1 ? 0 : focusedOptIdx.value + 1
      }
    } else {
      const currentOptId = props.answers[q.id]
      const currentOptPos = opts.findIndex(o => o.id === currentOptId)
      let nextPos
      if (e.key === 'ArrowUp') {
        nextPos = currentOptPos <= 0 ? opts.length - 1 : currentOptPos - 1
      } else {
        nextPos = currentOptPos >= opts.length - 1 ? 0 : currentOptPos + 1
      }
      onRadioPick(q, opts[nextPos].id, false)
    }
  } else if (e.key === ' ') {
    e.preventDefault()
    const opts = q.options
    if (!opts?.length) return
    if (q.type === 'multiple') {
      const optId = opts[focusedOptIdx.value]?.id
      if (!optId) return
      if (!Array.isArray(props.answers[q.id])) props.answers[q.id] = []
      const idx = props.answers[q.id].indexOf(optId)
      if (idx === -1) props.answers[q.id].push(optId)
      else props.answers[q.id].splice(idx, 1)
    } else {
      props.answers[q.id] = null
    }
  } else if (e.key === 'Enter') {
    e.preventDefault()
    if (q.type === 'multiple') {
      const opts = q.options
      if (!opts?.length) return
      const optId = opts[focusedOptIdx.value]?.id
      if (!optId) return
      if (!Array.isArray(props.answers[q.id])) props.answers[q.id] = []
      const idx = props.answers[q.id].indexOf(optId)
      if (idx === -1) props.answers[q.id].push(optId)
      else props.answers[q.id].splice(idx, 1)
    } else if (currentIndex.value < props.questions.length - 1) {
      if (props.isAnswered(q)) goTo(currentIndex.value + 1)
    } else {
      if (props.answeredCount >= props.questions.length) emit('submit')
    }
  }
}

let resizeObserver = null

function observeCard() {
  resizeObserver?.disconnect()
  nextTick(() => {
    const el = cardEl.value
    const node = el ? (Array.isArray(el) ? el[0] : el) : null
    if (!node) return
    containerHeight.value = node.offsetHeight
    resizeObserver = new ResizeObserver(() => {
      containerHeight.value = node.offsetHeight
    })
    resizeObserver.observe(node)
  })
}

watch(currentQuestion, observeCard)

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
  observeCard()
  nextTick(() => { progressAnimated.value = true })
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
  resizeObserver?.disconnect()
})
</script>

<style scoped>
.one-by-one-wrap {
  max-width: 42rem;
  margin: 0 auto;
}

.question-nav {
  display: grid;
  grid-template-columns: repeat(20, 1fr);
  gap: 4px;
  margin-bottom: 1rem;
}

.question-nav__cell {
  aspect-ratio: 1;
  width: 100%;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 600;
  transition: background 0.15s, color 0.15s;
  background: #F3F4F6;
  color: #9CA3AF;
  border: none;
  cursor: pointer;
}

.question-nav__cell--active {
  background: #4F63F5;
  color: #fff;
}

.question-nav__cell--answered {
  background: #C7D2FE;
  color: #3730A3;
}

.question-nav__status {
  font-size: 0.75rem;
  color: #9CA3AF;
  text-align: center;
  margin-top: 1rem;
}

.question-card-container {
  position: relative;
  overflow: hidden;
  transition: height 0.35s cubic-bezier(0.4, 0, 0.2, 1);
}

.question-card-inner {
  position: relative;
}

.question-card {
  position: relative;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  padding: 1.5rem;
  overflow: hidden;
  border-radius: var(--rounded-box, 1rem);
  background: #fff;
}

.question-card__progress-track {
  position: absolute;
  top: 0; left: 0; right: 0;
  height: 3px;
  background: #F3F4F6;
}

.question-card__progress-fill {
  height: 100%;
  background: #4F63F5;
}

.question-card__counter {
  font-size: 0.75rem;
  color: #9CA3AF;
  font-weight: 500;
  margin-bottom: 0.25rem;
}

.question-card__text {
  font-size: 1rem;
  line-height: 1.6;
  margin-bottom: 1rem;
}

.question-card__footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 1.5rem;
}

.question-card__btn-back {
  color: #9CA3AF;
}

.question-card__btn-next {
  background: #4F63F5;
  border: none;
  color: #fff;
}

.card-slide-enter-active,
.card-slide-leave-active {
  transition: opacity 0.2s ease;
  position: absolute;
  top: 0; left: 0;
  width: 100%;
}
.card-slide-enter-from,
.card-slide-leave-to { opacity: 0; }
.card-slide-enter-to,
.card-slide-leave-from { opacity: 1; }
</style>
