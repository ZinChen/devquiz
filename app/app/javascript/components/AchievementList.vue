<template>
  <div class="achievements">
    <div
      v-for="item in items"
      :key="item.key || item.slug"
      class="achievement"
      :class="{ 'achievement--locked': !item.earned }"
    >
      <span class="achievement__icon" aria-hidden="true">{{ item.icon || '🏅' }}</span>

      <div class="achievement__body">
        <p class="achievement__title">
          {{ item.title }}
          <span v-if="item.tier && item.tier.index > 0" class="achievement__tier">
            {{ item.tier.index }}/{{ item.tier.total }}
          </span>
        </p>

        <p v-if="item.description" class="achievement__description">{{ item.description }}</p>

        <!-- Прогресс до следующей ступени. Название ступени не повторяем,
             когда плитка и так озаглавлена ею: у невзятой ачивки текущая
             ступень и следующая — одно и то же. -->
        <div v-if="showProgress && item.progress" class="achievement__progress">
          <div class="achievement__bar">
            <div
              class="achievement__bar-fill"
              :style="{ width: barWidth(item.progress) }"
            ></div>
          </div>
          <span class="achievement__progress-text">
            <template v-if="item.progress.nextTitle !== item.title">{{ item.progress.nextTitle }} · </template>
            {{ item.progress.current }} / {{ item.progress.target }}
          </span>
        </div>

        <p v-else-if="item.earnedAt" class="achievement__date">{{ formatDate(item.earnedAt) }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  items:        { type: Array, default: () => [] },
  // В поповере чужих ачивок (#10) прогресс не показывается — это уже данные
  // об активности, а не о результате.
  showProgress: { type: Boolean, default: true }
})

function barWidth(progress) {
  if (!progress?.target) return '0%'
  return `${Math.min(100, Math.round((progress.current / progress.target) * 100))}%`
}

function formatDate(value) {
  if (!value) return ''
  return new Date(value).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
}
</script>

<style scoped>
.achievements {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
  gap: 0.75rem;
}

.achievement {
  display: flex;
  gap: 0.75rem;
  padding: 0.75rem;
  border: 1px solid #F3F4F6;
  border-radius: 0.625rem;
  background: #fff;
}

/* Невзятая ачивка остаётся читаемой: это не «секрет», а цель — по ней
   ориентируются, что делать дальше. */
.achievement--locked {
  background: #FAFAFB;
  border-style: dashed;
}

.achievement--locked .achievement__icon {
  filter: grayscale(1);
  opacity: 0.55;
}

.achievement__icon {
  font-size: 1.5rem;
  line-height: 1.5;
}

.achievement__body {
  min-width: 0;
}

.achievement__title {
  display: flex;
  align-items: baseline;
  gap: 0.375rem;
  font-weight: 600;
  font-size: 0.875rem;
  color: #111827;
}

.achievement--locked .achievement__title {
  color: #6B7280;
}

.achievement__tier {
  flex-shrink: 0;
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  background: #EEF0FE;
  color: #4F63F5;
  font-size: 0.6875rem;
  font-weight: 600;
}

.achievement__description {
  margin-top: 0.125rem;
  font-size: 0.75rem;
  color: #6B7280;
}

.achievement__progress {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.achievement__bar {
  flex: 1;
  height: 0.25rem;
  border-radius: 999px;
  background: #F3F4F6;
  overflow: hidden;
}

.achievement__bar-fill {
  height: 100%;
  border-radius: 999px;
  background: #4F63F5;
}

.achievement__progress-text {
  flex-shrink: 0;
  font-size: 0.6875rem;
  color: #6B7280;
}

.achievement__date {
  margin-top: 0.375rem;
  font-size: 0.6875rem;
  color: #9CA3AF;
}
</style>
