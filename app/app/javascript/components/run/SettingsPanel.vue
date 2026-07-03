<template>
  <div class="settings-panel">
    <h3 class="settings-panel__title">Настройки прохождения</h3>

    <div class="settings-panel__options">
      <label class="settings-option">
        <input type="radio" :checked="mode === 'all'" @change="$emit('update:mode', 'all')" class="radio radio-sm" />
        <div>
          <p class="settings-option__label">Все вопросы списком</p>
          <p class="settings-option__hint">Листай и решай</p>
        </div>
      </label>
      <label class="settings-option">
        <input type="radio" :checked="mode === 'one'" @change="$emit('update:mode', 'one')" class="radio radio-sm" />
        <div>
          <p class="settings-option__label">По одному вопросу</p>
          <p class="settings-option__hint">Фокус на одном вопросе</p>
        </div>
      </label>
    </div>

    <template v-if="hasCodeChallenge">
      <div class="settings-panel__divider"></div>
      <h3 class="settings-panel__title">Режим кодовых задач</h3>
      <div class="challenge-toggle-wrap">
        <div class="challenge-toggle-labels">
          <span
            v-for="opt in challengeModeOptions" :key="opt.value"
            class="challenge-toggle-label"
            :class="{ 'challenge-toggle-label--active': challengeMode === opt.value }"
          >{{ opt.label }}</span>
        </div>
        <div class="challenge-toggle" :class="{ 'challenge-toggle--locked': locked }">
          <div
            class="challenge-toggle__thumb"
            :style="{ transform: `translateX(${activeIndex * 100}%)` }"
          ></div>
          <button
            v-for="opt in challengeModeOptions" :key="opt.value"
            type="button"
            class="challenge-toggle__btn"
            :class="{ 'challenge-toggle__btn--active': challengeMode === opt.value }"
            @click="!locked && $emit('update:challengeMode', opt.value)"
            :title="locked ? 'Нельзя менять после начала теста' : opt.hint"
          ></button>
        </div>
      </div>
      <div class="challenge-toggle__footer">
        <p v-if="locked" class="challenge-toggle__locked-hint">Тест уже начат</p>
        <button
          v-if="locked"
          type="button"
          class="challenge-toggle__reset-btn"
          @click="$emit('reset')"
        >Сброс</button>
      </div>
    </template>
  </div>
</template>

<script setup>
const props = defineProps({
  mode:             String,
  challengeMode:    { type: String, default: 'highlight' },
  hasCodeChallenge: { type: Boolean, default: false },
  locked:           { type: Boolean, default: false },
})

defineEmits(['update:mode', 'update:challengeMode', 'reset'])

const challengeModeOptions = [
  { value: 'highlight', icon: '🔍', label: 'Highlight', hint: 'Кликни на проблемную строку' },
  { value: 'fill',      icon: '✏️', label: 'Fill',      hint: 'Введи пропущенный код вместо ___' },
  { value: 'fix',       icon: '🔧', label: 'Fix',       hint: 'Отредактируй и исправь баг' },
]

import { computed } from 'vue'
const currentChallengeHint = computed(
  () => challengeModeOptions.find(o => o.value === props.challengeMode)?.hint ?? ''
)
const activeIndex = computed(
  () => challengeModeOptions.findIndex(o => o.value === props.challengeMode)
)
</script>

<style scoped>
.settings-panel {
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  background: #fff;
  border-radius: var(--rounded-box, 1rem);
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}

.settings-panel__title {
  font-weight: 600;
  font-size: 0.875rem;
  color: #374151;
  margin-bottom: 0.75rem;
}

.settings-panel__divider {
  border-top: 1px solid #F3F4F6;
  margin: 1rem 0;
}

.settings-panel__options {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.settings-option {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
}

.settings-option__label {
  font-size: 0.875rem;
  font-weight: 500;
}

.settings-option__hint {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.challenge-toggle-wrap {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.challenge-toggle-labels {
  display: flex;
  max-width: 156px;
}

.challenge-toggle-label {
  flex: 1;
  text-align: center;
  font-size: 0.7rem;
  color: #9CA3AF;
  transition: color 0.2s;
}

.challenge-toggle-label--active {
  color: #111827;
  font-weight: 600;
}

.challenge-toggle {
  position: relative;
  display: inline-flex;
  background: #F3F4F6;
  border-radius: 999px;
  padding: 2px;
  max-width: 156px;
  width: 100%;
}

.challenge-toggle__thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: calc(33.333% - 1.33px);
  height: calc(100% - 4px);
  background: #fff;
  border-radius: 999px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.15);
  transition: transform 0.2s ease;
  pointer-events: none;
}

.challenge-toggle__btn {
  position: relative;
  z-index: 1;
  flex: 1;
  height: 20px;
  padding: 0;
  background: transparent;
  border: none;
  border-radius: 999px;
  cursor: pointer;
}

.challenge-toggle__btn--active {
  color: #111827;
}

.challenge-toggle--locked {
  opacity: 0.5;
  cursor: not-allowed;
}

.challenge-toggle--locked .challenge-toggle__btn {
  cursor: not-allowed;
}

.challenge-toggle__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.25rem;
  max-width: 156px;
}

.challenge-toggle__locked-hint {
  font-size: 0.7rem;
  color: #9CA3AF;
}

.challenge-toggle__reset-btn {
  font-size: 0.7rem;
  color: #6366F1;
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  text-decoration: underline;
  text-underline-offset: 2px;
}

.challenge-toggle__reset-btn:hover {
  color: #4F46E5;
}
</style>
