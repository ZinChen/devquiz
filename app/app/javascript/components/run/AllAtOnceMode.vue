<template>
  <div class="all-at-once">
    <aside class="question-sidebar" aria-hidden="true">
      <div class="question-sidebar__card">
      <div class="question-sidebar__grid">
        <button
          v-for="(q, idx) in questions" :key="q.id"
          @click="pickFromSidebar(idx, $event)"
          class="question-sidebar__cell"
          tabindex="-1"
          :class="{
            'question-sidebar__cell--answered': isAnswered(q),
            'question-sidebar__cell--active':   idx === activeIndex,
          }"
          :title="String(idx + 1)"
        ><span class="question-sidebar__cell-bar"></span></button>
      </div>
      </div>
    </aside>

    <form class="all-at-once__content" @submit.prevent="$emit('submit')">
      <div
        v-for="(q, idx) in questions" :key="q.id"
        class="question-item"
        :ref="el => { if (el) questionEls[idx] = el }"
      >
        <div class="question-item__header">
          <p class="question-item__counter">Вопрос {{ idx + 1 }}</p>
          <BookmarkButton v-if="q.dbId" :question-id="q.dbId" :initial="bookmarkedIds.includes(q.dbId)" />
        </div>
        <p class="question-item__text" v-html="formatText(q.text)"></p>

        <CodeChallengeQuestion
          v-if="q.type === 'code_challenge'"
          :question="q"
          :answers="answers"
          :mode="challengeMode"
          :hint-shown="isHintShown?.(q.id) ?? false"
          @hint-used="markHintUsed?.($event)"
        />
        <QuestionOptions
          v-else
          :question="q"
          :answers="answers"
          :focusedOptIdx="idx === activeIndex ? focusedOptIdx : -1"
          :optionStyle="optionStyle"
          :optionLetterStyle="optionLetterStyle"
          :optionLetter="optionLetter"
          @pick="onPick(q, $event)"
        />
      </div>

      <div class="submit-row">
        <button
          ref="submitBtn"
          type="submit"
          class="btn btn-primary all-at-once__submit-btn"
          :class="{ 'all-at-once__submit-btn--disabled': answeredCount < questions.length }"
          :aria-disabled="answeredCount < questions.length"
          @click="answeredCount < questions.length && $event.preventDefault()"
        >Завершить тест</button>
      </div>
      <p v-if="answeredCount < questions.length" class="submit-hint">
        Ответьте на все вопросы
      </p>
    </form>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import QuestionOptions from '@/components/run/QuestionOptions.vue'
import CodeChallengeQuestion from '@/components/run/CodeChallengeQuestion.vue'
import BookmarkButton from '@/components/BookmarkButton.vue'

const props = defineProps({
  questions:         Array,
  answers:           Object,
  answeredCount:     Number,
  bookmarkedIds:     { type: Array, default: () => [] },
  isAnswered:        Function,
  isHintShown:       Function,
  markHintUsed:      Function,
  optionStyle:       Function,
  optionLetterStyle: Function,
  optionLetter:      Function,
  formatText:        Function,
  challengeMode:     { type: String, default: 'highlight' },
})

const emit = defineEmits(['submit', 'index-change'])

const questionEls   = ref([])
const activeIndex   = ref(0)
const focusedOptIdx = ref(0)
const submitBtn     = ref(null)

// Кнопка «Завершить» — такая же остановка в кольце, как вопросы: стрелка
// вправо с последнего вопроса ведёт на неё, а с неё — на первый вопрос.
function focusSubmit() {
  const el = submitBtn.value
  if (!el) return
  el.focus()
  el.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

// Клик мышью фокусирует кнопку даже при tabindex="-1" (кроме Safari), а
// isInteractiveTarget затем блокирует стрелки на любой кнопке — снимаем
// фокус, чтобы клавиатура сразу заработала с выбранным вопросом.
function pickFromSidebar(idx, e) {
  scrollTo(idx)
  e.currentTarget?.blur()
}

function scrollTo(idx) {
  // Позиция выбрана явно (стрелкой или кликом по сайдбару) — до следующего
  // ручного скролла она главнее того, что видно на экране. Иначе у последнего
  // вопроса выбор откатывался на предыдущий: страница упирается в конец,
  // и первым «видимым» остаётся предыдущий вопрос.
  pinnedIndex = idx
  emit('index-change', idx)
  activeIndex.value = idx
  focusedOptIdx.value = 0
  const el = questionEls.value[idx]
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function onPick(q, optId) {
  props.answers[q.id] = optId
}

// Вопрос считается видимым, если на экране есть заметная его часть, —
// торчащий из-за кромки край не в счёт.
const VISIBLE_MARGIN = 80

function isQuestionVisible(idx) {
  const el = questionEls.value[idx]
  if (!el) return false

  const rect = el.getBoundingClientRect()
  const top = Math.max(rect.top, 0)
  const bottom = Math.min(rect.bottom, window.innerHeight)

  return bottom - top >= Math.min(VISIBLE_MARGIN, rect.height)
}

function currentQuestion() {
  return props.questions[activeIndex.value]
}

// Горячие клавиши висят на window, поэтому пробел и Enter перехватывались
// даже когда фокус стоял на кнопке «Завершить тест»: preventDefault не давал
// браузеру её нажать, а пробел вместо этого снимал ответ.
//
// Варианты ответа — label со скрытым input, фокус они не получают, так что
// выбор ответа с клавиатуры это не задевает.
const INTERACTIVE_TAGS = [ 'BUTTON', 'A', 'INPUT', 'TEXTAREA', 'SELECT' ]

function isInteractiveTarget(target) {
  if (!target) return false
  return target.isContentEditable || INTERACTIVE_TAGS.includes(target.tagName)
}

function handleKeydown(e) {
  // Кнопка «Завершить» — остановка в том же кольце, что и вопросы.
  const onSubmit = e.target === submitBtn.value

  if (onSubmit) {
    // Enter и пробел оставляем браузеру — они нажимают саму кнопку.
    if (e.key === 'Enter' || e.key === ' ') return

    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
      e.preventDefault()
      // Снимаем фокус, иначе следующая стрелка снова придёт «с кнопки».
      e.target.blur()
      scrollTo(e.key === 'ArrowRight' ? 0 : props.questions.length - 1)
      return
    }

    // Вверх-вниз правят ответ последнего вопроса: иначе, дойдя до кнопки,
    // поменять его с клавиатуры было бы нельзя. Возвращаемся к нему и
    // передаём событие общей ветке стрелок ниже.
    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return

    e.target.blur()
    activeIndex.value = props.questions.length - 1
    emit('index-change', activeIndex.value)
  }

  if (!onSubmit && isInteractiveTarget(e.target)) return

  const q = currentQuestion()
  if (!q) return

  if (q.type === 'code_challenge' && props.challengeMode === 'fix') return
  const isCodeInput = q.type === 'code_challenge' && (props.challengeMode === 'fill' || props.challengeMode === 'fix')

  if (e.key === 'ArrowRight') {
    if (isCodeInput) return
    e.preventDefault()
    if (activeIndex.value === props.questions.length - 1) focusSubmit()
    else scrollTo(activeIndex.value + 1)
  } else if (e.key === 'ArrowLeft') {
    if (isCodeInput) return
    e.preventDefault()
    if (activeIndex.value === 0) focusSubmit()
    else scrollTo(activeIndex.value - 1)
  } else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    e.preventDefault()

    // Ответ не должен меняться у вопроса, которого не видно: сначала
    // показываем его, менять будет уже следующее нажатие.
    if (!isQuestionVisible(activeIndex.value)) {
      scrollTo(activeIndex.value)
      return
    }

    const opts = q.options
    if (!opts?.length) return
    if (q.type === 'multiple') {
      if (e.key === 'ArrowUp') {
        focusedOptIdx.value = focusedOptIdx.value <= 0 ? opts.length - 1 : focusedOptIdx.value - 1
      } else {
        focusedOptIdx.value = focusedOptIdx.value >= opts.length - 1 ? 0 : focusedOptIdx.value + 1
      }
    } else {
      const currentOptId  = props.answers[q.id]
      const currentOptPos = opts.findIndex(o => o.id === currentOptId)
      let nextPos
      if (e.key === 'ArrowUp') {
        nextPos = currentOptPos <= 0 ? opts.length - 1 : currentOptPos - 1
      } else {
        nextPos = currentOptPos >= opts.length - 1 ? 0 : currentOptPos + 1
      }
      props.answers[q.id] = opts[nextPos].id
    }
  } else if (e.key === ' ') {
    if (q.type === 'code_challenge') return
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
    }
  }
}

// Индекс, выбранный явно через scrollTo. Сбрасывается, как только
// пользователь скроллит сам.
let pinnedIndex = null

function atPageBottom() {
  return window.innerHeight + window.scrollY >= document.body.scrollHeight - 4
}

// scrollIntoView({block:'start'}) учитывает scroll-margin-top карточки
// (1rem), поэтому итоговый top равен ~16px, а не 0 — порог должен это
// покрывать, иначе pinnedIndex не снимается никогда и handleScroll
// перестаёт пересчитывать активный вопрос при обычном скролле.
const SCROLL_TARGET_TOLERANCE = 20

function handleScroll() {
  if (pinnedIndex !== null) {
    // Плавный скролл от scrollTo ещё идёт: ждём, пока он дойдёт до цели.
    const el = questionEls.value[pinnedIndex]
    const reached = atPageBottom() ||
      (el && Math.abs(el.getBoundingClientRect().top) < SCROLL_TARGET_TOLERANCE)
    if (!reached) return
    pinnedIndex = null
    return
  }

  // У конца страницы активен последний вопрос. Отдельный случай, потому что
  // по «первому видимому» им всегда оказывался бы предпоследний: последний
  // вопрос невозможно поднять к верхней кромке — под ним ничего нет.
  //
  // Видимость считается с запасом: у предыдущей карточки из-за кромки торчит
  // несколько пикселей, и по «bottom > 0» активным становился бы именно
  // предыдущий вопрос, а не тот, к которому проскроллили.
  const idx = atPageBottom()
    ? props.questions.length - 1
    : props.questions.findIndex((_q, i) => isQuestionVisible(i))

  if (idx !== -1 && idx !== activeIndex.value) {
    emit('index-change', idx)
    activeIndex.value = idx
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
  window.addEventListener('scroll', handleScroll, { passive: true })
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
  window.removeEventListener('scroll', handleScroll)
})
</script>

<style scoped>
.all-at-once {
  max-width: 42rem;
  margin: 0 auto;
  position: relative;
}

.question-sidebar {
  width: 1.5rem;
  position: absolute;
  left: calc(-1.5rem - 1rem);
  top: 0;
  bottom: 0;
  pointer-events: none;
}

.question-sidebar__card {
  position: sticky;
  top: 1rem;
  pointer-events: auto;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: 0.5rem;
  padding: 0.75rem 0.375rem;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.question-sidebar__grid {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
  width: 100%;
}

.question-sidebar__cell {
  width: 100%;
  height: 14px;
  border: none;
  cursor: pointer;
  background: transparent;
  padding: 0;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  outline: none;
}

.question-sidebar__cell:hover::after {
  content: attr(title);
  position: absolute;
  left: calc(100% + 8px);
  top: 50%;
  transform: translateY(-50%);
  background: #1f2937;
  color: #fff;
  font-size: 0.65rem;
  font-weight: 600;
  padding: 2px 5px;
  border-radius: 4px;
  white-space: nowrap;
  pointer-events: none;
  z-index: 10;
}

.question-sidebar__cell-bar {
  display: block;
  width: 0.625rem;
  height: 2px;
  border-radius: 2px;
  background: #D1D5DB;
  transition: background 0.15s;
}

.question-sidebar__cell--answered .question-sidebar__cell-bar {
  background: #4F63F5;
}

.question-sidebar__cell--active .question-sidebar__cell-bar {
  background: #4F63F5;
  height: 4px;
}

.all-at-once__content {
  width: 100%;
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

.question-item__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.25rem;
}

.question-item__counter {
  font-weight: 500;
  font-size: 0.75rem;
  color: #9CA3AF;
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

.all-at-once__submit-btn {
  padding-left: 2rem;
  padding-right: 2rem;
}

.all-at-once__submit-btn--disabled {
  background: #C7D2FE;
  border-color: #C7D2FE;
  cursor: not-allowed;
}

.all-at-once__submit-btn:focus-visible {
  outline: 2px solid #4F63F5;
  outline-offset: 2px;
}
</style>
