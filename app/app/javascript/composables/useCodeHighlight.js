import { reactive } from 'vue'
import { useShiki } from '@/composables/useShiki.js'

// Подсветка ```lang code``` блоков внутри произвольного текста (вопрос,
// объяснение, вариант ответа) через Shiki. Подсветка асинхронна, а places,
// где вызывается formatText, рендерят её синхронно через v-html — поэтому
// здесь кэш text → html: при первом вызове возвращается неподсвеченный
// текст (как раньше), а когда Shiki досчитает, кэш заполняется и Vue
// перерисовывает v-html по реактивности.
const htmlCache = reactive({})
const { ready, init, highlightHtml } = useShiki()

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

// Раскладывает текст на обычные куски и код-блоки, экранирует обычный текст
// и инлайн-код сразу, а код-блоки временно заменяет плейсхолдером —
// его в конце подменяют либо на подсвеченный Shiki HTML, либо (пока не
// готово / язык не распознан) на прежний markup без подсветки.
function splitCodeBlocks(text) {
  const blocks = []
  const withPlaceholders = text.replace(/```([^\n]*)\n?([\s\S]*?)```/g, (_, lang, code) => {
    blocks.push({ lang: lang.trim().toLowerCase() || 'sql', code: code.trimEnd() })
    return `@@CODE_BLOCK_${blocks.length - 1}@@`
  })
  return { withPlaceholders, blocks }
}

function fallbackBlockHtml(block) {
  return `<pre class="code-block"><code>${escapeHtml(block.code)}</code></pre>`
}

// Возвращает HTML для одного код-блока: из кэша, если Shiki уже посчитал
// его раньше, иначе считает и кладёт в кэш (когда Shiki готов), иначе —
// неподсвеченный fallback на этот рендер.
function resolveCodeBlockHtml(block) {
  const key = `${block.lang}::${block.code}`
  if (htmlCache[key]) return htmlCache[key]
  if (ready.value) {
    htmlCache[key] = highlightHtml(block.code, block.lang) || fallbackBlockHtml(block)
    return htmlCache[key]
  }
  init()
  return fallbackBlockHtml(block)
}

function renderWithCache(text) {
  if (!text) return ''
  const { withPlaceholders, blocks } = splitCodeBlocks(text)

  const formatted = withPlaceholders
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')

  if (!blocks.length) return formatted

  return formatted.replace(/@@CODE_BLOCK_(\d+)@@/g, (_, i) => resolveCodeBlockHtml(blocks[Number(i)]))
}

export function useCodeHighlight() {
  init()

  function formatText(text) {
    return renderWithCache(text)
  }

  return { formatText, ready, splitCodeBlocks, resolveCodeBlockHtml }
}
