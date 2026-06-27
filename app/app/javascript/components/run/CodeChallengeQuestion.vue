<template>
  <div class="code-challenge">
    <div class="code-block-wrap">
      <pre class="code-block"><code><template
        v-for="(part, i) in codeParts"
        :key="i"
      ><template v-if="part.type === 'text'">{{ part.value }}</template><span
          v-else
          class="code-blank-wrap"
        ><input
            ref="inputEl"
            v-model="localAnswer"
            type="text"
            class="code-blank"
            placeholder="___"
            spellcheck="false"
            autocomplete="off"
            @input="onInput"
            @keydown.enter.prevent="$emit('submit-enter')"
          /></span></template></code></pre>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch, nextTick, onMounted } from 'vue'

const props = defineProps({
  question: Object,
  answers:  Object,
})

const emit = defineEmits(['submit-enter'])

const localAnswer = computed({
  get: () => props.answers[props.question.id] ?? '',
  set: val => { props.answers[props.question.id] = val },
})

const inputEl = ref(null)

onMounted(() => {
  nextTick(() => {
    const el = Array.isArray(inputEl.value) ? inputEl.value[0] : inputEl.value
    el?.focus()
  })
})

function onInput() {}

const codeParts = computed(() => {
  const code = props.question.code ?? ''
  const parts = []
  const segments = code.split('___')
  segments.forEach((seg, i) => {
    if (seg) parts.push({ type: 'text', value: seg })
    if (i < segments.length - 1) parts.push({ type: 'blank' })
  })
  return parts
})
</script>

<style scoped>
.code-challenge {
  margin-bottom: 0.5rem;
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
  width: max(8ch, calc(v-bind('localAnswer.length') * 1ch + 2ch));
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
</style>
