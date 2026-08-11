<template>
  <Transition name="onboarding">
    <div
      v-if="visible"
      class="onboarding"
      role="dialog"
      aria-modal="true"
      aria-labelledby="onboarding-title"
      @click.self="dismiss"
      @keydown.esc="dismiss"
    >
      <div class="onboarding__panel">
        <button class="onboarding__close" aria-label="Закрыть" @click="dismiss">×</button>

        <h2 id="onboarding-title" class="onboarding__title">
          {{ editing ? 'Мои темы' : 'Выбери нужные темы' }}
        </h2>
        <p class="onboarding__subtitle">
          Эти темы и теги будут показаны на главной странице
        </p>

        <TagPicker v-model="selected" :categories="categories" :descriptions="descriptions" />

        <div class="onboarding__actions">
          <!-- В режиме правки отказ ничего не сохраняет, при первом входе
               "Пропустить" — это осознанный выбор "без тем". -->
          <button class="btn btn-ghost btn-sm" @click="dismiss">
            {{ editing ? 'Отмена' : 'Пропустить' }}
          </button>
          <!-- Кнопка появляется по факту изменения, а не по наличию тем:
               снять все темы — это тоже изменение, его надо дать сохранить. -->
          <button v-if="changed" class="btn btn-primary" @click="submit(selected)">
            {{ editing ? 'Сохранить' : 'Показать тесты' }}
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref, computed } from 'vue'
import { router } from '@inertiajs/vue3'
import TagPicker from '@/components/tests/TagPicker.vue'
import { useToasts } from '@/composables/useToasts'

const { notify } = useToasts()

const props = defineProps({
  categories:   { type: Array,  default: () => [] },
  descriptions: { type: Object, default: () => ({}) },
  // Режим правки: открыт кнопкой "Изменить", стартует с текущего выбора
  // и закрывается без сохранения.
  editing:      { type: Boolean, default: false },
  initialTags:  { type: Array,  default: () => [] },
})

const emit = defineEmits(['done', 'close'])

const visible  = ref(true)
const selected = ref([...props.initialTags])
const saving   = ref(false)

// При первом входе закрытие — это выбор "без тем" и он сохраняется;
// в режиме правки это просто отмена.
function dismiss() {
  if (props.editing) {
    visible.value = false
    emit('close')
    return
  }
  submit([])
}

// Порядок выбора не значим, поэтому сравниваем как множества.
const changed = computed(() => {
  const before = [...props.initialTags].sort().join()
  const after  = [...selected.value].sort().join()
  return before !== after
})

function submit(tags) {
  if (saving.value) return
  saving.value = true

  const wasChanged = changed.value

  // Оверлей убираем сразу, не дожидаясь ответа: под ним уже отрендерена
  // главная, а выбор всё равно применяется на клиенте.
  visible.value = false
  emit('done', tags)

  // preserveState обязателен: без него Inertia пересоздаст страницу и сбросит
  // применённый выбор. only: [] здесь использовать нельзя — с пустым списком
  // пропсы не возвращаются и выбор теряется при следующей навигации.
  router.patch('/preferences/tags', { tags }, {
    preserveState: true,
    preserveScroll: true,
    // При preserveState страница не перерисовывается, поэтому серверный flash
    // до слоя уведомлений не доходит — показываем его сами.
    onSuccess: () => { if (wasChanged) notify('Избранные темы обновлены.') },
  })
}
</script>

<style scoped>
.onboarding {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1.5rem;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(6px);
  overflow-y: auto;
}

.onboarding__panel {
  position: relative;
  width: 100%;
  max-width: 46rem;
  text-align: center;
}

.onboarding__close {
  position: absolute;
  top: -0.5rem;
  right: 0;
  width: 2rem;
  height: 2rem;
  font-size: 1.5rem;
  line-height: 1;
  color: #9CA3AF;
  background: none;
  border: none;
  cursor: pointer;
}

.onboarding__close:hover {
  color: #4B5563;
}

.onboarding__title {
  font-size: 1.875rem;
  font-weight: 700;
  color: #1F2937;
  margin-bottom: 0.5rem;
}

.onboarding__subtitle {
  color: #6B7280;
  margin-bottom: 2rem;
}

.onboarding__actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

/* Растворение оверлея открывает уже отрисованную под ним главную. */
.onboarding-leave-active {
  transition: opacity 0.45s ease;
}

.onboarding-leave-to {
  opacity: 0;
}

@media (prefers-color-scheme: dark) {
  .onboarding {
    background: rgba(17, 24, 39, 0.92);
  }

  .onboarding__title {
    color: #F9FAFB;
  }
}
</style>
