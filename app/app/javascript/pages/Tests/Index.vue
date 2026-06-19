<template>
  <AppLayout>
    <div class="mb-8">
      <h1 class="text-3xl font-bold mb-2">Тесты для разработчиков</h1>
      <p class="text-gray-500">Backend-разработка, Ruby on Rails, PostgreSQL и не только</p>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-2 mb-6">
      <button
        v-for="tag in allTags" :key="tag"
        @click="toggleTag(tag)"
        class="badge badge-lg cursor-pointer transition-all"
        :style="filterTag === tag ? 'background:#4F63F5;color:#fff;border:none' : 'background:#EEF0FF;color:#4F63F5;border:none'"
      >
        {{ tag }}
      </button>
    </div>

    <div class="flex gap-2 mb-8">
      <button
        v-for="d in difficulties" :key="d.value"
        @click="toggleDifficulty(d.value)"
        class="btn btn-sm"
        :style="filterDifficulty === d.value ? 'background:#4F63F5;color:#fff;border:none' : ''"
      >
        {{ d.label }}
      </button>
    </div>

    <!-- Grid -->
    <div v-if="tests.length" class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <Link
        v-for="test in tests" :key="test.slug"
        :href="`/tests/${test.slug}`"
        class="card border border-gray-100 shadow-sm hover:shadow-md transition-shadow p-5 block"
      >
        <div class="flex items-start justify-between mb-2">
          <h2 class="font-semibold text-base">{{ test.title }}</h2>
          <DifficultyBadge :difficulty="test.difficulty" class="ml-2 shrink-0" />
        </div>
        <p class="text-sm text-gray-500 mb-3 line-clamp-2">{{ test.description }}</p>
        <div class="flex flex-wrap gap-1 mb-3">
          <span
            v-for="tag in test.tags" :key="tag"
            class="badge badge-sm"
            style="background:#EEF0FF;color:#4F63F5;border:none"
          >{{ tag }}</span>
        </div>
        <div class="flex items-center gap-4 text-xs text-gray-400">
          <span>{{ test.questions_count }} вопросов</span>
          <span>~{{ test.estimated_time }} мин</span>
          <span v-if="test.attempts_count > 0">{{ test.attempts_count }} попыток</span>
          <span v-if="test.attempts_count > 0">avg {{ test.avg_score.toFixed(0) }}%</span>
        </div>
      </Link>
    </div>

    <div v-else class="text-center py-16 text-gray-400">
      <p class="text-lg">Тесты не найдены</p>
      <button @click="clearFilters" class="btn btn-sm mt-4" style="background:#4F63F5;color:#fff;border:none">
        Сбросить фильтры
      </button>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import DifficultyBadge from '@/components/DifficultyBadge.vue'

const props = defineProps({
  tests:             Array,
  allTags:           Array,
  filterTag:         String,
  filterDifficulty:  String,
})

const filterTag        = ref(props.filterTag || null)
const filterDifficulty = ref(props.filterDifficulty || null)

const difficulties = [
  { value: 'beginner',     label: 'Начальный' },
  { value: 'intermediate', label: 'Средний' },
  { value: 'advanced',     label: 'Продвинутый' },
]

function applyFilters() {
  router.get('/', {
    tag:        filterTag.value || undefined,
    difficulty: filterDifficulty.value || undefined,
  }, { preserveState: true })
}

function toggleTag(tag) {
  filterTag.value = filterTag.value === tag ? null : tag
  applyFilters()
}

function toggleDifficulty(d) {
  filterDifficulty.value = filterDifficulty.value === d ? null : d
  applyFilters()
}

function clearFilters() {
  filterTag.value = null
  filterDifficulty.value = null
  applyFilters()
}
</script>
