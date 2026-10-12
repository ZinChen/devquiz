import { ref, readonly, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'

// Live-активность (#10): кто сейчас проходит какой тест и на каком вопросе.
// Одно соединение и одна подписка на всё приложение — карточки списка, экран
// прохождения и страница теста берут данные из общего снимка. Подписка
// держится по счётчику использований: закрылся последний компонент — отписка.

const HEARTBEAT_MS = 30_000

const activity = ref({})   // { slug: [{ key, name, avatarUrl, avatarSeed, questionId, userId, achievementsCount }] }
const me       = ref(null)

let consumer      = null
let subscription  = null
let users         = 0
let joined        = null   // { testSlug, questionId } — что объявлять заново после реконнекта
let heartbeat     = null

function camelizeViewer(v) {
  return {
    key:        v.key,
    name:       v.name,
    avatarUrl:  v.avatar_url,
    avatarSeed: v.avatar_seed,
    questionId: v.question_id,
    userId:     v.user_id,
    achievementsCount: v.achievements_count,
  }
}

function applySnapshot(data) {
  if (data.me !== undefined) me.value = data.me
  activity.value = Object.fromEntries(
    Object.entries(data.activity || {}).map(([slug, list]) => [slug, list.map(camelizeViewer)])
  )
}

function announce() {
  if (joined) subscription?.perform('join', { test_slug: joined.testSlug, question_id: joined.questionId })
}

function connect() {
  consumer     ??= createConsumer()
  subscription   = consumer.subscriptions.create('ActivityChannel', {
    received: applySnapshot,
    // После обрыва сервер успел забыть нас (unsubscribed) — объявляемся заново.
    connected: announce,
  })
}

function disconnect() {
  clearInterval(heartbeat)
  heartbeat = null
  subscription?.unsubscribe()
  subscription = null
  consumer?.disconnect()
  consumer = null
  joined   = null
  activity.value = {}
  me.value = null
}

export function useActivity() {
  if (users++ === 0) connect()

  onUnmounted(() => {
    if (--users === 0) disconnect()
  })

  // Объявить, что проходим тест. Вызывать один раз на странице прохождения.
  function join(testSlug, questionId = null) {
    joined = { testSlug, questionId }
    announce()
    clearInterval(heartbeat)
    heartbeat = setInterval(announce, HEARTBEAT_MS)
  }

  function focus(questionId) {
    if (!joined) return
    joined.questionId = questionId
    subscription?.perform('focus', { test_slug: joined.testSlug, question_id: questionId })
  }

  function leave() {
    if (!joined) return
    subscription?.perform('leave', { test_slug: joined.testSlug })
    clearInterval(heartbeat)
    heartbeat = null
    joined = null
  }

  return { activity: readonly(activity), me: readonly(me), join, focus, leave }
}
