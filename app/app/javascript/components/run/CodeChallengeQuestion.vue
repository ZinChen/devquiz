<template>
  <div class="code-challenge">

    <!-- ── highlight mode ─────────────────────────────────────────── -->
    <template v-if="mode === 'highlight'">
      <div
        ref="linesWrapRef"
        class="code-block-inner-wrap code-block-inner-wrap--lines"
        @mousemove="onLinesMouseMove"
        @mouseleave="if (!keepGap) hoveredGap = null"
      >
        <div
          v-for="(line, i) in highlightLines"
          :key="i"
          class="code-line"
          :class="{
            'code-line--selected': selectedLines.includes(i + 1),
            'code-line--gap-selected-before': selectedLines.includes(`after:${i}`),
            'code-line--gap-selected-after':  selectedLines.includes(`after:${i + 1}`),
          }"
          @click="onLineClick(i, $event)"
        >
          <code>
            <template v-if="tokenizedHighlight">
              <span
                v-for="(tok, ti) in (tokenizedHighlight[i] || [])"
                :key="ti"
                :style="tok.color ? { color: tok.color } : {}"
              >{{ tok.content }}</span>
            </template>
            <template v-else>{{ line || ' ' }}</template>
          </code>
        </div>

        <!-- floating + button, shown on hover near a gap -->
        <button
          v-if="hoveredGap !== null"
          class="gap-insert-btn"
          :class="{ 'gap-insert-btn--selected': selectedLines.includes(`after:${hoveredGap}`) }"
          :style="{ top: `${gapBtnTop}px` }"
          @click.stop="toggleLine(`after:${hoveredGap}`)"
          @mouseenter="keepGap = true"
          @mouseleave="keepGap = false; hoveredGap = null"
        >+</button>
      </div>
      <p v-if="hintVisible" class="code-challenge__hint">{{ modeData.hint || 'Кликни на проблемную строку' }}</p>
      <button v-else class="code-challenge__hint-btn" @click="showHint">Показать подсказку</button>
    </template>

    <!-- ── fill mode ──────────────────────────────────────────────── -->
    <template v-else-if="mode === 'fill'">
      <div class="code-block-inner-wrap">
        <pre class="code-block-inner"><code><template
            v-for="(line, li) in fillTokenLines"
            :key="li"
          ><template v-if="li > 0">{{ '\n' }}</template><template
              v-for="(tok, ti) in line"
              :key="ti"
            ><span
                v-if="tok.type === 'blank'"
                class="code-blank-wrap"
              ><input
                  ref="fillInputEl"
                  v-model="fillAnswer"
                  type="text"
                  class="code-blank"
                  placeholder="___"
                  spellcheck="false"
                  autocomplete="off"
                  @keydown.enter.prevent="$emit('submit-enter')"
                /></span><span
                v-else
                :style="tok.color ? { color: tok.color } : {}"
              >{{ tok.content }}</span></template></template></code></pre>
      </div>
    </template>

    <!-- ── fix mode ───────────────────────────────────────────────── -->
    <template v-else-if="mode === 'fix'">
      <p class="code-challenge__hint">Исправь код ниже</p>
      <CodeMirrorEditor
        v-model="fixAnswer"
        :lang="lang"
      />
    </template>

  </div>
</template>

<script setup>
import { computed, ref, watch, nextTick, onMounted } from 'vue'
import { useShiki } from '@/composables/useShiki.js'
import { preloadLang } from '@/composables/useCodeMirrorLang.js'
import CodeMirrorEditor from '@/components/run/CodeMirrorEditor.vue'

const props = defineProps({
  question:  Object,
  answers:   Object,
  mode:      { type: String, default: 'highlight' },
  hintShown: { type: Boolean, default: false },
})

const emit = defineEmits(['submit-enter', 'hint-used'])

const hintVisible = ref(props.hintShown)

watch(() => props.hintShown, val => { hintVisible.value = val })
watch(() => props.question?.id, () => { hintVisible.value = props.hintShown })

function showHint() {
  hintVisible.value = true
  emit('hint-used', props.question.id)
}

// ── gap hover state ──────────────────────────────────────────────────────────
const linesWrapRef = ref(null)
const hoveredGap   = ref(null)  // null | number (after:N index)
const gapBtnTop    = ref(0)
const keepGap      = ref(false)

function onLinesMouseMove(e) {
  if (keepGap.value) return
  const wrap = linesWrapRef.value
  if (!wrap) return

  const lineEls = wrap.querySelectorAll('.code-line')
  for (let i = 0; i < lineEls.length; i++) {
    const rect = lineEls[i].getBoundingClientRect()
    const wrapRect = wrap.getBoundingClientRect()
    const relY = e.clientY - rect.top
    const half = rect.height / 2

    if (e.clientY >= rect.top && e.clientY <= rect.bottom) {
      const gapIndex = relY < half ? i : i + 1
      hoveredGap.value = gapIndex
      // position button at the boundary
      const boundaryY = relY < half ? rect.top : rect.bottom
      gapBtnTop.value = boundaryY - wrapRect.top - 11  // 11 = half button height
      return
    }
  }
  hoveredGap.value = null
}

function onLineClick(i, e) {
  const el   = e.currentTarget
  const relY = e.clientY - el.getBoundingClientRect().top
  const half = el.getBoundingClientRect().height / 2
  if (relY < half * 0.25 || relY > half * 1.75) {
    // near boundary — handled by gap button
    return
  }
  toggleLine(i + 1)
}

const { ready, init, tokenize } = useShiki()

const modeData = computed(() => props.question.modes?.[props.mode] ?? {})
const lang     = computed(() => props.question.language || 'ruby')

onMounted(() => {
  init()
  preloadLang(lang.value)
})

// ── highlight ────────────────────────────────────────────────────────
const highlightLines = computed(() =>
  (modeData.value.code ?? '').trimEnd().split('\n')
)

const tokenizedHighlight = computed(() => {
  if (!ready.value) return null
  return tokenize(modeData.value.code ?? '', lang.value)
})

const selectedLines = computed(() => {
  const val = props.answers[props.question.id]
  if (!Array.isArray(val)) return []
  return val
})

function toggleLine(lineVal) {
  const current = Array.isArray(props.answers[props.question.id])
    ? [...props.answers[props.question.id]]
    : []
  const idx = current.indexOf(lineVal)
  if (idx === -1) current.push(lineVal)
  else current.splice(idx, 1)
  props.answers[props.question.id] = current
}

// ── fill ─────────────────────────────────────────────────────────────
const fillInputEl = ref(null)

const fillAnswer = computed({
  get: () => typeof props.answers[props.question.id] === 'string'
    ? props.answers[props.question.id]
    : '',
  set: val => { props.answers[props.question.id] = val },
})

const fillTokenLines = computed(() => {
  const code = modeData.value.code ?? ''
  const tokens = ready.value ? tokenize(code, lang.value) : null

  if (!tokens) {
    // fallback без подсветки
    const lines = code.split('\n')
    return lines.map(line => {
      const parts = line.split('___')
      const result = []
      parts.forEach((seg, i, arr) => {
        if (seg) result.push({ type: 'text', content: seg })
        if (i < arr.length - 1) result.push({ type: 'blank' })
      })
      return result
    })
  }

  // разбиваем токены по ___ на каждой строке
  return tokens.map(lineTokens => {
    const result = []
    for (const tok of lineTokens) {
      if (tok.content === '___') {
        result.push({ type: 'blank' })
      } else if (tok.content.includes('___')) {
        // ___ внутри токена (редко, но возможно)
        const parts = tok.content.split('___')
        parts.forEach((seg, i, arr) => {
          if (seg) result.push({ type: 'text', content: seg, color: tok.color })
          if (i < arr.length - 1) result.push({ type: 'blank' })
        })
      } else {
        result.push({ type: 'text', content: tok.content, color: tok.color })
      }
    }
    return result
  })
})

// ── fix ──────────────────────────────────────────────────────────────
const fixAnswer = computed({
  get: () => typeof props.answers[props.question.id] === 'string'
    ? props.answers[props.question.id]
    : (modeData.value.code ?? ''),
  set: val => { props.answers[props.question.id] = val },
})

// ── auto-focus on mount and mode change ──────────────────────────────
function focusActive() {
  nextTick(() => {
    if (props.mode === 'fill') {
      const el = Array.isArray(fillInputEl.value) ? fillInputEl.value[0] : fillInputEl.value
      el?.focus({ preventScroll: true })
    }
  })
}

onMounted(focusActive)
watch(() => props.mode, focusActive)
</script>

<style scoped>
.code-challenge {
  margin-bottom: 0.5rem;
}

.code-challenge__hint {
  font-size: 0.75rem;
  color: #9CA3AF;
  margin: 0.375rem 0 0;
}

.code-challenge__hint-btn {
  display: block;
  margin-top: 0.375rem;
  font-size: 0.75rem;
  color: #9CA3AF;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  text-decoration: none;
}

.code-challenge__hint-btn:hover {
  color: #6B7280;
}

.code-block-inner-wrap {
  background: #F3F4F6;
  border-radius: 0.75rem;
  overflow: hidden;
}

.code-block-inner {
  margin: 0;
  padding: 1rem 1.25rem;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.8125rem;
  line-height: 1.7;
  color: #374151;
  overflow-x: auto;
  white-space: pre;
}

.code-block-inner code {
  font-family: inherit;
}

/* highlight mode */
.code-block-inner-wrap--lines {
  padding: 0.5rem 0;
  position: relative;
}

.gap-insert-btn {
  position: absolute;
  left: 0.5rem;
  width: 22px;
  height: 22px;
  background: #fff;
  border: 1px solid #D1D5DB;
  border-radius: 6px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.12);
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
  color: #6B7280;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  z-index: 10;
  transition: background 0.1s, color 0.1s, border-color 0.1s;
  user-select: none;
}

.gap-insert-btn:hover {
  background: #F0F4FF;
  border-color: #4F63F5;
  color: #4F63F5;
}

.gap-insert-btn--selected {
  background: #ECFDF5;
  border-color: #10B981;
  color: #10B981;
}

.code-line--gap-selected-before {
  border-top: 2px solid #10B981;
}

.code-line--gap-selected-after {
  border-bottom: 2px solid #10B981;
}

.code-line {
  display: block;
  padding: 0 1.25rem;
  cursor: pointer;
  border-left: 3px solid transparent;
  transition: background 0.1s, border-color 0.1s;
  user-select: none;
  min-height: 1.7em;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.8125rem;
  line-height: 1.7;
  color: #374151;
  white-space: pre;
}

.code-line code {
  font-family: inherit;
  font-size: inherit;
  background: none;
  color: inherit;
}

.code-line:hover {
  background: rgba(0, 0, 0, 0.04);
}

.code-line--selected {
  background: rgba(239, 68, 68, 0.08);
  border-left-color: #EF4444;
}

.code-line--selected code span {
  color: #B91C1C !important;
}

/* fill mode */
.code-blank-wrap {
  display: inline;
}

.code-blank {
  background: #fff;
  border: 1px solid #D1D5DB;
  border-radius: 4px;
  color: #374151;
  font-family: inherit;
  font-size: inherit;
  line-height: inherit;
  padding: 0 0.4rem;
  min-width: 8ch;
  width: max(8ch, calc(v-bind('fillAnswer.length') * 1ch + 2ch));
  outline: none;
  vertical-align: baseline;
  transition: border-color 0.15s, box-shadow 0.15s;
}

.code-blank:focus {
  border-color: #6366F1;
  box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.15);
}

.code-blank::placeholder {
  color: #9CA3AF;
}


</style>
