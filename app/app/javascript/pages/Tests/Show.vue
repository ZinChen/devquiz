<template>
  <AppLayout>
    <div class="max-w-2xl">
      <Link href="/" class="text-sm text-gray-400 hover:text-gray-600 mb-6 inline-block">← Все тесты</Link>

      <div class="card border border-gray-100 shadow-sm p-8">
        <div class="flex items-start gap-3 mb-4">
          <h1 class="text-2xl font-bold flex-1">{{ test.title }}</h1>
          <DifficultyBadge :difficulty="test.difficulty" />
        </div>

        <p class="text-gray-600 mb-6">{{ test.description }}</p>

        <div class="flex flex-wrap gap-1 mb-6">
          <span
            v-for="tag in test.tags" :key="tag"
            class="badge"
            style="background:#EEF0FF;color:#4F63F5;border:none"
          >{{ tag }}</span>
        </div>

        <div class="grid grid-cols-3 gap-4 mb-8">
          <div class="text-center p-4 rounded-xl" style="background:#F7F8FA">
            <div class="text-2xl font-bold" style="color:#4F63F5">{{ test.questions_count }}</div>
            <div class="text-xs text-gray-500 mt-1">вопросов</div>
          </div>
          <div class="text-center p-4 rounded-xl" style="background:#F7F8FA">
            <div class="text-2xl font-bold text-gray-700">~{{ test.estimated_time }}<span class="text-sm font-normal"> мин</span></div>
            <div class="text-xs text-gray-500 mt-1">примерно</div>
          </div>
          <div class="text-center p-4 rounded-xl" style="background:#F7F8FA">
            <div class="text-2xl font-bold text-gray-700">{{ test.attempts_count }}</div>
            <div class="text-xs text-gray-500 mt-1">попыток</div>
          </div>
        </div>

        <div v-if="test.attempts_count > 0" class="flex gap-6 text-sm text-gray-500 mb-8">
          <span>Средний балл: <b>{{ test.avg_score.toFixed(1) }}%</b></span>
          <span>Проходят: <b>{{ test.pass_rate.toFixed(0) }}%</b></span>
        </div>

        <Link :href="`/tests/${test.slug}/run/new`" class="btn w-full text-white" style="background:#4F63F5;border:none">
          Начать тест
        </Link>
      </div>
    </div>
  </AppLayout>
</template>

<script setup>
import { Link } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'
import DifficultyBadge from '@/components/DifficultyBadge.vue'

defineProps({ test: Object })
</script>
