import { ref, shallowRef } from 'vue'
import { createHighlighter } from 'shiki'

const highlighter = shallowRef(null)
const ready = ref(false)
let initPromise = null

const SUPPORTED_LANGS = ['ruby', 'sql', 'javascript', 'typescript', 'python', 'bash', 'json', 'yaml', 'go', 'ini', 'nginx']
const THEME = 'github-light'

export function useShiki() {
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

  // Готовая HTML-строка с подсветкой — для мест, где код рендерится через
  // v-html одним куском (formatText), а не построчно с кликами по строкам,
  // как в code_challenge.
  function highlightHtml(code, lang = 'sql') {
    if (!highlighter.value) return null
    const safeLang = SUPPORTED_LANGS.includes(lang) ? lang : 'sql'
    try {
      const html = highlighter.value.codeToHtml(code, { lang: safeLang, theme: THEME })
      // Shiki ставит свой класс "shiki" и инлайновый цвет фона от темы —
      // добавляем наш code-block, чтобы унаследовать общий вид блока кода
      // (рамка, паддинг, фон приложения) через существующий CSS-класс.
      return html.replace('<pre class="shiki', '<pre class="code-block shiki')
    } catch {
      return null
    }
  }

  return { ready, init, tokenize, highlightHtml }
}
