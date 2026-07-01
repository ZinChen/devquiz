<template>
  <div ref="containerEl" class="codemirror-wrap"></div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { EditorView, minimalSetup } from 'codemirror'
import { EditorState } from '@codemirror/state'
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language'
import { tags } from '@lezer/highlight'
import { loadLang } from '@/composables/useCodeMirrorLang.js'

const props = defineProps({
  modelValue: { type: String, default: '' },
  lang:       { type: String, default: 'ruby' },
})

const emit = defineEmits(['update:modelValue'])

const containerEl = ref(null)
let view = null

const githubLight = HighlightStyle.define([
  // keywords: def, class, end, do, if, unless, ...
  { tag: tags.keyword,                       color: '#D73A49' },
  { tag: tags.controlKeyword,                color: '#D73A49' },
  { tag: tags.definitionKeyword,             color: '#D73A49' },
  { tag: tags.moduleKeyword,                 color: '#D73A49' },
  { tag: tags.operatorKeyword,               color: '#D73A49' },
  // atoms: true, false, nil, self, symbols
  { tag: tags.atom,                          color: '#005CC5' },
  { tag: tags.bool,                          color: '#005CC5' },
  { tag: tags.null,                          color: '#005CC5' },
  { tag: tags.self,                          color: '#005CC5' },
  { tag: tags.constant(tags.variableName),   color: '#005CC5' },
  // strings
  { tag: tags.string,                        color: '#032F62' },
  { tag: tags.special(tags.string),          color: '#032F62' },
  // comments
  { tag: tags.comment,                       color: '#6A737D', fontStyle: 'italic' },
  // numbers
  { tag: tags.number,                        color: '#005CC5' },
  // identifiers
  { tag: tags.variableName,                  color: '#24292E' },
  { tag: tags.definition(tags.variableName), color: '#6F42C1' },
  { tag: tags.standard(tags.variableName),   color: '#005CC5' },
  { tag: tags.function(tags.variableName),   color: '#6F42C1' },
  { tag: tags.function(tags.propertyName),   color: '#6F42C1' },
  { tag: tags.propertyName,                  color: '#005CC5' },
  { tag: tags.typeName,                      color: '#6F42C1' },
  { tag: tags.className,                     color: '#6F42C1' },
  { tag: tags.namespace,                     color: '#6F42C1' },
  // operators & punctuation
  { tag: tags.operator,                      color: '#D73A49' },
  { tag: tags.punctuation,                   color: '#24292E' },
  { tag: tags.separator,                     color: '#24292E' },
  // regexp
  { tag: tags.regexp,                        color: '#032F62' },
])

const baseTheme = EditorView.theme({
  '&': {
    fontSize: '0.8125rem',
    fontFamily: "'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace",
    background: '#F3F4F6',
    borderRadius: '0.75rem',
  },
  '.cm-content': {
    padding: '1rem 1.25rem',
    caretColor: '#6366F1',
    minHeight: '14rem',
  },
  '.cm-line': { padding: '0' },
  '.cm-focused': { outline: 'none' },
  '.cm-scroller': { overflow: 'auto', lineHeight: '1.7' },
  '.cm-gutters': { display: 'none' },
  '.cm-cursor': { borderLeftColor: '#6366F1' },
  '&.cm-focused .cm-selectionBackground, .cm-selectionBackground': {
    background: 'rgba(99,102,241,0.15)',
  },
})

async function createView() {
  const langSupport = await loadLang(props.lang)

  const extensions = [
    minimalSetup,
    baseTheme,
    syntaxHighlighting(githubLight),
    EditorView.updateListener.of(update => {
      if (update.docChanged) {
        emit('update:modelValue', update.state.doc.toString())
      }
    }),
  ]

  if (langSupport) extensions.push(langSupport)

  view = new EditorView({
    parent: containerEl.value,
    state: EditorState.create({
      doc: props.modelValue,
      extensions,
    }),
  })
}

onMounted(createView)

onUnmounted(() => view?.destroy())

watch(() => props.modelValue, val => {
  if (!view) return
  const current = view.state.doc.toString()
  if (current !== val) {
    view.dispatch({
      changes: { from: 0, to: current.length, insert: val },
    })
  }
})
</script>

<style scoped>
.codemirror-wrap {
  border-radius: 0.75rem;
  overflow: auto;
}
</style>
