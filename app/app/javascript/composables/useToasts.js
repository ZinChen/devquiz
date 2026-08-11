import { ref } from 'vue'

// Клиентские уведомления. Нужны там, где запрос идёт с preserveState: Inertia
// не перерисовывает страницу, и flash из redirect_back до слоя тостов не
// доходит — показать его может только тот, кто инициировал сохранение.
const toasts = ref([])

let nextId = 0

export function useToasts() {
  function notify(text, { type = 'notice', timeout = 4000 } = {}) {
    if (!text) return

    const id = ++nextId
    // Повторное сохранение заменяет предыдущее уведомление с тем же текстом,
    // а не копит стопку одинаковых плашек.
    toasts.value = [...toasts.value.filter(t => t.text !== text), { id, text, type }]

    if (timeout) setTimeout(() => dismiss(id), timeout)
    return id
  }

  function dismiss(id) {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }

  return { toasts, notify, dismiss }
}
