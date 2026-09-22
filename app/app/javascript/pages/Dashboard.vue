<template>
  <AppLayout>
    <h1 class="dashboard-title">Мой кабинет</h1>

    <div class="tabs" role="tablist">
      <button
        v-for="t in tabs" :key="t.id"
        type="button"
        role="tab"
        class="tabs__item"
        :class="{ 'tabs__item--active': tab === t.id }"
        :aria-selected="tab === t.id"
        @click="selectTab(t.id)"
      >
        {{ t.label }}
      </button>
    </div>

    <section v-if="tab === 'overview'" class="dashboard-stack">
      <div class="dashboard-col dashboard-col--half">
        <h2 class="dashboard-section-title">Статистика</h2>
        <dl class="stat-list">
          <div v-for="s in summaryCards" :key="s.label" class="stat-list__row">
            <dt class="stat-list__label">{{ s.label }}</dt>
            <dd class="stat-list__value">{{ s.value }}</dd>
          </div>
        </dl>
      </div>

      <div class="dashboard-col">
        <h2 class="dashboard-section-title">Сильные темы</h2>
        <template v-if="strongTopics.length">
          <div class="weak-summary">
            <span
              v-for="topic in strongTopics" :key="topic.slug"
              class="weak-summary__tag weak-summary__tag--strong"
              :title="strongTopicTitle(topic)"
            >
              <span
                v-if="topic.color"
                class="weak-summary__dot"
                :style="{ background: topic.color }"
                aria-hidden="true"
              ></span>
              {{ topic.label }}
              <span class="weak-summary__count">{{ topic.correctCount }}</span>
            </span>
          </div>
        </template>
        <p v-else class="dashboard-col__empty">
          Пока рано подводить итоги — пройдите больше тестов, и здесь появятся темы, в которых вы уверенно отвечаете.
        </p>
      </div>

      <div class="dashboard-col">
        <h2 class="dashboard-section-title">Слабые темы</h2>
        <template v-if="weakTopics.length">
          <div class="weak-summary">
            <!-- Фон кодирует число ошибок, точка слева — саму тему. -->
            <Link
              v-for="topic in weakTopics" :key="topic.slug"
              :href="`/practice/topic/${topic.slug}`"
              class="weak-summary__tag"
              :class="`weak-summary__tag--${topic.level}`"
              :title="topicTitle(topic)"
            >
              <span
                v-if="topic.color"
                class="weak-summary__dot"
                :style="{ background: topic.color }"
                aria-hidden="true"
              ></span>
              {{ topic.label }}
              <span v-if="topic.wrongCount > 1" class="weak-summary__count">{{ topic.wrongCount }}</span>
            </Link>
          </div>
        </template>
        <p v-else class="dashboard-col__empty">
          Пока нечего подтягивать — пройдите тест, и слабые темы появятся здесь.
        </p>
      </div>

      <div class="dashboard-col">
        <h2 class="dashboard-section-title">Рекомендуемые тесты</h2>
        <div v-if="recommendedTests.length" class="recommended-tests recommended-tests--grid">
          <Link
            v-for="t in recommendedTests" :key="t.slug"
            :href="`/tests/${t.slug}`"
            class="recommended-tests__item"
          >
            <span class="recommended-tests__title">{{ t.title }}</span>
            <span v-if="t.topics?.length" class="recommended-tests__topics">{{ t.topics.join(', ') }}</span>
            <span v-if="t.completed" class="recommended-tests__badge">пройден</span>
          </Link>
        </div>
        <p v-else class="dashboard-col__empty">
          Пока нет рекомендаций — они появятся, когда наберутся слабые темы.
        </p>
      </div>

      <div class="dashboard-col">
        <h2 class="dashboard-section-title">История прохождений</h2>

        <div v-if="attempts.length" class="attempts-list">
          <!-- Ведёт на страницу результата этой попытки: там разбор ответов
               и слабые темы — отдельное окно дублировало бы её. -->
          <Link
            v-for="a in attempts" :key="a.id"
            :href="`/tests/${a.testSlug}/runs/${a.id}`"
            class="attempt-row"
          >
            <div>
              <p class="attempt-row__title">
                {{ a.testTitle }}
                <!-- Тренировка идёт по части вопросов, поэтому счёт вида 3/3
                     рядом с обычными попытками иначе читался бы как полный тест. -->
                <span v-if="a.weakOnly" class="attempt-row__badge">тренировка</span>
              </p>
              <p class="attempt-row__date">{{ formatDate(a.completedAt) }}</p>
            </div>
            <div class="attempt-row__score-wrap">
              <span class="attempt-row__count">{{ a.correctCount }}/{{ a.totalQuestions }}</span>
              <span class="attempt-row__score" :style="{ color: scoreColor(a.score) }">{{ a.score.toFixed(0) }}%</span>
            </div>
          </Link>

          <button
            v-if="hasMoreAttemptsRef"
            type="button"
            class="load-more"
            :disabled="loadingAttempts"
            @click="loadMoreAttempts"
          >
            {{ loadingAttempts ? 'Загружаем…' : `Показать ещё ${pageSize}` }}
          </button>
        </div>

        <div v-else class="dashboard-empty">
          <p>Вы ещё не прошли ни одного теста</p>
          <Link href="/" class="btn btn-sm btn-primary dashboard-empty__btn">
            К тестам
          </Link>
        </div>
      </div>
    </section>

    <section v-else-if="tab === 'bookmarks'">
      <h2 class="dashboard-section-title">Избранные вопросы</h2>

      <div v-if="bookmarks.length" class="bookmarks-list">
        <!-- Удалённая закладка не исчезает сразу: пока страница открыта, её
             можно вернуть — удаление в один клик иначе необратимо. -->
        <div
          v-for="b in bookmarks" :key="b.id"
          class="bookmark-card"
          :class="{ 'bookmark-card--removed': removedIds.has(b.id) }"
        >
          <div class="bookmark-card__header">
            <span class="bookmark-card__test">{{ b.testTitle }}</span>
            <button
              v-if="removedIds.has(b.id)"
              type="button"
              class="bookmark-restore"
              @click="restoreBookmark(b)"
            >
              Вернуть
            </button>
            <button
              v-else
              type="button"
              class="bookmark-remove"
              title="Убрать из избранного"
              @click="removeBookmark(b)"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
              </svg>
            </button>
          </div>
          <p class="bookmark-card__text">{{ b.questionText }}</p>

          <div v-if="b.typeField === 'code_challenge'" class="bookmark-code">
            <template v-if="highlightModeFor(b)">
              <div class="bookmark-code__lines">
                <div
                  v-for="(line, i) in highlightLinesFor(b)" :key="i"
                  class="bookmark-code-line"
                  :class="{ 'bookmark-code-line--correct': highlightModeFor(b).correctLines.includes(String(i + 1)) }"
                ><code>{{ line || ' ' }}</code></div>
              </div>
              <p v-if="highlightModeFor(b).hint" class="bookmark-card__explanation">{{ highlightModeFor(b).hint }}</p>
            </template>
            <p v-else class="bookmark-card__explanation">
              Этот тип вопроса пока нельзя показать в избранном — откройте его в тесте «{{ b.testTitle }}».
            </p>
          </div>
          <div v-else class="bookmark-card__options">
            <div
              v-for="opt in b.options" :key="opt.id"
              class="bookmark-option"
              :class="b.correctIds.includes(opt.id) ? 'bookmark-option--correct' : ''"
            >
              {{ opt.text }}
            </div>
          </div>
          <p v-if="b.explanation" class="bookmark-card__explanation">{{ b.explanation }}</p>
        </div>

        <button
          v-if="hasMoreBookmarksRef"
          type="button"
          class="load-more"
          :disabled="loadingBookmarks"
          @click="loadMoreBookmarks"
        >
          {{ loadingBookmarks ? 'Загружаем…' : `Показать ещё ${pageSize}` }}
        </button>
      </div>

      <div v-else class="dashboard-empty dashboard-empty--sm">
        <p>Нет избранных вопросов</p>
        <p class="dashboard-empty__hint">Добавляйте вопросы в избранное во время прохождения теста</p>
      </div>
    </section>

    <section v-else-if="tab === 'profile'" class="profile">
      <h2 class="dashboard-section-title">Профиль</h2>
      <p class="profile__intro">
        Ваши данные, которые могут увидеть остальные при прохождении тестов
      </p>

      <div class="profile__card">
        <div class="profile__avatar-block">
          <img v-if="avatarUrl" :src="avatarUrl" alt="" class="profile__avatar" />
          <GeneratedAvatar v-else class="profile__avatar" :seed="avatarSeedInput" :name="nameInput" />

          <div class="profile__avatar-actions">
            <button
              type="button"
              class="profile__link-btn"
              :disabled="!!avatarUrl"
              :title="avatarUrl ? 'Недоступно: сейчас показывается ваше фото, а не сгенерированный аватар' : ''"
              @click="randomizeAvatar"
            >
              Сменить цвет
            </button>
            <button
              v-for="p in avatarProviders" :key="p.provider"
              type="button"
              class="profile__link-btn"
              @click="adoptAvatar(p.provider)"
            >
              Взять из {{ providerLabel(p.provider) }}
            </button>
          </div>
        </div>

        <div class="profile__fields">
          <label class="profile__label" for="profile-name">Имя</label>
          <input
            id="profile-name"
            v-model.trim="nameInput"
            type="text"
            maxlength="60"
            class="profile__input"
            placeholder="Как вас называть"
          />
          <div class="profile__name-actions">
            <button type="button" class="profile__link-btn" @click="randomizeName">
              Сменить имя
            </button>
            <button
              v-for="p in nameProviders" :key="p.provider"
              type="button"
              class="profile__link-btn"
              @click="adoptName(p.provider)"
            >
              Взять из {{ providerLabel(p.provider) }}
            </button>
          </div>

          <label class="profile__label" for="profile-avatar">Ссылка на аватар</label>
          <input
            id="profile-avatar"
            v-model.trim="avatarInput"
            type="url"
            class="profile__input"
            placeholder="https://…"
          />

          <p class="profile__email">{{ currentUser?.email }}</p>
          <p v-if="currentUser?.providers?.length" class="profile__providers">
            Вход через: {{ currentUser.providers.join(', ') }}
          </p>
        </div>
      </div>

      <div class="profile__actions">
        <button class="btn btn-primary" :disabled="!profileChanged || !nameInput.trim() || savingProfile" @click="saveProfile">
          {{ savingProfile ? 'Сохранение…' : 'Сохранить' }}
        </button>
        <button
          v-if="profileChanged"
          type="button"
          class="profile__cancel-btn"
          :disabled="savingProfile"
          @click="cancelProfileChanges"
        >
          Отмена
        </button>
        <span v-if="!profileChanged && !savingProfile" class="settings__hint">Изменений нет</span>
      </div>
    </section>
  </AppLayout>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { Link, usePage, router } from '@inertiajs/vue3'
import axios from 'axios'
import AppLayout from '@/components/AppLayout.vue'
import GeneratedAvatar from '@/components/GeneratedAvatar.vue'
import { detectAnimal } from '@/assets/animalIconPaths'

const props = defineProps({
  attempts:           Array,
  stats:              Object,
  bookmarks:          { type: Array, default: () => [] },
  weakTopics:         { type: Array, default: () => [] },
  strongTopics:       { type: Array, default: () => [] },
  recommendedTests:   { type: Array, default: () => [] },
  identities:         { type: Array, default: () => [] },
  hasMoreAttempts:    { type: Boolean, default: false },
  hasMoreBookmarks:   { type: Boolean, default: false },
  pageSize:           { type: Number, default: 5 },
})

const page = usePage()
const currentUser = computed(() => page.props.currentUser)

const tabs = [
  { id: 'overview',  label: 'Тесты' },
  { id: 'bookmarks', label: 'Избранное' },
  { id: 'profile',   label: 'Профиль' },
]
const tabIds = tabs.map(t => t.id)

// Вкладка живёт в хэше (#profile), а не только в памяти компонента: так
// обновление страницы и кнопка «назад» возвращают туда же, а не сбрасывают
// на первую вкладку — без похода на сервер, хэш меняет только браузер.
function tabFromHash() {
  const id = window.location.hash.slice(1)
  return tabIds.includes(id) ? id : 'overview'
}

const tab = ref(tabFromHash())

function selectTab(id) {
  tab.value = id
  window.location.hash = id
}

function onHashChange() { tab.value = tabFromHash() }
onMounted(() => window.addEventListener('hashchange', onHashChange))
onUnmounted(() => window.removeEventListener('hashchange', onHashChange))

const bookmarks = ref(props.bookmarks)

// Списки догружаются страницами, поэтому живут в локальном состоянии,
// а не читаются из пропов напрямую.
const attempts           = ref(props.attempts ?? [])
const hasMoreAttemptsRef = ref(props.hasMoreAttempts)
const hasMoreBookmarksRef = ref(props.hasMoreBookmarks)
const loadingAttempts    = ref(false)
const loadingBookmarks   = ref(false)

async function loadMoreAttempts() {
  if (loadingAttempts.value) return
  loadingAttempts.value = true
  try {
    const { data } = await axios.get('/dashboard/attempts', {
      params: { offset: attempts.value.length },
    })
    attempts.value = [...attempts.value, ...data.attempts]
    hasMoreAttemptsRef.value = data.hasMore
  } catch {} finally {
    loadingAttempts.value = false
  }
}

async function loadMoreBookmarks() {
  if (loadingBookmarks.value) return
  loadingBookmarks.value = true
  try {
    const { data } = await axios.get('/dashboard/bookmarks', {
      params: { offset: bookmarks.value.length },
    })
    bookmarks.value = [...bookmarks.value, ...data.bookmarks]
    hasMoreBookmarksRef.value = data.hasMore
  } catch {} finally {
    loadingBookmarks.value = false
  }
}

// Избранное умеет показывать только code_challenge в режиме highlight —
// это единственный режим, где ответ выражается статично (подсветкой нужных
// строк), без интерактивного ввода. Для fill/select/fix показываем заглушку.
function highlightModeFor(b) {
  return b.modes?.highlight ?? null
}

function highlightLinesFor(b) {
  return (highlightModeFor(b)?.code ?? '').trimEnd().split('\n')
}


// В тултипе описание темы и число ошибок: на самом теге число показано
// только при повторных промахах, чтобы не зашумлять строку единицами.
function topicTitle(topic) {
  const parts = []
  if (topic.description) parts.push(topic.description)
  // Из каких тестов набралась тема — иначе непонятно, откуда она взялась.
  if (topic.sources?.length) {
    parts.push(topic.sources.map(s => `${s.title}: ${s.wrongCount}`).join(', '))
  } else if (topic.wrongCount > 0) {
    parts.push(`Ошибок: ${topic.wrongCount}`)
  }
  return parts.join(' • ')
}

const strongTopics = computed(() => props.strongTopics)

function strongTopicTitle(topic) {
  const parts = []
  if (topic.description) parts.push(topic.description)
  parts.push(`Верно: ${topic.correctCount} из ${topic.totalCount}`)
  return parts.join(' • ')
}

// Лучший балл убран намеренно: у любого, кто прошёл пару тестов, там 100%,
// и строка ничего не сообщает.
const summaryCards = computed(() => [
  { label: 'Всего попыток',   value: props.stats.totalAttempts },
  { label: 'Тестов пройдено', value: props.stats.testsCompleted },
  { label: 'Средний балл',    value: props.stats.avgScore.toFixed(1) + '%' },
])

// Карточка остаётся в списке, помеченная как удалённая: из БД запись уже
// убрана, но вернуть её можно, пока страница не перезагружена.
const removedIds = ref(new Set())

async function removeBookmark(b) {
  try {
    await axios.delete('/bookmarks', { data: { question_id: b.questionId } })
    removedIds.value = new Set(removedIds.value).add(b.id)
  } catch {}
}

async function restoreBookmark(b) {
  try {
    await axios.post('/bookmarks', { question_id: b.questionId })
    const next = new Set(removedIds.value)
    next.delete(b.id)
    removedIds.value = next
  } catch {}
}

function scoreColor(s) {
  if (s >= 80) return '#10B981'
  if (s >= 50) return '#F59E0B'
  return '#EF4444'
}

function formatDate(d) {
  return new Date(d).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
}

// Профиль: имя и аватар редактируются локально и уходят PATCH-ом на /profile.
const nameInput       = ref(currentUser.value?.name ?? '')
const avatarInput     = ref(currentUser.value?.avatarUrl ?? '')
const avatarSeedInput = ref(currentUser.value?.avatarSeed || currentUser.value?.email || 'default')
const savingProfile   = ref(false)

// Только avatarInput, без запасного currentUser.avatarUrl: очистка поля
// должна сразу вернуть сгенерированный аватар, а не показывать старое
// сохранённое фото, пока не нажато «Сохранить».
const avatarUrl = computed(() => avatarInput.value)

// Цвет пересчитывается только когда меняется само распознанное животное
// (появилось, исчезло или сменилось на другое) — а не на каждую напечатанную
// букву, иначе фон мигал бы во время ввода имени.
watch(() => detectAnimal(nameInput.value), (next, prev) => {
  if (next !== prev) avatarSeedInput.value = Math.random().toString(36).slice(2)
})

const profileChanged = computed(() => {
  const initialName   = currentUser.value?.name ?? ''
  const initialAvatar = currentUser.value?.avatarUrl ?? ''
  const initialSeed   = currentUser.value?.avatarSeed || currentUser.value?.email || 'default'
  return nameInput.value !== initialName
    || avatarInput.value !== initialAvatar
    || avatarSeedInput.value !== initialSeed
})

// Возвращает поля профиля к тому, что сейчас сохранено на сервере —
// отменяет любой несохранённый ввод, включая случайное имя/цвет и вставленный URL.
function cancelProfileChanges() {
  nameInput.value = currentUser.value?.name ?? ''
  avatarInput.value = currentUser.value?.avatarUrl ?? ''
  avatarSeedInput.value = currentUser.value?.avatarSeed || currentUser.value?.email || 'default'
}

function saveProfile() {
  if (savingProfile.value) return
  savingProfile.value = true

  // На /dashboard, а не /profile: форма профиля живёт на этой странице, и
  // Inertia запоминает URL ответа как адрес браузера — на другом маршруте
  // адресная строка переключилась бы туда, а её обновление давало бы 404.
  //
  // Хэш (#profile) передаём в самом целевом URL визита, а не восстанавливаем
  // постфактум: Inertia сама переносит хэш из URL запроса в page.url, если
  // ответ сервера пришёл без хэша на тот же путь (см. setPage/visit в
  // @inertiajs/core — w.hash && !V.hash && тот же путь → V.hash = w.hash).
  // Без хэша в целевом URL это условие не срабатывает, и адресная строка
  // остаётся без него.
  router.patch(`/dashboard${window.location.hash}`, {
    name: nameInput.value,
    avatar_url: avatarInput.value,
    avatar_seed: avatarSeedInput.value,
  }, {
    preserveScroll: true,
    // Ключ в snake_case: сервер отдаёт проп как current_user (см.
    // ApplicationController#current_user_props), camelCase — только
    // клиентское преобразование в application.js. С неверным ключом here
    // partial reload молча отдавал бы ПОЛНЫЙ дашборд вместо одного пропа.
    only: [ 'current_user' ],
    onFinish: () => { savingProfile.value = false }
  })
}

const PROVIDER_LABELS = { google_oauth2: 'Google', github: 'GitHub' }
function providerLabel(provider) {
  return PROVIDER_LABELS[provider] || provider
}

// Кнопка «Взять из …» показывается только для провайдеров, реально
// вернувших это поле — иначе кнопка была бы бесполезной заглушкой.
const nameProviders   = computed(() => props.identities.filter(i => i.rawName))
const avatarProviders = computed(() => props.identities.filter(i => i.rawAvatarUrl))

// Тот же список, что в RandomIdentity (app/services/random_identity.rb) —
// имя меняется мгновенно, без похода на сервер и без прогресс-бара Inertia
// поверх страницы. Сохраняется, как и обычный ввод, только по «Сохранить».
const ADJECTIVES = [
  'Быстрый', 'Смелый', 'Тихий', 'Ловкий', 'Хитрый', 'Весёлый', 'Сонный', 'Шустрый', 'Мудрый', 'Дерзкий',
  'Игривый', 'Спокойный', 'Яркий', 'Задумчивый', 'Отважный', 'Незаметный', 'Проворный', 'Добрый',
  'Загадочный', 'Бодрый', 'Одинокий', 'Затаившийся', 'Коварный', 'Летучий', 'Ворчливый',
  'Рассеянный', 'Скользкий', 'Наглый', 'Пугливый', 'Неуловимый', 'Ленивый', 'Взъерошенный',
  'Голодный', 'Молчаливый', 'Своенравный', 'Упрямый', 'Внимательный', 'Терпеливый', 'Насторожённый',
]
const ANIMALS = [
  'Аллигатор', 'Муравьед', 'Броненосец', 'Тур', 'Аксолотль', 'Барсук', 'Мышь', 'Бизон',
  'Верблюд', 'Капибара', 'Хамелеон', 'Гепард', 'Шиншилла', 'Бурундук', 'Чупакабра', 'Баклан',
  'Койот', 'Ворон', 'Динго', 'Динозавр', 'Дельфин', 'Утка', 'Слон', 'Хорёк', 'Лис', 'Лягушка', 'Жираф',
  'Суслик', 'Гризли', 'Ёж', 'Бегемот', 'Гиена', 'Козерог', 'Ифрит', 'Игуана', 'Шакал', 'Джекалоп',
  'Кенгуру', 'Коала', 'Кракен', 'Лемур', 'Леопард', 'Лигр', 'Лама', 'Ламантин', 'Норка', 'Обезьяна',
  'Лось', 'Нарвал', 'Орангутан', 'Выдра', 'Панда', 'Пингвин', 'Утконос', 'Питон', 'Квагга', 'Кролик',
  'Енот', 'Носорог', 'Овца', 'Землеройка', 'Скунс', 'Лори', 'Белка', 'Тигр', 'Черепаха', 'Морж',
  'Волк', 'Росомаха', 'Вомбат', 'Сова', 'Бобр', 'Кот', 'Тукан',
]

// Существительные женского рода — прилагательное перед ними ставится в
// женском роде ("Хитрая Лиса", не "Хитрый Лиса"). Признак "оканчивается на
// -а/-я" покрывает почти все случаи автоматически; "Мышь" — исключение.
const FEMININE_ANIMALS = new Set([...ANIMALS.filter(a => /[ая]$/.test(a)), 'Мышь'])

// Мужская форма на -кий/-гий/-хий/-жий/-чий/-ший/-щий даёт -ая (Тихий →
// Тихая); на -ый/-ой — тоже -ая. "-ийся" (причастие вроде "Затаившийся") —
// отдельно, обычное правило его не покрывает: "ий" там не в конце слова.
function feminize(word) {
  if (/[гкхжчшщ]ийся$/.test(word)) return word.replace(/ийся$/, 'аяся')
  if (/[гкхжчшщ]ий$/.test(word)) return word.replace(/ий$/, 'ая')
  if (word.endsWith('ый')) return word.replace(/ый$/, 'ая')
  if (word.endsWith('ой')) return word.replace(/ой$/, 'ая')
  return word
}

function randomName() {
  const animal = ANIMALS[Math.floor(Math.random() * ANIMALS.length)]
  const rawAdjective = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)]
  const adjective = FEMININE_ANIMALS.has(animal) ? feminize(rawAdjective) : rawAdjective
  return `${adjective} ${animal}`
}

function randomizeName() {
  nameInput.value = randomName()
}

// Данные уже пришли в props.identities вместе со страницей — незачем
// ходить на сервер за тем, что и так лежит на клиенте.
function adoptName(provider) {
  const identity = props.identities.find(i => i.provider === provider)
  if (identity?.rawName) nameInput.value = identity.rawName
}

// Новый случайный seed — мгновенно на клиенте, как и «Случайное имя»: без
// похода на сервер и без прогресс-бара Inertia. Сбрасывает avatarInput,
// иначе выбранное раньше фото провайдера продолжало бы показываться поверх
// нового сгенерированного аватара.
function randomizeAvatar() {
  avatarInput.value = ''
  avatarSeedInput.value = Math.random().toString(36).slice(2)
}

// Данные уже пришли в props.identities вместе со страницей — незачем
// ходить на сервер за тем, что и так лежит на клиенте.
function adoptAvatar(provider) {
  const identity = props.identities.find(i => i.provider === provider)
  if (identity?.rawAvatarUrl) avatarInput.value = identity.rawAvatarUrl
}
</script>

<style scoped>
.dashboard-title {
  font-size: 1.5rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
}

.dashboard-section-title {
  font-weight: 600;
  font-size: 1.125rem;
  margin-bottom: 1rem;
}

.tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  margin-bottom: 1.75rem;
  border-bottom: 1px solid #F3F4F6;
}

.tabs__item {
  padding: 0.625rem 0.875rem;
  border: none;
  background: none;
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  color: #6B7280;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}

.tabs__item:hover {
  color: #4F63F5;
}

.tabs__item--active {
  color: #4F63F5;
  border-bottom-color: #4F63F5;
}

.attempts-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.attempt-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem;
  color: inherit;
  text-decoration: none;
}

.attempt-row:hover {
  background: #F7F8FA;
  border-color: #4F63F5;
}

.attempt-row:hover .attempt-row__title {
  color: #4F63F5;
}

.attempt-row__title {
  font-weight: 500;
  font-size: 0.875rem;
}

/* Пометка, а не акцент: приглушённая, как дата и счётчик рядом. */
.attempt-row__badge {
  display: inline-block;
  margin-left: 0.375rem;
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #9CA3AF;
  font-size: 0.6875rem;
  font-weight: 600;
  vertical-align: middle;
}

.attempt-row__date {
  font-size: 0.75rem;
  color: #9CA3AF;
  margin-top: 0.125rem;
}

.attempt-row__score-wrap {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.attempt-row__count {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.attempt-row__score {
  font-weight: 700;
  font-size: 1.125rem;
}

.dashboard-empty {
  text-align: center;
  padding: 3rem 0;
  color: #9CA3AF;
}

.dashboard-empty--sm {
  padding: 2.5rem 0;
}

.dashboard-empty__btn {
  margin-top: 1rem;
}

.dashboard-empty__hint {
  font-size: 0.75rem;
  margin-top: 0.25rem;
}

.bookmarks-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.bookmark-card {
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: 0.75rem;
  padding: 1.25rem;
}

.bookmark-card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.bookmark-card__test {
  font-size: 0.75rem;
  color: #6366F1;
  font-weight: 500;
}

.bookmark-remove {
  background: none;
  border: none;
  cursor: pointer;
  color: #6366F1;
  padding: 0.125rem;
  display: flex;
  align-items: center;
  opacity: 0.7;
  transition: opacity 0.15s;
}

.bookmark-remove:hover {
  opacity: 1;
}

.bookmark-card__text {
  font-size: 0.9rem;
  font-weight: 500;
  line-height: 1.5;
  margin-bottom: 0.75rem;
}

.bookmark-card__options {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  margin-bottom: 0.75rem;
}

.bookmark-option {
  font-size: 0.8rem;
  color: #6B7280;
  padding: 0.35rem 0.6rem;
  border-radius: 0.4rem;
  background: #F9FAFB;
}

.bookmark-option--correct {
  background: #ECFDF5;
  color: #059669;
  font-weight: 500;
}

.bookmark-card__explanation {
  font-size: 0.8rem;
  color: #9CA3AF;
  border-top: 1px solid #F3F4F6;
  padding-top: 0.6rem;
  margin-top: 0.25rem;
}

.bookmark-code {
  margin-bottom: 0.75rem;
}

.bookmark-code__lines {
  background: #F3F4F6;
  border-radius: 0.75rem;
  padding: 0.5rem 0;
  overflow-x: auto;
}

.bookmark-code-line {
  padding: 0 1.25rem;
  border-left: 3px solid transparent;
  min-height: 1.6em;
  font-family: 'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace;
  font-size: 0.75rem;
  line-height: 1.6;
  color: #374151;
  white-space: pre;
}

.bookmark-code-line code {
  font-family: inherit;
  font-size: inherit;
  background: none;
  color: inherit;
}

.bookmark-code-line--correct {
  background: rgba(16, 185, 129, 0.08);
  border-left-color: #10B981;
  color: #059669;
  font-weight: 500;
}

/* Слабые темы и рекомендации: та же карточка и та же градация,
   что в отчёте после теста, чтобы язык интерфейса не разъезжался. */
.weak-summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1rem;
}

.weak-summary__tag {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.1875rem 0.625rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #4B5563;
  font-size: 0.75rem;
  font-weight: 600;
}

.weak-summary__tag--low {
  background: #F3F4F6;
  color: #4B5563;
}

.weak-summary__tag--medium {
  background: #FEF3C7;
  color: #92400E;
}

.weak-summary__tag--high {
  background: #FEE2E2;
  color: #991B1B;
}

.weak-summary__tag--strong {
  background: #D1FAE5;
  color: #065F46;
}

.weak-summary__dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  flex-shrink: 0;
}

.weak-summary__count {
  padding: 0 0.3125rem;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.65);
  font-size: 0.6875rem;
  font-weight: 700;
}

.recommended-tests {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

/* Отдельная секция во всю ширину: раскладываем карточки в две колонки,
   а не одной строкой, как в узкой колонке рядом с темами. */
.recommended-tests--grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
}

@media (max-width: 48rem) {
  .recommended-tests--grid {
    grid-template-columns: 1fr;
  }
}

.recommended-tests__item {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.875rem;
  border-radius: 0.5rem;
  background: #fff;
  border: 1px solid #E5E7EB;
  color: #374151;
  font-size: 0.8125rem;
  font-weight: 500;
  text-decoration: none;
}

.recommended-tests__item:hover {
  background: #F7F8FA;
  border-color: #4F63F5;
  color: #4F63F5;
}

/* Уже пройденные показываем последними и помечаем, чтобы не выглядели новыми. */
.recommended-tests__badge {
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  background: #F3F4F6;
  color: #9CA3AF;
  font-size: 0.6875rem;
  font-weight: 600;
}

.weak-summary__tag {
  text-decoration: none;
  cursor: pointer;
}

.weak-summary__tag:hover {
  filter: brightness(0.95);
}

/* Сильные темы — не ссылки: тренировать уже освоенную тему незачем,
   поэтому тег не должен выглядеть кликабельным. */
.weak-summary__tag--strong {
  cursor: default;
}

.weak-summary__tag--strong:hover {
  filter: none;
}

.recommended-tests__topics {
  color: #9CA3AF;
  font-size: 0.75rem;
}

/* Секции вкладки «Тесты» идут одна под другой; отступ между ними —
   на самих секциях (.dashboard-col), а не здесь. */
.dashboard-stack {
  display: flex;
  flex-direction: column;
}

.dashboard-col__empty {
  font-size: 0.8125rem;
  color: #9CA3AF;
  line-height: 1.5;
}

/* Подпись слева, значение справа — плотнее и читается быстрее плиток.
   Карточка такая же, как у строк истории, чтобы секции были однородны. */
.stat-list {
  margin: 0;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 0.25rem 1rem;
}

.stat-list__row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.625rem 0;
  border-bottom: 1px solid #F3F4F6;
}

.stat-list__row:last-child {
  border-bottom: none;
}

.stat-list__label {
  font-size: 0.8125rem;
  color: #6B7280;
}

.stat-list__value {
  margin: 0;
  font-size: 0.9375rem;
  font-weight: 600;
  color: #111827;
  text-align: right;
}

/* Секции идут друг под другом с равным отступом; последней он не нужен. */
.dashboard-col {
  min-width: 0;
  margin-bottom: 2rem;
}

.dashboard-col:last-child {
  margin-bottom: 0;
}

/* Статистика — в половину ширины секции, а не во всю. */
.dashboard-col--half {
  max-width: calc(50% - 0.5rem);
}

@media (max-width: 48rem) {
  .dashboard-col--half {
    max-width: none;
  }
}

/* Удалённая, но ещё возвращаемая закладка: видно, что её больше нет,
   но карточка остаётся на месте, чтобы список не прыгал. */
.bookmark-card--removed {
  opacity: 0.55;
}

.bookmark-card--removed .bookmark-card__text,
.bookmark-card--removed .bookmark-card__options,
.bookmark-card--removed .bookmark-code {
  text-decoration: line-through;
  text-decoration-color: #D1D5DB;
}

.bookmark-restore {
  padding: 0.125rem 0.5rem;
  border: 1px solid #C7CDFA;
  border-radius: 999px;
  background: #fff;
  color: #4F63F5;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.bookmark-restore:hover {
  background: #EEF0FF;
}

/* Догрузка следующей страницы списка. */
.load-more {
  align-self: center;
  margin-top: 0.25rem;
  padding: 0.5rem 1rem;
  border: 1px solid #E5E7EB;
  border-radius: 0.5rem;
  background: #fff;
  color: #4B5563;
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
}

.load-more:hover:not(:disabled) {
  background: #F7F8FA;
  border-color: #4F63F5;
  color: #4F63F5;
}

.load-more:disabled {
  opacity: 0.6;
  cursor: default;
}

.profile__intro {
  font-size: 0.8125rem;
  color: #6B7280;
  max-width: 32rem;
  margin-bottom: 1rem;
  line-height: 1.5;
}

.profile__card {
  display: flex;
  gap: 1.25rem;
  align-items: flex-start;
  background: #fff;
  border: 1px solid #F3F4F6;
  box-shadow: 0 1px 3px rgba(0,0,0,0.07);
  border-radius: var(--rounded-box, 0.75rem);
  padding: 1.25rem;
  max-width: 32rem;
}

.profile__avatar-block {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.profile__avatar {
  width: 4rem;
  height: 4rem;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
}

.profile__avatar-actions,
.profile__name-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.profile__avatar-actions {
  justify-content: center;
}

.profile__name-actions {
  margin-top: 0.125rem;
}

.profile__link-btn {
  padding: 0.1875rem 0.5rem;
  border: 1px solid #E5E7EB;
  border-radius: 999px;
  background: #fff;
  color: #4F63F5;
  font-size: 0.6875rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}

.profile__link-btn:hover:not(:disabled) {
  background: #EEF0FF;
  border-color: #C7CDFA;
}

.profile__link-btn:disabled {
  opacity: 0.5;
  cursor: default;
}

.profile__fields {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  flex: 1;
  min-width: 0;
}

.profile__label {
  font-size: 0.75rem;
  color: #6B7280;
  font-weight: 500;
  margin-top: 0.5rem;
}

.profile__label:first-child {
  margin-top: 0;
}

.profile__input {
  padding: 0.5rem 0.625rem;
  border: 1px solid #E5E7EB;
  border-radius: 0.5rem;
  font-size: 0.875rem;
}

.profile__input:focus {
  outline: none;
  border-color: #4F63F5;
}

.profile__email {
  font-size: 0.8125rem;
  color: #9CA3AF;
  margin-top: 0.5rem;
}

.profile__providers {
  font-size: 0.75rem;
  color: #9CA3AF;
}

.profile__actions {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  margin-top: 1rem;
}

.profile__cancel-btn {
  padding: 0;
  border: none;
  background: none;
  color: #6B7280;
  font-size: 0.875rem;
  cursor: pointer;
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.profile__cancel-btn:hover:not(:disabled) {
  color: #374151;
}

.profile__cancel-btn:disabled {
  opacity: 0.5;
  cursor: default;
}

.settings__hint {
  font-size: 0.8125rem;
  color: #9CA3AF;
}
</style>
