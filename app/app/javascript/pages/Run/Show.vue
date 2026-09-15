<template>
  <AppLayout>
    <div class="result-wrap">
      <div v-if="preview" class="result-preview-note">
        <span class="result-preview-note__icon" aria-hidden="true">i</span>
        <div>
          <p class="result-preview-note__title">Тест из файла — результат нигде не сохранён</p>
          <p class="result-preview-note__text">
            Эта попытка не попала ни в вашу историю, ни в статистику теста.
            Чтобы результат не потерялся, скачайте отчёт.
          </p>
        </div>
      </div>

      <div class="result-summary">
        <p class="result-summary__label">
          Тест завершён: {{ test.title }}
          <span v-if="challengeModeLabel" class="result-summary__mode-badge">{{ challengeModeLabel }}</span>
        </p>
        <div class="result-summary__score" :style="{ color: scoreColor }">
          {{ attempt.score.toFixed(0) }}%
        </div>
        <p class="result-summary__correct">
          {{ attempt.correctCount }} правильных из {{ attempt.totalQuestions }}
        </p>
        <p class="result-summary__time">Время: {{ formatTime(attempt.timeSpent) }}</p>

        <div v-if="preview" class="result-summary__actions">
          <button type="button" class="btn btn-primary" @click="downloadReport">
            Сохранить результат
          </button>
          <button type="button" class="btn btn-ghost" @click="$emit('retry')">
            Пройти снова
          </button>
          <Link href="/" class="btn btn-ghost">Все тесты</Link>
        </div>
        <div v-else class="result-summary__actions">
          <Link
            v-if="suggestedNextMode"
            :href="`/tests/${test.slug}/run/new?mode=${suggestedNextMode}`"
            class="btn btn-primary"
          >
            Пройти в режиме {{ CHALLENGE_MODE_LABELS[suggestedNextMode] }}
          </Link>
          <Link :href="`/tests/${test.slug}/run/new`" :class="suggestedNextMode ? 'btn btn-ghost' : 'btn btn-primary'">
            Пройти снова
          </Link>
          <Link href="/" class="btn btn-ghost">Все тесты</Link>
        </div>
      </div>

      <!-- От частного к общему: конкретные вопросы, затем их темы, затем куда идти дальше. -->
      <template v-if="!preview && hasWeakTopics">
        <div v-if="weakTopics.recentMistakes?.length" class="weak-header">
          <h2 class="result-breakdown-title">Вопросы, где вы ошиблись</h2>
          <Link
            v-if="weakTopics.hasWeakInThisTest"
            :href="`/tests/${test.slug}/run/new?only=weak`"
            class="btn btn-primary btn-sm"
          >
            Тренировка по ошибкам
          </Link>
        </div>

        <div class="weak-topics">
          <ul v-if="weakTopics.recentMistakes?.length" class="weak-topics__mistakes-list">
            <li v-for="m in weakTopics.recentMistakes" :key="`${m.testSlug}-${m.questionId}`">
              <!-- Вопрос этого теста уже отрисован ниже — скроллим к нему, а не уходим со страницы. -->
              <a
                v-if="m.testSlug === test.slug"
                :href="`#question-${m.questionId}`"
                class="weak-topics__mistake-link"
                @click.prevent="scrollToQuestion(m.questionId)"
              >{{ m.text }}</a>
              <Link v-else :href="`/tests/${m.testSlug}`" class="weak-topics__mistake-link">{{ m.text }}</Link>
              <!-- Одна ошибка — счётчик не несёт информации, показываем только повторные. -->
              <span v-if="m.wrongCount > 1" class="weak-topics__mistake-count">
                {{ m.wrongCount }} {{ timesLabel(m.wrongCount) }}
              </span>
            </li>
          </ul>

          <section class="weak-topics__section">
            <h3 class="weak-topics__subtitle">Слабые темы</h3>
            <div class="weak-topics__tags">
              <!-- Фон кодирует число ошибок, точка слева — саму тему: два разных
                   признака, поэтому цвет темы не спорит с градацией. -->
              <span
                v-for="topic in weakTopics.tags" :key="topic.slug"
                class="weak-topics__tag"
                :class="`weak-topics__tag--${topic.level}`"
                :title="topicTitle(topic)"
              >
                <span
                  v-if="topic.color"
                  class="weak-topics__tag-dot"
                  :style="{ background: topic.color }"
                  aria-hidden="true"
                ></span>
                {{ topic.label }}
                <span v-if="topic.wrongCount > 1" class="weak-topics__tag-count">{{ topic.wrongCount }}</span>
              </span>
            </div>
          </section>

          <section v-if="weakTopics.recommendedTests?.length" class="weak-topics__section">
            <h3 class="weak-topics__subtitle">Рекомендуемые тесты</h3>
            <div class="weak-topics__tests">
              <Link
                v-for="rt in weakTopics.recommendedTests" :key="rt.slug"
                :href="`/tests/${rt.slug}`"
                class="weak-topics__test-link"
              >
                {{ rt.title }}
              </Link>
            </div>
          </section>
        </div>
      </template>

      <div class="weak-header">
        <h2 class="result-breakdown-title">Разбор ответов</h2>
        <!-- Подпись называет действие по клику, а не текущее состояние:
             «Только неправильные» в роли статуса читалась бы двояко. -->
        <button
          v-if="wrongCount && wrongCount < answersDetail.length"
          type="button"
          class="btn btn-ghost btn-sm"
          @click="onlyWrong = !onlyWrong"
        >
          {{ onlyWrong ? `Все ответы (${answersDetail.length})` : `Только неправильные (${wrongCount})` }}
        </button>
      </div>

      <div
        v-for="(item, idx) in visibleAnswers" :key="item.questionId"
        :id="`question-${item.questionId}`"
        class="result-item"
        :class="{ 'result-item--highlight': highlightedQuestion === item.questionId }"
        :style="{ borderColor: item.correct ? '#10B98130' : '#EF444430' }"
      >
        <div class="result-item__header">
          <span
            class="result-item__badge"
            :style="item.correct ? 'background:#D1FAE5;color:#065F46' : 'background:#FEE2E2;color:#991B1B'"
          >
            {{ item.correct ? '✓' : '✗' }}
          </span>
          <p class="result-item__question" v-html="formatText(item.questionText)"></p>
        </div>

        <div v-if="item.type === 'code_challenge'" class="result-code-challenge">
          <!-- highlight: show code with highlighted correct/selected lines -->
          <template v-if="item.challengeMode === 'highlight'">
            <pre class="result-code-block result-code-block--lines"><code><template
                v-for="(line, i) in (item.code ?? '').trimEnd().split('\n')"
                :key="i"
              ><div
                  v-if="i === 0 && (isCorrectLine(item, 'after:0') || isSelectedLine(item, 'after:0'))"
                  class="result-code-line result-code-line--gap"
                  :class="{
                    'result-code-line--correct':  isCorrectLine(item, 'after:0'),
                    'result-code-line--selected': !item.correct && isSelectedLine(item, 'after:0') && !isCorrectLine(item, 'after:0'),
                  }"
                >{{ isCorrectLine(item, 'after:0') && item.insertText ? item.insertText : ' ' }}</div><div
                  class="result-code-line"
                  :class="{
                    'result-code-line--correct':  isCorrectLine(item, i + 1),
                    'result-code-line--selected': !item.correct && isSelectedLine(item, i + 1) && !isCorrectLine(item, i + 1),
                  }"
                ><template v-if="tokenCache[item.questionId]"><span
                    v-for="(tok, ti) in (tokenCache[item.questionId][i] || [])"
                    :key="ti"
                    :style="tok.color ? { color: tok.color } : {}"
                  >{{ tok.content }}</span></template><template v-else>{{ line || ' ' }}</template></div><div
                  v-if="isCorrectLine(item, `after:${i + 1}`) || isSelectedLine(item, `after:${i + 1}`)"
                  class="result-code-line result-code-line--gap"
                  :class="{
                    'result-code-line--correct':  isCorrectLine(item, `after:${i + 1}`),
                    'result-code-line--selected': !item.correct && isSelectedLine(item, `after:${i + 1}`) && !isCorrectLine(item, `after:${i + 1}`),
                  }"
                >{{ isCorrectLine(item, `after:${i + 1}`) && item.insertText ? item.insertText : ' ' }}</div></template></code></pre>
            <div class="result-code-legend">
              <span class="result-code-legend__item result-code-legend__item--correct">верная строка</span>
              <span v-if="!item.correct" class="result-code-legend__item result-code-legend__item--wrong">ваш выбор</span>
            </div>
          </template>
          <!-- fill / select: show typed answer vs correct -->
          <template v-else-if="item.challengeMode !== 'fix'">
            <div class="result-code-answers" @scroll.capture="syncAnswerScroll">
              <div class="result-code-answer" :class="item.correct ? 'result-code-answer--correct' : 'result-code-answer--wrong'">
                <span class="result-code-answer__label">Ваш ответ:</span>
                <code class="result-code-answer__value">{{ item.selectedAnswer || '(пусто)' }}</code>
              </div>
              <div v-if="!item.correct" class="result-code-answer result-code-answer--correct">
                <span class="result-code-answer__label">Правильный ответ:</span>
                <code class="result-code-answer__value">{{ item.correctAnswer }}</code>
              </div>
            </div>
          </template>

          <!-- fix: show original code + word-level diff of typed answer vs correct -->
          <template v-else>
            <pre class="result-code-block"><code><template
                v-if="tokenCache[item.questionId]"
              ><template
                  v-for="(lineTokens, li) in tokenCache[item.questionId]" :key="li"
                ><template v-if="li > 0">{{ '\n' }}</template><span
                    v-for="(tok, ti) in lineTokens" :key="ti"
                    :style="tok.color ? { color: tok.color } : {}"
                  >{{ tok.content }}</span></template></template><template v-else>{{ item.code }}</template></code></pre>
            <div class="result-code-answers" @scroll.capture="syncAnswerScroll">
              <div class="result-code-answer result-code-answer--diff" :class="item.correct ? 'result-code-answer--correct' : 'result-code-answer--wrong'">
                <span class="result-code-answer__label">Ваш ответ:</span>
                <code v-if="item.selectedAnswer?.length" class="result-code-answer__value result-code-answer__value--diff"><span
                    v-for="(line, li) in item.selectedAnswer" :key="li"
                    class="result-diff-line"
                  ><span
                      v-if="line.kind === 'removed'"
                      class="result-diff-token result-diff-token--removed"
                    >{{ line.content }}</span><template
                      v-else
                    ><span
                        v-for="(tok, ti) in line.tokens" :key="ti"
                        class="result-diff-token"
                        :class="{ 'result-diff-token--added': tok.type === 'added' }"
                      >{{ tok.text }}</span></template></span></code>
                <code v-else class="result-code-answer__value">(пусто)</code>
              </div>
              <div v-if="!item.correct" class="result-code-answer result-code-answer--diff result-code-answer--correct">
                <span class="result-code-answer__label">Правильный ответ:</span>
                <code class="result-code-answer__value result-code-answer__value--diff"><span
                    v-for="(line, li) in item.correctAnswer" :key="li"
                    class="result-diff-line"
                  ><span
                      v-if="line.kind === 'removed'"
                      class="result-diff-token result-diff-token--removed"
                    >{{ line.content }}</span><template
                      v-else
                    ><span
                        v-for="(tok, ti) in line.tokens" :key="ti"
                        class="result-diff-token"
                        :class="{ 'result-diff-token--added': tok.type === 'added' }"
                      >{{ tok.text }}</span></template></span></code>
              </div>
            </div>
          </template>
        </div>
        <div v-else class="result-item__options">
          <div
            v-for="(opt, oi) in item.options" :key="opt.id"
            class="result-option"
            :style="optionStyle(item, opt.id)"
          >
            <span class="result-option__letter" :style="optionLetterStyle(item, opt.id)">
              {{ optionLetter(oi) }}
            </span>
            <span class="result-option__body">
              <span>{{ opt.text }}</span>
              <span
                v-if="opt.explanation && (item.correctIds.includes(opt.id) || item.selectedOptions.includes(opt.id))"
                class="result-option__explanation"
              >{{ opt.explanation }}</span>
            </span>
          </div>
        </div>

        <p v-if="item.explanation" class="result-item__explanation" v-html="formatMarkdown(item.explanation)"></p>

        <div v-if="item.extendedExplanation || item.recommendation" class="result-item__details">
          <button
            class="result-item__details-toggle"
            @click="toggleDetails(item.questionId)"
          >
            {{ openDetails[item.questionId] ? 'Скрыть подробности' : 'Подробнее' }}
            <span class="result-item__details-arrow" :class="{ 'result-item__details-arrow--open': openDetails[item.questionId] }">▾</span>
          </button>
          <div v-if="openDetails[item.questionId]" class="result-item__details-body">
            <div v-if="item.extendedExplanation" class="result-item__extended" v-html="formatMarkdown(item.extendedExplanation)"></div>
            <div v-if="item.recommendation" class="result-item__recommendation">
              <p class="result-item__recommendation-label">Что повторить</p>
              <div v-html="formatMarkdown(item.recommendation)"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { computed, reactive, ref, nextTick, onMounted, onUnmounted } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import { useShiki } from '@/composables/useShiki.js'
import { CHALLENGE_MODE_LABELS, isChallengeModeUnlocked, nextChallengeMode } from '@/composables/challengeModes.js'
import { buildReport, reportFilename } from '@/composables/quizReport.js'

const props = defineProps({
  test:           Object,
  attempt:        Object,
  answersDetail:  Array,
  weakTopics:     { type: Object, default: () => ({}) },
  // Разовое прохождение из перетащенного файла: попытки в БД нет, поэтому
  // вместо ссылок на /tests/:slug показываем скачивание отчёта.
  preview:        { type: Boolean, default: false },
})

const hasWeakTopics = computed(() => Boolean(props.weakTopics?.tags?.length))

const onlyWrong = ref(false)

const wrongCount = computed(() => props.answersDetail?.filter(a => !a.correct).length ?? 0)

const visibleAnswers = computed(() =>
  onlyWrong.value ? props.answersDetail.filter(a => !a.correct) : props.answersDetail
)

// Подсветка гасится по таймеру, поэтому его надо снимать при уходе со страницы.
const highlightedQuestion = ref(null)
let highlightTimer

async function scrollToQuestion(questionId) {
  // Фильтр мог скрыть карточку — тогда ждём перерисовку, иначе скроллить некуда.
  if (!document.getElementById(`question-${questionId}`)) {
    onlyWrong.value = false
    await nextTick()
  }

  const el = document.getElementById(`question-${questionId}`)
  if (!el) return

  el.scrollIntoView({ behavior: 'smooth', block: 'center' })
  highlightedQuestion.value = questionId
  clearTimeout(highlightTimer)
  highlightTimer = setTimeout(() => { highlightedQuestion.value = null }, 1600)
}

onUnmounted(() => clearTimeout(highlightTimer))

// В тултипе описание темы и число ошибок: на самом теге число показано
// только при повторных промахах, чтобы не зашумлять строку единицами.
function topicTitle(topic) {
  const parts = []
  if (topic.description) parts.push(topic.description)
  if (topic.wrongCount > 0) parts.push(`Ошибок: ${topic.wrongCount}`)
  return parts.join(' • ')
}

// «2 раза», но «5 раз» и «11 раз» — вторая форма нужна для 5..20 и хвостов 0, 5-9.
function timesLabel(count) {
  const tail    = count % 10
  const hundred = count % 100
  return tail >= 2 && tail <= 4 && (hundred < 12 || hundred > 14) ? 'раза' : 'раз'
}

defineEmits(['retry'])

function downloadReport() {
  const blob = new Blob([buildReport(props)], { type: 'text/markdown;charset=utf-8' })
  const url  = URL.createObjectURL(blob)
  const a    = document.createElement('a')
  a.href     = url
  a.download = reportFilename(props.test.title)
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

const { ready, init, tokenize } = useShiki()
onMounted(() => init())

const tokenCache = computed(() => {
  if (!ready.value) return {}
  const cache = {}
  props.answersDetail?.forEach(item => {
    if (item.type === 'code_challenge' && item.code) {
      cache[item.questionId] = tokenize(item.code, item.language || 'ruby')
    }
  })
  return cache
})

function syncAnswerScroll(e) {
  const source = e.target
  if (!source.classList?.contains('result-code-answer__value')) return
  const group = source.closest('.result-code-answers')
  if (!group) return
  group.querySelectorAll('.result-code-answer__value').forEach(el => {
    if (el !== source) el.scrollLeft = source.scrollLeft
  })
}

const openDetails = reactive({})
function toggleDetails(questionId) {
  openDetails[questionId] = !openDetails[questionId]
}

function formatMarkdown(text) {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/^## (.+)$/gm, '<h4 class="result-md-h4">$1</h4>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/(<li>.*<\/li>\n?)+/g, '<ul class="result-md-list">$&</ul>')
    .replace(/\s*(Источники:|Источник:)\s*/g, '<br><br>$1<br>')
    .replace(/,\s*(?=https?:\/\/)/g, '<br>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/^(?!<[hul])(.+)$/gm, (m) => m.startsWith('<') ? m : m)
    .replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" target="_blank" rel="noopener" class="result-link">$1</a>')
}

const scoreColor = computed(() => {
  if (props.attempt.score >= 80) return '#10B981'
  if (props.attempt.score >= 50) return '#F59E0B'
  return '#EF4444'
})

const challengeModeLabel = computed(() => CHALLENGE_MODE_LABELS[props.attempt.challengeMode] || null)

const PASS_THRESHOLD = 70

const suggestedNextMode = computed(() => {
  if (!props.attempt.challengeMode) return null
  if (props.attempt.score < PASS_THRESHOLD) return null
  const next = nextChallengeMode(props.test.completedChallengeModes || [])
  return next && next !== props.attempt.challengeMode ? next : null
})

function formatTime(seconds) {
  if (!seconds) return '—'
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  return `${m}м ${s}с`
}

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function formatText(text) {
  if (!text) return ''
  return text
    .replace(/```[^\n]*\n?([\s\S]*?)```/g, (_, code) => `<pre class="code-block"><code>${escapeHtml(code.trimEnd())}</code></pre>`)
    .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')
}

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']
function optionLetter(idx) { return LETTERS[idx] || String(idx + 1) }

function optionStyle(item, optId) {
  const isCorrect  = item.correctIds.includes(optId)
  const isSelected = item.selectedOptions.includes(optId)
  if (isCorrect)  return { background: '#D1FAE5', color: '#065F46' }
  if (isSelected) return { background: '#FEE2E2', color: '#991B1B' }
  return { background: '#F7F8FA', color: '#374151' }
}

function parseLineVal(s) {
  const t = s.trim()
  return t.startsWith('after:') ? t : parseInt(t)
}

function correctVals(item) {
  return item.correctAnswer?.split(',').map(parseLineVal) ?? []
}

function isCorrectLine(item, lineNum) {
  return correctVals(item).includes(lineNum)
}

// true if lineNum was selected AND is not a wrong answer
// (handles equivalence: selecting line N == after:N-1)
function isSelectedLine(item, lineNum) {
  const selected = item.selectedAnswer?.split(',').map(parseLineVal) ?? []
  if (!selected.includes(lineNum)) return false
  // check if this selection is equivalent to a correct answer
  const correct = correctVals(item)
  if (typeof lineNum === 'number') {
    // line N is equivalent to after:N-1
    if (correct.includes(`after:${lineNum - 1}`)) return false
  } else if (typeof lineNum === 'string' && lineNum.startsWith('after:')) {
    const n = parseInt(lineNum.replace('after:', ''))
    // after:N is equivalent to line N+1
    if (correct.includes(n + 1)) return false
  }
  return true
}

function optionLetterStyle(item, optId) {
  const isCorrect  = item.correctIds.includes(optId)
  const isSelected = item.selectedOptions.includes(optId)
  if (isCorrect)  return { background: '#10B981', color: '#fff', borderColor: '#10B981' }
  if (isSelected) return { background: '#EF4444', color: '#fff', borderColor: '#EF4444' }
  return { background: '#fff', color: '#9CA3AF', borderColor: '#E5E7EB' }
}
</script>

<style scoped>
.result-wrap {
  max-width: 42rem;
  margin: 0 auto;
}

.result-preview-note {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  margin-bottom: 1rem;
  border: 1px solid #FDE68A;
  border-radius: var(--rounded-box, 0.75rem);
  background: #FFFBEB;
}

.result-preview-note__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 1.25rem;
  height: 1.25rem;
  margin-top: 0.0625rem;
  border-radius: 50%;
  background: #F59E0B;
  color: #fff;
  font-size: 0.75rem;
  font-style: italic;
  font-weight: 700;
  font-family: Georgia, 'Times New Roman', serif;
  line-height: 1;
}

.result-preview-note__title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #92400E;
  margin-bottom: 0.125rem;
}

.result-preview-note__text {
  font-size: 0.8125rem;
  line-height: 1.45;
  color: #B45309;
}

.result-summary {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 2rem;
  margin-bottom: 1.5rem;
  text-align: center;
}

.result-summary__label {
  color: #6B7280;
  margin-bottom: 0.25rem;
}

.result-summary__mode-badge {
  display: inline-block;
  margin-left: 0.375rem;
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: #EEF0FF;
  color: #4F46E5;
  font-size: 0.7rem;
  font-weight: 600;
  vertical-align: middle;
}

.result-summary__score {
  font-size: 3.75rem;
  font-weight: 700;
  margin: 1rem 0;
}

.result-summary__correct {
  color: #4B5563;
  margin-bottom: 0.5rem;
}

.result-summary__time {
  font-size: 0.875rem;
  color: #9CA3AF;
}

.result-summary__actions {
  display: flex;
  justify-content: center;
  gap: 0.75rem;
  margin-top: 1.5rem;
}

.result-breakdown-title {
  font-weight: 600;
  font-size: 1.125rem;
  margin-bottom: 1rem;
}

/* Заголовок блока и кнопка тренировки по краям одной строки. */
.weak-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.weak-header .result-breakdown-title {
  margin-bottom: 0;
}

/* Обычная карточка страницы — как .result-item, чтобы блок не выбивался. */
.weak-topics {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}

.weak-topics__section {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #F3F4F6;
}

/* Заголовки второстепенных секций — мельче, чтобы список вопросов читался первым. */
.weak-topics__subtitle {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #6B7280;
  margin-bottom: 0.5rem;
}

.weak-topics__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

/* Насыщенность фона растёт с числом ошибок: серый — разовый промах,
   красный — тема, где ошиблись трижды и больше. */
.weak-topics__tag {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.1875rem 0.625rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #4B5563;
  font-size: 0.75rem;
  font-weight: 600;
}

.weak-topics__tag--none,
.weak-topics__tag--low {
  background: #F3F4F6;
  color: #4B5563;
}

.weak-topics__tag--medium {
  background: #FEF3C7;
  color: #92400E;
}

.weak-topics__tag--high {
  background: #FEE2E2;
  color: #991B1B;
}

/* Цвет темы из словаря — отдельный от градации признак. */
.weak-topics__tag-dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.weak-topics__tag-count {
  padding: 0 0.3125rem;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.65);
  font-size: 0.6875rem;
  font-weight: 700;
}

.weak-topics__tests {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.weak-topics__test-link {
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
  background: #fff;
  border: 1px solid #E5E7EB;
  color: #374151;
  font-size: 0.8125rem;
  font-weight: 500;
  text-decoration: none;
}

.weak-topics__test-link:hover {
  background: #F7F8FA;
  border-color: #4F63F5;
  color: #4F63F5;
}

.weak-topics__mistakes-list {
  list-style: disc;
  padding-left: 1.125rem;
  margin: 0;
  /* Маркер красим через цвет самого li, текст ссылки перекрывает его своим. */
  color: #D1D5DB;
}

.weak-topics__mistakes-list li {
  font-size: 0.8125rem;
  line-height: 1.5;
  margin-bottom: 0.3125rem;
}

.weak-topics__mistakes-list li:last-child {
  margin-bottom: 0;
}

.weak-topics__mistake-link {
  color: #374151;
  text-decoration: none;
  cursor: pointer;
}

.weak-topics__mistake-link:hover {
  color: #4F63F5;
  text-decoration: underline;
}

.weak-topics__mistake-count {
  margin-left: 0.375rem;
  color: #9CA3AF;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}

.result-item {
  background: #fff;
  border: 1px solid;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  margin-bottom: 0.75rem;
}

/* Короткая вспышка после перехода из списка ошибок — чтобы было видно, куда привели. */
.result-item--highlight {
  animation: result-item-flash 1.6s ease-out;
}

@keyframes result-item-flash {
  0%, 40% { box-shadow: 0 0 0 3px rgba(79, 99, 245, 0.35); }
  100%    { box-shadow: 0 1px 3px rgba(0,0,0,0.07); }
}

.result-item__header {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.result-item__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.125rem 0.4rem;
  border-radius: 999px;
  flex-shrink: 0;
  margin-top: 0.125rem;
}

.result-item__question {
  font-size: 0.875rem;
  font-weight: 500;
}

.result-item__options {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  font-size: 0.875rem;
  margin-bottom: 0.75rem;
}

.result-option {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
}

.result-option__body {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.result-option__explanation {
  font-size: 0.75rem;
  opacity: 0.75;
  font-style: italic;
}

.result-option__letter {
  flex-shrink: 0;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid;
  margin-top: 0.125rem;
}

.result-item__explanation {
  font-size: 0.75rem;
  color: #6B7280;
  border-top: 1px solid #F3F4F6;
  padding-top: 0.75rem;
  margin-top: 0.25rem;
}

:deep(.inline-code) {
  background: #F3F4F6;
  border-radius: 0.25rem;
  padding: 0.125rem 0.25rem;
  font-size: 0.875rem;
  font-family: monospace;
}

.result-item__details {
  margin-top: 0.5rem;
  border-top: 1px solid #F3F4F6;
  padding-top: 0.5rem;
}

.result-item__details-toggle {
  background: none;
  border: none;
  padding: 0;
  font-size: 0.75rem;
  color: #4F63F5;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.result-item__details-toggle:hover {
  text-decoration: underline;
}

.result-item__details-arrow {
  display: inline-block;
  transition: transform 0.2s;
  font-size: 0.875rem;
}

.result-item__details-arrow--open {
  transform: rotate(180deg);
}

.result-item__details-body {
  margin-top: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.result-item__extended {
  font-size: 0.8125rem;
  color: #374151;
  line-height: 1.6;
}

.result-item__recommendation {
  background: #F0F4FF;
  border-radius: 0.5rem;
  padding: 0.75rem;
  font-size: 0.8125rem;
  color: #374151;
  line-height: 1.6;
}

.result-item__recommendation-label {
  font-weight: 600;
  color: #4F63F5;
  margin-bottom: 0.375rem;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

:deep(.result-md-h4) {
  font-size: 0.8125rem;
  font-weight: 600;
  margin: 0.5rem 0 0.25rem;
  color: #1F2937;
}

:deep(.result-md-list) {
  margin: 0.25rem 0 0.25rem 1rem;
  padding: 0;
}

:deep(.result-link) {
  color: inherit;
  word-break: break-all;
  text-decoration: underline;
}

.result-code-challenge {
  margin-bottom: 0.75rem;
}

.result-code-block {
  background: #F3F4F6;
  border-radius: 0.75rem;
  padding: 0.875rem 1.25rem;
  margin: 0 0 0.5rem;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.8125rem;
  line-height: 1.7;
  color: #374151;
  overflow-x: auto;
  white-space: pre;
}

.result-code-block code {
  font-family: inherit;
}

.result-code-block--lines {
  padding: 0.5rem 0;
}

.result-code-block--lines code {
  display: block;
}

.result-code-line {
  display: block;
  padding: 0 1.25rem;
  min-height: 1.7em;
  border-left: 3px solid transparent;
  color: #374151;
}

.result-code-line--correct {
  background: rgba(16, 185, 129, 0.08);
  border-left-color: #10B981;
}

.result-code-line--selected {
  background: rgba(239, 68, 68, 0.08);
  border-left-color: #EF4444;
  color: #B91C1C;
}

.result-code-legend {
  display: flex;
  gap: 1rem;
  padding: 0.25rem 0;
  margin-top: 0.375rem;
  margin-bottom: 0.25rem;
}

.result-code-legend__item {
  font-size: 0.7rem;
  color: #6B7280;
  display: flex;
  align-items: center;
  gap: 0.3rem;
}

.result-code-legend__item::before {
  content: '';
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.result-code-legend__item--correct::before { background: #10B981; }
.result-code-legend__item--wrong::before   { background: #EF4444; }

.result-code-answers {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.result-code-answer {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
  border: 2px solid transparent;
  font-size: 0.875rem;
}

.result-code-answer--correct {
  background: #D1FAE5;
  color: #065F46;
}

.result-code-answer--wrong {
  background: #FEE2E2;
  color: #991B1B;
}

/* fix mode contains its own added/removed diff colors, so the answer
   wrapper is outlined instead of filled to avoid clashing backgrounds */
.result-code-answer--diff.result-code-answer--correct {
  background: transparent;
  border-color: #D1FAE5;
}

.result-code-answer--diff.result-code-answer--wrong {
  background: transparent;
  border-color: #FEE2E2;
}

.result-code-answer__label {
  font-weight: 500;
  flex-shrink: 0;
}

.result-code-answer__value {
  display: block;
  font-family: 'Fira Code', 'Cascadia Code', monospace;
  font-size: 0.875rem;
  white-space: pre;
  overflow-x: auto;
  color: #374151;
}

.result-code-answer__value--diff {
  display: flex;
  flex-direction: column;
}

.result-diff-line {
  display: block;
}

.result-diff-token--added {
  background: rgba(16, 185, 129, 0.25);
  border-radius: 0.2rem;
}

.result-diff-token--removed {
  background: rgba(239, 68, 68, 0.25);
  border-radius: 0.2rem;
}
</style>
