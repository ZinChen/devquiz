<template>
  <div class="layout">
    <header class="layout__header">
      <div class="layout__header-inner">
        <Link href="/" class="layout__logo">
          DevQuiz
        </Link>

        <div class="layout__search">
          <slot name="search" />
        </div>

        <nav v-if="!hideNav" class="layout__nav">
          <template v-if="currentUser">
            <Link href="/stats" class="nav-link">Статистика</Link>
            <Link href="/dashboard" class="nav-link">Кабинет</Link>
            <Link href="/logout" method="delete" as="button" class="btn btn-sm btn-primary">
              Выйти
            </Link>
          </template>
          <template v-else>
            <Link href="/login" class="btn btn-sm btn-primary">
              Войти
            </Link>
          </template>
        </nav>
      </div>
    </header>

    <!-- Уведомления вне main: это плавающий слой в углу экрана, он не должен
         сдвигать содержимое страницы. -->
    <Teleport to="body">
      <div class="flash-toasts" role="status" aria-live="polite">
        <Transition name="flash-toast">
          <div v-if="flash?.notice && noticeVisible" class="flash-toast flash-toast--notice">
            <span class="flash-toast__icon" aria-hidden="true">✓</span>
            <span class="flash-toast__text">{{ flash.notice }}</span>
            <button class="flash-toast__close" @click="noticeVisible = false" aria-label="Закрыть">✕</button>
          </div>
        </Transition>
        <Transition name="flash-toast">
          <div v-if="flash?.alert && alertVisible" class="flash-toast flash-toast--alert">
            <span class="flash-toast__icon" aria-hidden="true">!</span>
            <span class="flash-toast__text">{{ flash.alert }}</span>
            <button class="flash-toast__close" @click="alertVisible = false" aria-label="Закрыть">✕</button>
          </div>
        </Transition>

        <!-- Уведомления, поднятые с клиента (см. useToasts). -->
        <TransitionGroup name="flash-toast">
          <div
            v-for="toast in toasts" :key="toast.id"
            class="flash-toast"
            :class="`flash-toast--${toast.type}`"
          >
            <span class="flash-toast__icon" aria-hidden="true">{{ toast.type === 'alert' ? '!' : '✓' }}</span>
            <span class="flash-toast__text">{{ toast.text }}</span>
            <button class="flash-toast__close" @click="dismiss(toast.id)" aria-label="Закрыть">✕</button>
          </div>
        </TransitionGroup>
      </div>
    </Teleport>

    <main class="layout__main">
      <slot />
    </main>

    <footer class="layout__footer">
      DevQuiz — тесты для backend-разработчиков
    </footer>
  </div>
</template>

<script setup>
import { Link, usePage } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'
import { useToasts } from '@/composables/useToasts'

const { toasts, dismiss } = useToasts()

defineProps({ hideNav: { type: Boolean, default: false } })

const page = usePage()
const currentUser = computed(() => page.props.currentUser)
const flash       = computed(() => page.props.flash)

const noticeVisible = ref(!!flash.value?.notice)
const alertVisible  = ref(!!flash.value?.alert)

watch(() => flash.value?.notice, val => {
  noticeVisible.value = !!val
  if (val) setTimeout(() => { noticeVisible.value = false }, 4000)
}, { immediate: true })

// Ошибка висит дольше обычного уведомления, но тоже уезжает сама: плавающая
// плашка в углу перекрывает интерфейс, оставлять её навсегда нельзя.
watch(() => flash.value?.alert, val => {
  alertVisible.value = !!val
  if (val) setTimeout(() => { alertVisible.value = false }, 7000)
}, { immediate: true })
</script>

<style scoped>
.layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.layout__header {
  background: #fff;
  border-bottom: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}

.layout__header-inner {
  max-width: 64rem;
  margin: 0 auto;
  padding: 0 1rem;
  height: 3.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
}

.layout__logo {
  font-weight: 600;
  font-size: 1.125rem;
  letter-spacing: -0.01em;
  color: #4F63F5;
  flex-shrink: 0;
}

.layout__search {
  flex: 1;
}

.layout__nav {
  display: flex;
  align-items: center;
  gap: 1.25rem;
  font-size: 0.875rem;
  flex-shrink: 0;
}

.layout__main {
  flex: 1;
  max-width: 64rem;
  margin: 0 auto;
  width: 100%;
  padding: 2rem 1rem;
}

.layout__footer {
  text-align: center;
  font-size: 0.75rem;
  color: #9CA3AF;
  padding: 1.5rem 0;
  border-top: 1px solid #F3F4F6;
}

.nav-link { color: #374151; }
.nav-link:hover { color: #4F63F5; }
</style>

<style>
/* Не scoped: уведомления телепортируются в body. */
.flash-toasts {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 100;
  display: flex;
  flex-direction: column;
  /* По правому краю: без этого колонка растягивается и плашки уезжают вниз. */
  align-items: flex-end;
  gap: 0.5rem;
  pointer-events: none;
}

/* Плашка в духе системного уведомления macOS: скруглённая, с размытой
   подложкой и мягкой тенью вместо жирной рамки. */
.flash-toast {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  width: max-content;
  max-width: min(22rem, calc(100vw - 2rem));
  padding: 0.75rem 0.875rem;
  border-radius: 0.875rem;
  font-size: 0.8125rem;
  line-height: 1.35;
  color: #1F2937;
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid rgba(255, 255, 255, 0.6);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.06);
  pointer-events: auto;
}

.flash-toast__icon {
  flex-shrink: 0;
  display: grid;
  place-items: center;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 9999px;
  font-size: 0.6875rem;
  font-weight: 700;
  color: #fff;
}

.flash-toast--notice .flash-toast__icon { background: #10B981; }
.flash-toast--alert  .flash-toast__icon { background: #F97316; }

.flash-toast__text {
  flex: 1;
  min-width: 0;
}

.flash-toast__close {
  flex-shrink: 0;
  padding: 0.125rem 0.25rem;
  font-size: 0.6875rem;
  color: #6B7280;
  background: none;
  border: none;
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.15s;
}

.flash-toast__close:hover {
  opacity: 1;
}

/* Выезжает справа, как системное уведомление. */
.flash-toast-enter-active {
  transition: opacity 0.3s ease, transform 0.35s cubic-bezier(0.22, 1, 0.36, 1);
}

.flash-toast-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.flash-toast-enter-from,
.flash-toast-leave-to {
  opacity: 0;
  transform: translateX(calc(100% + 1rem));
}

@media (prefers-color-scheme: dark) {
  .flash-toast {
    color: #F3F4F6;
    background: rgba(31, 41, 55, 0.75);
    border-color: rgba(255, 255, 255, 0.12);
  }

  .flash-toast__close {
    color: #D1D5DB;
  }
}
</style>
