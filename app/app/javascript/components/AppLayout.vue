<template>
  <div class="min-h-screen flex flex-col" style="background:#F7F8FA">
    <header class="bg-white border-b border-gray-100 shadow-sm">
      <div class="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
        <Link href="/" class="font-semibold text-lg tracking-tight" style="color:#4F63F5">
          DevQuiz
        </Link>

        <nav class="flex items-center gap-5 text-sm">
          <Link href="/" class="nav-link">Тесты</Link>
          <Link href="/stats" class="nav-link">Статистика</Link>
          <template v-if="currentUser">
            <Link href="/dashboard" class="nav-link">Кабинет</Link>
            <Link href="/logout" method="delete" as="button" class="btn btn-sm" style="background:#4F63F5;color:#fff;border:none">
              Выйти
            </Link>
          </template>
          <template v-else>
            <Link href="/login" class="btn btn-sm" style="background:#4F63F5;color:#fff;border:none">
              Войти
            </Link>
          </template>
        </nav>
      </div>
    </header>

    <main class="flex-1 max-w-5xl mx-auto w-full px-4 py-8">
      <div v-if="flash?.notice" class="alert alert-success mb-6 shadow-sm">{{ flash.notice }}</div>
      <div v-if="flash?.alert"  class="alert alert-error  mb-6 shadow-sm">{{ flash.alert }}</div>
      <slot />
    </main>

    <footer class="text-center text-xs text-gray-400 py-6 border-t border-gray-100">
      DevQuiz — тесты для backend-разработчиков
    </footer>
  </div>
</template>

<script setup>
import { Link, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const page = usePage()
const currentUser = computed(() => page.props.current_user)
const flash       = computed(() => page.props.flash)
</script>

<style scoped>
.nav-link { color: #374151; }
.nav-link:hover { color: #4F63F5; }
</style>
