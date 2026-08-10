export const CHALLENGE_MODE_ORDER = ['highlight', 'select', 'fill', 'fix']

export const CHALLENGE_MODE_LABELS = {
  highlight: 'Highlight',
  select:    'Select',
  fill:      'Fill',
  fix:       'Fix',
}

export const CHALLENGE_MODE_HINTS = {
  highlight: 'Кликни на проблемную строку или добавь недостающую',
  select:    'Выбери правильный вариант',
  fill:      'Введи пропущенный код вместо ___',
  fix:       'Отредактируй и исправь баг',
}

// fix stays gated behind the other three modes, mirroring SettingsPanel's gating
const GATED_PREREQUISITES = ['highlight', 'select', 'fill']

export function isChallengeModeUnlocked(mode, completedChallengeModes) {
  if (mode !== 'fix') return true
  return GATED_PREREQUISITES.every(m => completedChallengeModes.includes(m))
}

// First mode in the fixed order that hasn't been completed yet and isn't
// gated behind other modes; null once everything is done (or unlocked left).
export function nextChallengeMode(completedChallengeModes) {
  return CHALLENGE_MODE_ORDER.find(mode =>
    !completedChallengeModes.includes(mode) && isChallengeModeUnlocked(mode, completedChallengeModes)
  ) || null
}
