<template>
  <div v-if="tests.length" class="tests-grid">
    <Link
      v-for="test in tests" :key="test.slug"
      :href="`/tests/${test.slug}/run/new`"
      class="test-card"
    >
      <div class="test-card__header">
        <h2 class="test-card__title">
          {{ test.title }}
          <span v-if="duplicateTitles.has(test.title)" class="test-card__slug">{{ test.slug }}</span>
        </h2>
        <DifficultyBadge :difficulty="test.difficulty" class="test-card__badge" />
      </div>
      <p class="test-card__desc">{{ test.description }}</p>
      <div class="test-card__tags">
        <button
          v-for="tag in test.tags" :key="tag"
          class="badge badge-sm tag-badge"
          :class="{ 'tag-badge--active': selectedTags.includes(tag), 'tag-badge--excluded': excludedTags.includes(tag) }"
          @click.prevent.stop="onTagClick($event, tag)"
          @mousedown.stop="lp.start($event, tag)"
          @mouseup.stop="lp.cancel()"
          @mouseleave.stop="lp.cancel()"
          @touchstart.passive.stop="lp.start($event, tag)"
          @touchend.stop="lp.cancel()"
          @touchcancel.stop="lp.cancel()"
        >{{ tag }}</button>
      </div>
      <div class="test-card__meta">
        <span>{{ test.questionsCount }} вопросов</span>
        <span>~{{ test.estimatedTime }} мин</span>
        <div class="test-card__user-stats">
          <Link
            v-if="test.attemptsCount > 0"
            :href="`/tests/${test.slug}/attempts`"
            class="badge badge-sm test-card__attempts"
            @click.stop
          >{{ test.attemptsCount }} попыток</Link>
          <Link
            v-if="test.bestScore != null && test.bestAttemptId"
            :href="`/tests/${test.slug}/runs/${test.bestAttemptId}`"
            class="badge badge-sm score-badge"
            :class="test.bestScore >= 60 ? 'score--pass' : 'score--fail'"
            @click.stop
          >
            <svg v-if="test.bestScore >= 60" width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="2,6 5,9 10,3"/>
            </svg>
            <svg v-else width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="3" y1="3" x2="9" y2="9"/><line x1="9" y1="3" x2="3" y2="9"/>
            </svg>
            {{ test.bestScore.toFixed(0) }}%
          </Link>
          <div
            v-if="test.hasCodeChallenge"
            class="challenge-modes-indicator"
            title="Режимы кодовых задач"
          >
            <span
              v-for="mode in CHALLENGE_MODES" :key="mode"
              class="challenge-mode-dot"
              :class="{ 'challenge-mode-dot--done': test.completedChallengeModes?.includes(mode) }"
              :title="MODE_LABELS[mode]"
            ></span>
          </div>
        </div>
      </div>
    </Link>
  </div>

  <EmptyState v-else @clear="$emit('clear-filters')" />
</template>

<script setup>
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import DifficultyBadge from '@/components/DifficultyBadge.vue'
import EmptyState from '@/components/tests/EmptyState.vue'

const props = defineProps({
  tests:        Array,
  selectedTags: { type: Array, default: () => [] },
  excludedTags: { type: Array, default: () => [] },
})
const emit = defineEmits(['clear-filters', 'toggle-tag', 'exclude-tag'])

function useLongPress(onLong, delay = 500) {
  let timer = null
  let fired = false
  function start(e, ...args) { fired = false; timer = setTimeout(() => { fired = true; onLong(...args) }, delay) }
  function cancel() { clearTimeout(timer) }
  function click(e) { if (fired) { e.preventDefault(); return true } return false }
  return { start, cancel, click }
}

const lp = useLongPress(tag => emit('exclude-tag', tag))

function onTagClick(e, tag) {
  if (lp.click(e)) return
  if (e.ctrlKey || e.metaKey) { emit('exclude-tag', tag); return }
  if (props.excludedTags.includes(tag)) { emit('exclude-tag', tag); return }
  emit('toggle-tag', tag)
}

const CHALLENGE_MODES = ['highlight', 'fill', 'fix']
const MODE_LABELS = { highlight: 'Highlight', fill: 'Fill', fix: 'Fix' }

const duplicateTitles = computed(() => {
  const counts = {}
  props.tests.forEach(t => { counts[t.title] = (counts[t.title] || 0) + 1 })
  return new Set(Object.keys(counts).filter(title => counts[title] > 1))
})
</script>

<style scoped>
.tests-grid {
  display: grid;
  grid-template-columns: repeat(1, 1fr);
  gap: 1rem;
}

@media (min-width: 768px) {
  .tests-grid { grid-template-columns: repeat(2, 1fr); }
}

.test-card {
  display: flex;
  flex-direction: column;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 1rem);
  padding: 1.25rem;
  transition: box-shadow 0.15s;
}

.test-card:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.test-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.test-card__title {
  font-weight: 600;
  font-size: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.test-card__slug {
  font-size: 0.7rem;
  font-weight: 400;
  color: #9CA3AF;
}

.test-card__badge {
  margin-left: 0.5rem;
  flex-shrink: 0;
}

.test-card__desc {
  font-size: 0.875rem;
  color: #6B7280;
  margin-bottom: 0.75rem;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.test-card__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
}

.test-card__meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  font-size: 0.75rem;
  color: #9CA3AF;
  margin-top: auto;
}

.test-card__user-stats {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-left: auto;
}

@media (max-width: 767px) {
  .test-card__user-stats {
    margin-right: 0;
    justify-content: flex-end;
  }
}

.test-card__attempts {
  background: #6B728020;
  color: #6B7280;
  border: none;
  font-weight: 500;
}

.score-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
}

.score--pass {
  background: #10B98120;
  color: #10B981;
  border: none;
  font-weight: 500;
}

.score--fail {
  background: #EF444420;
  color: #EF4444;
  border: none;
  font-weight: 500;
}

.challenge-modes-indicator {
  display: flex;
  align-items: center;
  gap: 3px;
}

@media (min-width: 768px) {
  .challenge-modes-indicator {
    margin-left: auto;
  }
}


.challenge-mode-dot {
  display: block;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #E5E7EB;
  transition: background 0.15s;
}

.challenge-mode-dot--done {
  background: #4F63F5;
}
</style>
