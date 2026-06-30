<template>
  <AppLayout>
    <div class="result-wrap">
      <div class="result-summary">
        <p class="result-summary__label">Тест завершён: {{ test.title }}</p>
        <div class="result-summary__score" :style="{ color: scoreColor }">
          {{ attempt.score.toFixed(0) }}%
        </div>
        <p class="result-summary__correct">
          {{ attempt.correctCount }} правильных из {{ attempt.totalQuestions }}
        </p>
        <p class="result-summary__time">Время: {{ formatTime(attempt.timeSpent) }}</p>

        <div class="result-summary__actions">
          <Link :href="`/tests/${test.slug}/run/new`" class="btn btn-primary">
            Пройти снова
          </Link>
          <Link href="/" class="btn btn-ghost">Все тесты</Link>
        </div>
      </div>

      <h2 class="result-breakdown-title">Разбор ответов</h2>

      <div
        v-for="(item, idx) in answersDetail" :key="item.questionId"
        class="result-item"
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
          <!-- fill / fix: show typed answer vs correct -->
          <template v-else>
            <pre v-if="item.challengeMode === 'fix'" class="result-code-block"><code>{{ item.code }}</code></pre>
            <div class="result-code-answers">
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
import { computed, reactive, onMounted } from 'vue'
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import { useShiki } from '@/composables/useShiki.js'

const props = defineProps({
  test:           Object,
  attempt:        Object,
  answersDetail:  Array,
})

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
    .replace(/\n\n/g, '</p><p>')
    .replace(/^(?!<[hul])(.+)$/gm, (m) => m.startsWith('<') ? m : m)
    .replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" target="_blank" rel="noopener" class="result-link">$1</a>')
}

const scoreColor = computed(() => {
  if (props.attempt.score >= 80) return '#10B981'
  if (props.attempt.score >= 50) return '#F59E0B'
  return '#EF4444'
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

.result-item {
  background: #fff;
  border: 1px solid;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  margin-bottom: 0.75rem;
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
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
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

.result-code-answer__label {
  font-weight: 500;
  flex-shrink: 0;
}

.result-code-answer__value {
  font-family: 'Fira Code', 'Cascadia Code', monospace;
  font-size: 0.875rem;
}
</style>
