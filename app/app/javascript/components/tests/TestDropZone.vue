<template>
  <!-- Обработчики висят на window (см. script): файл принимает вся страница,
       включая шапку, подвал и пустое место под контентом. -->
  <div class="drop-zone">
    <slot />

    <!-- Плавающий слой поверх всей страницы — как и флеш-уведомления в
         AppLayout, выносим его из потока, чтобы никакой ancestor с transform
         не превратил fixed в относительное позиционирование. -->
    <Teleport to="body">
      <Transition name="drop-overlay">
        <div v-if="dragging" class="drop-overlay">
          <div class="drop-overlay__card">
            <div class="drop-overlay__icon" aria-hidden="true">↓</div>
            <p class="drop-overlay__title">Отпустите файл теста</p>
            <p class="drop-overlay__hint">.yml или .yaml — тест откроется сразу, без сохранения в статистику</p>
          </div>
        </div>
      </Transition>
    </Teleport>

    <div v-if="parseErrors.length" class="drop-errors" role="alert">
      <div class="drop-errors__header">
        <span class="drop-errors__title">Файл не подходит</span>
        <button class="drop-errors__close" @click="clearErrors" aria-label="Закрыть">✕</button>
      </div>
      <ul class="drop-errors__list">
        <li v-for="(err, i) in parseErrors.slice(0, ERROR_LIMIT)" :key="i">{{ err }}</li>
      </ul>
      <p v-if="parseErrors.length > ERROR_LIMIT" class="drop-errors__more">
        …и ещё {{ parseErrors.length - ERROR_LIMIT }}
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { router } from '@inertiajs/vue3'
import { useDroppedTest, isYamlFile, stashDefinition } from '@/composables/useDroppedTest.js'

const ERROR_LIMIT = 8

const { parseErrors, parseFile, clearErrors } = useDroppedTest()

// dragenter/dragleave приходят и от вложенных элементов, поэтому считаем
// глубину входов, а не просто переключаем флаг.
const dragDepth = ref(0)
const dragging  = ref(false)

function hasFiles(e) {
  return Array.from(e.dataTransfer?.types ?? []).includes('Files')
}

function onDragEnter(e) {
  if (!hasFiles(e)) return
  e.preventDefault()
  dragDepth.value++
  dragging.value = true
}

// Без preventDefault на dragover браузер откроет файл вместо того, чтобы
// отдать его нам, — и уведёт пользователя со страницы.
function onDragOver(e) {
  if (!hasFiles(e)) return
  e.preventDefault()
  e.dataTransfer.dropEffect = 'copy'
}

function onDragLeave() {
  dragDepth.value = Math.max(0, dragDepth.value - 1)
  if (dragDepth.value === 0) dragging.value = false
}

async function onDrop(e) {
  if (!hasFiles(e)) return
  e.preventDefault()

  dragDepth.value = 0
  dragging.value  = false

  const files = Array.from(e.dataTransfer?.files ?? [])
  if (files.length === 0) return

  // Из нескольких файлов берём первый подходящий: перетащить папку с тестами
  // и получить один открытый тест понятнее, чем молчаливый отказ.
  const file = files.find(isYamlFile) ?? files[0]

  const definition = await parseFile(file)
  if (!definition) return

  // Определение кладём в sessionStorage в исходном snake_case: пропсы Inertia
  // на клиенте камелизуются, и отправлять их обратно на /preview/grade нельзя —
  // Rails не найдёт ни correct_lines, ни insert_text.
  stashDefinition(definition)
  router.post('/preview', { test: definition })
}

const EVENTS = {
  dragenter: onDragEnter,
  dragover:  onDragOver,
  dragleave: onDragLeave,
  drop:      onDrop,
}

onMounted(() => {
  Object.entries(EVENTS).forEach(([name, handler]) => window.addEventListener(name, handler))
})

onUnmounted(() => {
  Object.entries(EVENTS).forEach(([name, handler]) => window.removeEventListener(name, handler))
})
</script>

<style scoped>
.drop-zone {
  position: relative;
}

.drop-errors {
  margin-bottom: 1.5rem;
  padding: 0.875rem 1rem;
  border: 1px solid #FCA5A5;
  border-radius: 0.75rem;
  background: #FEF2F2;
}

.drop-errors__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 0.375rem;
}

.drop-errors__title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #991B1B;
}

.drop-errors__close {
  border: none;
  background: none;
  color: #B91C1C;
  cursor: pointer;
  font-size: 0.875rem;
  line-height: 1;
  padding: 0.125rem;
}

.drop-errors__list {
  margin: 0;
  padding-left: 1.125rem;
  font-size: 0.8125rem;
  color: #7F1D1D;
  list-style: disc;
}

.drop-errors__list li + li {
  margin-top: 0.125rem;
}

.drop-errors__more {
  margin-top: 0.25rem;
  font-size: 0.75rem;
  color: #B91C1C;
}
</style>
