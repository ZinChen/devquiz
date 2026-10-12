import { ref } from 'vue'

// Таймер активного времени: идёт, пока человек смотрит на тест, и стоит, когда
// вкладка скрыта или он давно ничего не делает.
//
// Раньше это был голый setInterval(() => elapsed++, 1000): он считал и скрытую
// вкладку, а в фоне Chrome ещё и замедляет таймеры (после ~5 минут — до одного
// срабатывания в минуту), так что счётчик не просто ошибался, а ещё и
// отставал от реального времени. Теперь секунды копятся из реальных интервалов
// между тиками (Date.now), а не из числа срабатываний, поэтому частота
// интервала на результат не влияет.
//
// Итог уходит на сервер как time_spent и участвует в ачивке «Спидран».

// Один тик не может добавить больше этого: ноутбук «уснул» с видимой вкладкой
// или основной поток надолго завис — это не время за тестом.
export const MAX_STEP_MS = 3000

// Столько без действий считается паузой в работе. Последние IDLE_MS перед
// паузой вычитаются: человек уже ушёл, время не его. Пять минут — чтобы не
// штрафовать за честное раздумье над вопросом с кодом.
export const IDLE_MS = 5 * 60 * 1000

const TICK_MS = 1000
const ACTIVITY_EVENTS = [ 'pointerdown', 'pointermove', 'keydown', 'wheel', 'touchstart', 'scroll' ]

export function useActiveTimer() {
  const elapsed     = ref(0)       // целые секунды, то, что видит человек и уходит на сервер
  const paused      = ref(false)
  const pauseReason = ref(null)    // 'hidden' | 'idle'

  let accumulatedMs = 0
  let lastTick      = Date.now()
  let lastActivity  = Date.now()
  let interval      = null

  function publish() {
    elapsed.value = Math.floor(accumulatedMs / 1000)
  }

  function tick() {
    const now   = Date.now()
    const delta = now - lastTick
    lastTick = now
    if (paused.value) return

    accumulatedMs += Math.min(Math.max(delta, 0), MAX_STEP_MS)
    publish()

    if (now - lastActivity >= IDLE_MS) pause('idle')
  }

  function pause(reason) {
    if (paused.value) return

    if (reason === 'idle') {
      accumulatedMs = Math.max(0, accumulatedMs - IDLE_MS)
      publish()
    }
    paused.value      = true
    pauseReason.value = reason
  }

  function resume() {
    if (!paused.value) return

    paused.value      = false
    pauseReason.value = null
    lastTick          = Date.now()
    lastActivity      = lastTick
  }

  function onVisibilityChange() {
    if (document.hidden) {
      // Дописываем то, что накопилось с прошлого тика, и только потом встаём.
      tick()
      pause('hidden')
    } else {
      // Вернулся на вкладку — это и есть действие, в том числе после паузы
      // по бездействию.
      resume()
    }
  }

  function onActivity() {
    lastActivity = Date.now()
    if (paused.value && pauseReason.value === 'idle') resume()
  }

  // Значение из сохранённой сессии (или 0 при сбросе).
  function setElapsed(seconds) {
    accumulatedMs = Math.max(0, Number(seconds) || 0) * 1000
    lastTick      = Date.now()
    lastActivity  = lastTick
    publish()
  }

  function start() {
    lastTick     = Date.now()
    lastActivity = lastTick
    // Вкладку могли открыть сразу в фоне (открыть ссылку в новой вкладке).
    if (document.hidden) pause('hidden')

    interval = setInterval(tick, TICK_MS)
    document.addEventListener('visibilitychange', onVisibilityChange)
    ACTIVITY_EVENTS.forEach(name => window.addEventListener(name, onActivity, { passive: true, capture: true }))
  }

  function stop() {
    clearInterval(interval)
    interval = null
    document.removeEventListener('visibilitychange', onVisibilityChange)
    ACTIVITY_EVENTS.forEach(name => window.removeEventListener(name, onActivity, { capture: true }))
  }

  // Перед отправкой: дописать последний неполный интервал.
  function flush() {
    tick()
  }

  return { elapsed, paused, pauseReason, start, stop, setElapsed, flush }
}
