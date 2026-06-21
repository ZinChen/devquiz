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

    <main class="layout__main">
      <Transition name="flash">
        <div v-if="flash?.notice && noticeVisible" class="flash-msg flash-msg--notice">
          <span>{{ flash.notice }}</span>
          <button class="flash-msg__close" @click="noticeVisible = false" aria-label="Закрыть">✕</button>
        </div>
      </Transition>
      <Transition name="flash">
        <div v-if="flash?.alert && alertVisible" class="flash-msg flash-msg--alert">
          <span>{{ flash.alert }}</span>
          <button class="flash-msg__close" @click="alertVisible = false" aria-label="Закрыть">✕</button>
        </div>
      </Transition>
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

watch(() => flash.value?.alert, val => {
  alertVisible.value = !!val
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

.flash-msg {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.625rem 1rem;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  margin-bottom: 1rem;
  border: 1px solid;
}

.flash-msg--notice {
  background: #F0FDF4;
  color: #166534;
  border-color: #BBF7D0;
}

.flash-msg--alert {
  background: #FFF7ED;
  color: #9A3412;
  border-color: #FED7AA;
}

.flash-msg__close {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 0.75rem;
  opacity: 0.5;
  color: inherit;
  padding: 0.125rem 0.25rem;
  flex-shrink: 0;
  transition: opacity 0.15s;
}

.flash-msg__close:hover {
  opacity: 1;
}

.flash-enter-active,
.flash-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.flash-enter-from,
.flash-leave-to {
  opacity: 0;
  transform: translateY(-0.5rem);
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
