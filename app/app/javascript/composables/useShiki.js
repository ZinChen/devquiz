import { ref, shallowRef } from 'vue'
import { createHighlighter } from 'shiki'

const highlighter = shallowRef(null)
let initPromise = null

const SUPPORTED_LANGS = ['ruby', 'sql', 'javascript', 'typescript', 'python', 'bash', 'json', 'yaml']
const THEME = 'github-light'

export function useShiki() {
  const ready = ref(!!highlighter.value)

  function init() {
    if (initPromise) return initPromise
    initPromise = createHighlighter({ themes: [THEME], langs: SUPPORTED_LANGS }).then(h => {
      highlighter.value = h
      ready.value = true
    })
    return initPromise
  }

  function tokenize(code, lang = 'ruby') {
    if (!highlighter.value) return null
    const safeCode = code.endsWith('\n') ? code.slice(0, -1) : code
    try {
      const result = highlighter.value.codeToTokens(safeCode, { lang, theme: THEME })
      return result.tokens
    } catch {
      return null
    }
  }

  return { ready, init, tokenize }
}
