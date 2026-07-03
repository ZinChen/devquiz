import { languages } from '@codemirror/language-data'

const cache = {}

export async function loadLang(lang) {
  const key = lang.toLowerCase()
  if (cache[key]) return cache[key]
  const desc = languages.find(l => l.name.toLowerCase() === key)
  if (!desc) return null
  cache[key] = await desc.load()
  return cache[key]
}

export function preloadLang(lang) {
  loadLang(lang)
}
