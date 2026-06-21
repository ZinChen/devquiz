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
  </div>
</template>

<script setup>
defineProps({ mode: String })
defineEmits(['update:mode'])
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
</style>
