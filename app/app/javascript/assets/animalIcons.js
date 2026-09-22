// Иконки животных для генерируемого аватара (GeneratedAvatar.vue).
//
// Источники:
// - game-icons.net (CC BY 3.0 — lorc, delapouite, caro-asercion, darkzaitzev,
//   skoll — https://game-icons.net), единый viewBox 512x512;
// - svgrepo.com (свободные для использования иконки разных авторов,
//   некоммерческий проект), viewBox у каждой свой.
//
// Каждый файл в ./animals/*.svg — самостоятельная, открываемая как обычная
// картинка иконка. Несколько файлов на одно животное (суффикс -1/-2/...)
// хранят разные варианты — при рендере выбирается случайный (см.
// GeneratedAvatar.vue), чтобы одинаковые имена не выглядели идентично.
// Соответствие «животное → файлы» лежит в animals-index.json, а не
// выводится из имён файлов (транслитерация необратима).
//
// Одноцветные иконки красятся через currentColor. Часть иконок svgrepo —
// многослойные (контур+глаза и т.п., несколько исходных цветов) — они
// хранятся как есть, с оригинальной раскраской; чтобы их можно было
// частично подстроить под палитру аватара, заливка контура в части таких
// файлов задана через CSS-переменную --fill-bg (см. animalIcon.hasFillBg).
import animalsIndex from './animals-index.json'

const svgModules = import.meta.glob('./animals/*.svg', {
  eager: true,
  query: '?raw',
  import: 'default',
})

function parseSvg(raw) {
  const viewBoxMatch = raw.match(/viewBox="([^"]*)"/)
  const innerMatch = raw.match(/<svg[^>]*>([\s\S]*)<\/svg>/)
  return {
    viewBox: viewBoxMatch ? viewBoxMatch[1] : '0 0 512 512',
    markup: innerMatch ? innerMatch[1].trim() : '',
    hasFillBg: raw.includes('--fill-bg'),
  }
}

export const ANIMAL_ICON_VARIANTS = Object.fromEntries(
  Object.entries(animalsIndex).map(([name, files]) => [
    name,
    files.map(file => parseSvg(svgModules[`./animals/${file}`])),
  ])
)

// Ищет животное из ANIMAL_ICON_VARIANTS внутри произвольного текста (имени
// пользователя) — подстрока, без учёта регистра, побеждает самое длинное
// совпадение, чтобы не путать составные названия. Возвращает русское имя
// животного или null, если совпадения нет.
export function detectAnimal(text) {
  const lower = (text || '').toLowerCase()
  if (!lower) return null

  let bestMatch = null
  for (const animal of Object.keys(ANIMAL_ICON_VARIANTS)) {
    if (lower.includes(animal.toLowerCase())) {
      if (!bestMatch || animal.length > bestMatch.length) bestMatch = animal
    }
  }
  return bestMatch
}
