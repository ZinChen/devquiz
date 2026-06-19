<template>
  <AppLayout>
    <div class="max-w-2xl mx-auto">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <Link :href="`/tests/${test.slug}`" class="text-sm text-gray-400 hover:text-gray-600">← {{ test.title }}</Link>
        <div class="flex items-center gap-3">
          <div class="text-sm text-gray-500">
            {{ answeredCount }} / {{ questions.length }}
            <span class="ml-4 font-mono" :class="timerWarning ? 'text-red-500' : 'text-gray-600'">{{ timeDisplay }}</span>
          </div>
          <!-- Settings toggle -->
          <button
            @click="settingsOpen = !settingsOpen"
            class="p-2 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors"
            title="Настройки"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Settings panel -->
        <div v-if="settingsOpen" class="card border border-gray-100 shadow-sm p-5 mb-6">
          <h3 class="font-semibold text-sm text-gray-700 mb-3">Настройки прохождения</h3>
          <div class="flex flex-col gap-2">
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="radio" v-model="mode" value="all" class="radio radio-sm" />
              <div>
                <p class="text-sm font-medium">Все вопросы сразу</p>
                <p class="text-xs text-gray-400">Листай список и отвечай в любом порядке</p>
              </div>
            </label>
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="radio" v-model="mode" value="one" class="radio radio-sm" />
              <div>
                <p class="text-sm font-medium">По одному вопросу</p>
                <p class="text-xs text-gray-400">Карточки с анимацией, фокус на текущем вопросе</p>
              </div>
            </label>
          </div>
        </div>

      <!-- ONE-BY-ONE MODE -->
      <div v-if="mode === 'one'">
        <!-- Progress bar -->
        <div class="w-full bg-gray-100 rounded-full h-1.5 mb-6">
          <div
            class="h-1.5 rounded-full transition-all duration-300"
            style="background:#4F63F5"
            :style="{ width: progressPercent + '%' }"
          ></div>
        </div>

        <div class="relative overflow-hidden" style="min-height: 280px">
          <TransitionGroup name="card-slide" tag="div">
            <div
              v-if="currentQuestion"
              :key="currentQuestion.id"
              class="card border border-gray-100 shadow-sm p-6"
            >
              <p class="font-medium mb-1 text-xs text-gray-400">Вопрос {{ currentIndex + 1 }} из {{ questions.length }}</p>
              <p class="mb-4 text-base leading-relaxed" v-html="formatText(currentQuestion.text)"></p>

              <div class="flex flex-col gap-2">
                <label
                  v-for="(opt, oi) in currentQuestion.options" :key="opt.id"
                  class="flex items-start gap-3 p-3 rounded-xl cursor-pointer transition-colors"
                  :style="optionStyle(currentQuestion, opt)"
                  @click="currentQuestion.type !== 'multiple' && onRadioPick(currentQuestion, opt.id)"
                >
                  <span class="shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-semibold border mt-0.5"
                    :style="optionLetterStyle(currentQuestion, opt)">
                    {{ optionLetter(oi) }}
                  </span>
                  <div class="flex-1">
                    <input
                      v-if="currentQuestion.type === 'multiple'"
                      type="checkbox"
                      :value="opt.id"
                      v-model="answers[currentQuestion.id]"
                      class="hidden"
                    />
                    <input
                      v-else
                      type="radio"
                      :name="currentQuestion.id"
                      :value="opt.id"
                      v-model="answers[currentQuestion.id]"
                      class="hidden"
                    />
                    <span class="text-sm">{{ opt.text }}</span>
                  </div>
                </label>
              </div>

              <div class="flex justify-between items-center mt-6">
                <button
                  v-if="currentIndex > 0"
                  @click="goTo(currentIndex - 1)"
                  class="btn btn-ghost btn-sm text-gray-400"
                >← Назад</button>
                <div v-else></div>

                <button
                  v-if="currentIndex < questions.length - 1"
                  @click="goTo(currentIndex + 1)"
                  class="btn btn-sm text-white"
                  style="background:#4F63F5;border:none"
                  :disabled="!isAnswered(currentQuestion)"
                >
                  Далее →
                </button>
                <button
                  v-else
                  @click="submit"
                  class="btn btn-sm text-white"
                  style="background:#4F63F5;border:none"
                  :disabled="answeredCount < questions.length"
                >
                  Завершить
                </button>
              </div>
            </div>
          </TransitionGroup>
        </div>

        <p v-if="answeredCount < questions.length" class="text-xs text-gray-400 text-center mt-4">
          Отвечено {{ answeredCount }} из {{ questions.length }}
        </p>
      </div>

      <!-- ALL MODE -->
      <form v-else @submit.prevent="submit">
        <div
          v-for="(q, idx) in questions" :key="q.id"
          class="card border border-gray-100 shadow-sm p-6 mb-4"
        >
          <p class="font-medium mb-1 text-xs text-gray-400">Вопрос {{ idx + 1 }}</p>
          <p class="mb-4 text-base leading-relaxed" v-html="formatText(q.text)"></p>

          <div class="flex flex-col gap-2">
            <label
              v-for="(opt, oi) in q.options" :key="opt.id"
              class="flex items-start gap-3 p-3 rounded-xl cursor-pointer transition-colors"
              :style="optionStyle(q, opt)"
            >
              <span class="shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-semibold border mt-0.5"
                :style="optionLetterStyle(q, opt)">
                {{ optionLetter(oi) }}
              </span>
              <input
                v-if="q.type === 'multiple'"
                type="checkbox"
                :value="opt.id"
                v-model="answers[q.id]"
                class="hidden"
              />
              <input
                v-else
                type="radio"
                :name="q.id"
                :value="opt.id"
                v-model="answers[q.id]"
                class="hidden"
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
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { Link, router } from '@inertiajs/vue3'
import AppLayout from '@/components/AppLayout.vue'

const props = defineProps({ test: Object, questions: Array })

const STORAGE_KEY = `devquiz_session_${props.test.slug}`

const answers     = ref({})
const startedAt   = ref(new Date().toISOString())
const elapsed     = ref(0)
const settingsOpen = ref(false)
const mode        = ref(localStorage.getItem('devquiz_mode') || 'all')
const currentIndex = ref(0)
let timer

// Persist mode preference
watch(mode, val => localStorage.setItem('devquiz_mode', val))

onMounted(() => {
  timer = setInterval(() => elapsed.value++, 1000)

  // Init answers
  props.questions.forEach(q => {
    answers.value[q.id] = q.type === 'multiple' ? [] : null
  })

  // Restore saved session state
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null')
    if (saved) {
      answers.value   = saved.answers   || answers.value
      currentIndex.value = saved.currentIndex || 0
      startedAt.value = saved.startedAt || startedAt.value
    }
  } catch {}

  // Save session state on each answer change
  watch(answers, () => saveSession(), { deep: true })
  watch(currentIndex, () => saveSession())
})

onUnmounted(() => clearInterval(timer))

function saveSession() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    answers:      answers.value,
    currentIndex: currentIndex.value,
    startedAt:    startedAt.value,
    questionOrder: props.questions.map(q => q.id),
  }))
}

const currentQuestion = computed(() => props.questions[currentIndex.value])

const progressPercent = computed(() =>
  Math.round((answeredCount.value / props.questions.length) * 100)
)

const answeredCount = computed(() =>
  props.questions.filter(q => isAnswered(q)).length
)

function isAnswered(q) {
  const a = answers.value[q.id]
  return q.type === 'multiple' ? a?.length > 0 : a !== null
}

const timeDisplay = computed(() => {
  const m = Math.floor(elapsed.value / 60).toString().padStart(2, '0')
  const s = (elapsed.value % 60).toString().padStart(2, '00')
  return `${m}:${s}`
})

const timerWarning = computed(() =>
  props.test.estimated_time && elapsed.value > props.test.estimated_time * 60
)

function goTo(idx) {
  currentIndex.value = idx
}

function onRadioPick(q, optId) {
  answers.value[q.id] = optId
  const nextIdx = currentIndex.value + 1
  if (nextIdx < props.questions.length) {
    setTimeout(() => goTo(nextIdx), 400)
  }
}

const LETTERS = ['A', 'B', 'C', 'D', 'E', 'F']
function optionLetter(idx) {
  return LETTERS[idx] || String(idx + 1)
}

function optionStyle(q, opt) {
  const sel = answers.value[q.id]
  const selected = q.type === 'multiple' ? sel?.includes(opt.id) : sel === opt.id
  if (selected) return { background: '#EEF0FF', border: '1px solid #4F63F5' }
  return { background: '#F7F8FA', border: '1px solid transparent' }
}

function optionLetterStyle(q, opt) {
  const sel = answers.value[q.id]
  const selected = q.type === 'multiple' ? sel?.includes(opt.id) : sel === opt.id
  if (selected) return { background: '#4F63F5', color: '#fff', borderColor: '#4F63F5' }
  return { background: '#fff', color: '#9CA3AF', borderColor: '#E5E7EB' }
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
  localStorage.removeItem(STORAGE_KEY)
  router.post(`/tests/${props.test.slug}/run`, {
    answers:    normalized,
    started_at: startedAt.value,
    time_spent: elapsed.value,
  })
}
</script>

<style scoped>
/* Card slide animation: enter from right, leave to left */
.card-slide-enter-active,
.card-slide-leave-active {
  transition: all 0.35s cubic-bezier(0.4, 0, 0.2, 1);
  position: absolute;
  width: 100%;
}
.card-slide-enter-from {
  transform: translateX(60px);
  opacity: 0;
}
.card-slide-enter-to {
  transform: translateX(0);
  opacity: 1;
}
.card-slide-leave-from {
  transform: translateX(0);
  opacity: 1;
}
.card-slide-leave-to {
  transform: translateX(-60px);
  opacity: 0;
}


</style>
