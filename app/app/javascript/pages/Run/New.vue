<template>
  <AppLayout>
    <div class="max-w-2xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <Link :href="`/tests/${test.slug}`" class="text-sm text-gray-400 hover:text-gray-600">← {{ test.title }}</Link>
        <div class="text-sm text-gray-500">
          {{ answeredCount }} / {{ questions.length }}
          <span class="ml-4 font-mono" :class="timerWarning ? 'text-red-500' : 'text-gray-600'">{{ timeDisplay }}</span>
        </div>
      </div>

      <form @submit.prevent="submit">
        <div
          v-for="(q, idx) in questions" :key="q.id"
          class="card border border-gray-100 shadow-sm p-6 mb-4"
        >
          <p class="font-medium mb-1 text-xs text-gray-400">Вопрос {{ idx + 1 }}</p>
          <p class="mb-4 text-base leading-relaxed" v-html="formatText(q.text)"></p>

          <div class="flex flex-col gap-2">
            <label
              v-for="opt in q.options" :key="opt.id"
              class="flex items-start gap-3 p-3 rounded-xl cursor-pointer transition-colors"
              :style="optionStyle(q, opt)"
            >
              <input
                v-if="q.type === 'multiple'"
                type="checkbox"
                :value="opt.id"
                v-model="answers[q.id]"
                class="mt-0.5 checkbox checkbox-sm"
              />
              <input
                v-else
                type="radio"
                :name="q.id"
                :value="opt.id"
                v-model="answers[q.id]"
                class="mt-0.5 radio radio-sm"
              />
              <span class="text-sm">{{ opt.text }}</span>
            </label>
          </div>
        </div>

        <div class="flex justify-end mt-6">
          <button
            type="submit"
            class="btn px-8 text-white"
            style="background:#4F63F5;border:none"
            :disabled="answeredCount < questions.length"
          >
            Завершить тест
          </button>
        </div>
        <p v-if="answeredCount < questions.length" class="text-xs text-gray-400 text-right mt-2">
          Ответьте на все вопросы
        </p>
      </form>
    </div>
  </AppLayout>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({ test: Object, questions: Array })

const answers   = ref({})
const startedAt = ref(new Date().toISOString())
const elapsed   = ref(0)
let timer

onMounted(() => {
  timer = setInterval(() => elapsed.value++, 1000)
  props.questions.forEach(q => {
    answers.value[q.id] = q.type === 'multiple' ? [] : null
  })
})
onUnmounted(() => clearInterval(timer))

const answeredCount = computed(() =>
  props.questions.filter(q => {
    const a = answers.value[q.id]
    return q.type === 'multiple' ? a?.length > 0 : a !== null
  }).length
)

const timeDisplay = computed(() => {
  const m = Math.floor(elapsed.value / 60).toString().padStart(2, '0')
  const s = (elapsed.value % 60).toString().padStart(2, '0')
  return `${m}:${s}`
})

const timerWarning = computed(() =>
  props.test.estimated_time && elapsed.value > props.test.estimated_time * 60
)

function optionStyle(q, opt) {
  const sel = answers.value[q.id]
  const selected = q.type === 'multiple' ? sel?.includes(opt.id) : sel === opt.id
  if (selected) return { background: '#EEF0FF', border: '1px solid #4F63F5' }
  return { background: '#F7F8FA', border: '1px solid transparent' }
}

function formatText(text) {
  return text.replace(/`([^`]+)`/g, '<code class="bg-gray-100 rounded px-1 py-0.5 text-sm font-mono">$1</code>')
}

function submit() {
  const normalized = {}
  props.questions.forEach(q => {
    const a = answers.value[q.id]
    normalized[q.id] = q.type === 'multiple' ? (a || []) : (a ? [a] : [])
  })
  router.post(`/tests/${props.test.slug}/run`, {
    answers:     normalized,
    started_at:  startedAt.value,
    time_spent:  elapsed.value,
  })
}
</script>
