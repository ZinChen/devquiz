<template>
  <div class="code-challenge">

    <!-- ── highlight mode ─────────────────────────────────────────── -->
    <template v-if="mode === 'highlight'">
      <p class="code-challenge__hint">{{ modeData.hint || 'Кликни на проблемную строку' }}</p>
      <div class="code-block-wrap code-block-wrap--lines">
        <div
          v-for="(line, i) in highlightLines"
          :key="i"
          class="code-line"
          :class="{ 'code-line--selected': selectedLines.includes(i + 1) }"
          @click="toggleLine(i + 1)"
        ><code>{{ line || ' ' }}</code></div>
      </div>
    </template>

    <!-- ── fill mode ──────────────────────────────────────────────── -->
    <template v-else-if="mode === 'fill'">
      <div class="code-block-wrap">
        <pre class="code-block"><code><template
            v-for="(part, i) in fillParts"
            :key="i"
          ><template v-if="part.type === 'text'">{{ part.value }}</template><span
              v-else
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
              /></span></template></code></pre>
      </div>
    </template>

    <!-- ── fix mode ───────────────────────────────────────────────── -->
    <template v-else-if="mode === 'fix'">
      <p class="code-challenge__hint">Исправь код ниже</p>
      <div class="code-block-wrap code-block-wrap--fix">
        <textarea
          ref="fixTextareaEl"
          v-model="fixAnswer"
          class="code-textarea"
          spellcheck="false"
          autocomplete="off"
          autocorrect="off"
        />
      </div>
    </template>

  </div>
</template>

<script setup>
import { computed, ref, watch, nextTick, onMounted } from 'vue'

const props = defineProps({
  question: Object,
  answers:  Object,
  mode:     { type: String, default: 'highlight' },
})

const emit = defineEmits(['submit-enter'])

const modeData = computed(() => props.question.modes?.[props.mode] ?? {})

// ── highlight ────────────────────────────────────────────────────────
const highlightLines = computed(() =>
  (modeData.value.code ?? '').trimEnd().split('\n')
)

const selectedLines = computed(() => {
  const val = props.answers[props.question.id]
  if (!Array.isArray(val)) return []
  return val
})

function toggleLine(lineNum) {
  const current = Array.isArray(props.answers[props.question.id])
    ? [...props.answers[props.question.id]]
    : []
  const idx = current.indexOf(lineNum)
  if (idx === -1) current.push(lineNum)
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

const fillParts = computed(() => {
  const code = modeData.value.code ?? ''
  const parts = []
  code.split('___').forEach((seg, i, arr) => {
    if (seg) parts.push({ type: 'text', value: seg })
    if (i < arr.length - 1) parts.push({ type: 'blank' })
  })
  return parts
})

// ── fix ──────────────────────────────────────────────────────────────
const fixTextareaEl = ref(null)

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
      el?.focus()
    } else if (props.mode === 'fix') {
      fixTextareaEl.value?.focus()
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
  margin-bottom: 0.375rem;
}

.code-block-wrap {
  background: #1E1E2E;
  border-radius: 0.75rem;
  overflow: hidden;
}

.code-block {
  margin: 0;
  padding: 1rem 1.25rem;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.8125rem;
  line-height: 1.7;
  color: #CDD6F4;
  overflow-x: auto;
  white-space: pre;
}

.code-block code {
  font-family: inherit;
}

/* highlight mode */
.code-block-wrap--lines {
  padding: 0.5rem 0;
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
  color: #CDD6F4;
  white-space: pre;
}

.code-line code {
  font-family: inherit;
  font-size: inherit;
  background: none;
  color: inherit;
}

.code-line:hover {
  background: rgba(137, 180, 250, 0.08);
}

.code-line--selected {
  background: rgba(249, 226, 175, 0.15);
  border-left-color: #F9E2AF;
  color: #F9E2AF;
}

/* fill mode */
.code-blank-wrap {
  display: inline;
}

.code-blank {
  background: #313244;
  border: 1px solid #89B4FA;
  border-radius: 4px;
  color: #89DCEB;
  font-family: inherit;
  font-size: inherit;
  line-height: inherit;
  padding: 0 0.4rem;
  min-width: 8ch;
  width: max(8ch, calc(v-bind('fillAnswer.length') * 1ch + 2ch));
  outline: none;
  vertical-align: baseline;
  transition: border-color 0.15s, background 0.15s;
}

.code-blank:focus {
  border-color: #89DCEB;
  background: #1E2030;
  box-shadow: 0 0 0 2px rgba(137, 220, 235, 0.15);
}

.code-blank::placeholder {
  color: #6C7086;
}

/* fix mode */
.code-block-wrap--fix {
  padding: 0;
}

.code-textarea {
  display: block;
  width: 100%;
  min-height: 14rem;
  background: #1E1E2E;
  color: #CDD6F4;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.8125rem;
  line-height: 1.7;
  padding: 1rem 1.25rem;
  border: none;
  outline: none;
  resize: vertical;
  border-radius: 0.75rem;
  white-space: pre;
  overflow-wrap: normal;
  overflow-x: auto;
  caret-color: #89DCEB;
}
</style>
