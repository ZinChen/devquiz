<template>
  <div class="tag-picker">
    <div class="tag-picker__categories">
      <button
        v-for="cat in visibleCategories" :key="cat.tag"
        @click="toggleCategory(cat.tag)"
        class="category-tile"
        :class="{ 'category-tile--active': modelValue.includes(cat.tag) }"
        :title="cat.description || undefined"
      >
        <span class="category-tile__title">{{ cat.title }}</span>
        <span v-if="cat.description" class="category-tile__description">{{ cat.description }}</span>
        <!-- Бейдж внизу карточки: при равной высоте плиток в ряду он стоит на
             одной линии у всех, а не гуляет вслед за длиной описания. -->
        <span v-if="hasCounts" class="category-tile__count">{{ testsLabel(countOf(cat.tag)) }}</span>
      </button>
    </div>

    <!-- Вторая ступень: подтеги только выбранных категорий, уточнение необязательное. -->
    <Transition name="tag-picker-children">
      <div v-if="availableChildren.length > 0" class="tag-picker__children">
        <p class="tag-picker__children-hint">Снимите лишнее, если что-то не интересно:</p>
        <div class="tag-picker__children-list">
          <TagTip
            v-for="child in availableChildren" :key="child"
            :text="descriptions[child] || ''"
          >
            <button
              @click="toggleChild(child)"
              class="child-tag"
              :class="{ 'child-tag--active': modelValue.includes(child) }"
            >
              {{ child }}<span v-if="hasCounts" class="child-tag__count">{{ countOf(child) }}</span>
            </button>
          </TagTip>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import TagTip from '@/components/TagTip.vue'
import { testsLabel } from '@/utils/pluralize'

const props = defineProps({
  modelValue:   { type: Array,  default: () => [] },
  categories:   { type: Array,  default: () => [] },
  descriptions: { type: Object, default: () => ({}) },
  // Сколько тестов стоит за плиткой и подтегом (см. TagTaxonomy#tag_counts).
  // Без счётчиков (пустой объект) всё показывается как раньше, без цифр.
  counts:       { type: Object, default: () => ({}) },
})

const emit = defineEmits(['update:modelValue'])

const hasCounts = computed(() => Object.keys(props.counts).length > 0)
const countOf = tag => props.counts[tag] ?? 0

// Плитки по убыванию числа тестов (при равенстве — в порядке таксономии, сорт
// стабильный); плитка и подтег без единого теста не показываются: клик по ним
// вёл бы в пустую выдачу.
const visibleCategories = computed(() => {
  if (!hasCounts.value) return props.categories
  return props.categories
    .filter(cat => countOf(cat.tag) > 0)
    .sort((a, b) => countOf(b.tag) - countOf(a.tag))
})

const availableChildren = computed(() =>
  visibleCategories.value
    .filter(cat => props.modelValue.includes(cat.tag))
    .flatMap(cat => cat.children || [])
    .filter(child => !hasCounts.value || countOf(child) > 0)
)

function toggleCategory(tag) {
  const children = props.categories.find(c => c.tag === tag)?.children || []

  if (!props.modelValue.includes(tag)) {
    // Подтеги включаются вместе с категорией: выбрав тему, пользователь хочет
    // её целиком, а не пустое уточнение. Лишнее он снимет вручную.
    const next = [...props.modelValue, tag, ...children]
    emit('update:modelValue', [...new Set(next)])
    return
  }

  // Снимая категорию, убираем и её подтеги — иначе остались бы висеть
  // уточнения без родителя, которых на экране уже не видно.
  emit('update:modelValue', props.modelValue.filter(t => t !== tag && !children.includes(t)))
}

function toggleChild(tag) {
  const next = props.modelValue.includes(tag)
    ? props.modelValue.filter(t => t !== tag)
    : [...props.modelValue, tag]
  emit('update:modelValue', next)
}
</script>

<style scoped>
.tag-picker__categories {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.category-tile {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 1rem;
  text-align: left;
  color: #374151;
  background: #F3F4F6;
  border: 2px solid transparent;
  border-radius: 0.75rem;
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s, transform 0.15s;
}

.category-tile:hover {
  background: #E5E7EB;
  transform: translateY(-1px);
}

.category-tile--active {
  background: #EEF0FE;
  border-color: #4F63F5;
  color: #4F63F5;
}

.category-tile__title {
  font-size: 1.0625rem;
  font-weight: 600;
}

.category-tile__count {
  /* margin-top: auto прижимает бейдж к низу карточки; зазор от описания
     даёт его нижний отступ, когда текст занимает всю высоту. */
  align-self: flex-start;
  margin-top: auto;
  padding: 0.125rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 500;
  color: #6B7280;
  background: rgba(107, 114, 128, 0.12);
  border-radius: 999px;
}

.category-tile--active .category-tile__count {
  color: #4F63F5;
  background: rgba(79, 99, 245, 0.14);
}

.category-tile__description {
  margin-bottom: 0.75rem;
  font-size: 0.75rem;
  line-height: 1.35;
  color: #9CA3AF;
}

.category-tile--active .category-tile__description {
  color: #7C8AF7;
}

.tag-picker__children {
  margin-bottom: 1.75rem;
}

.tag-picker__children-hint {
  font-size: 0.875rem;
  color: #9CA3AF;
  margin-bottom: 0.75rem;
}

.tag-picker__children-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.child-tag {
  padding: 0.375rem 0.75rem;
  font-size: 0.8125rem;
  color: #6B7280;
  background: #F3F4F6;
  border: none;
  border-radius: 9999px;
  cursor: pointer;
  transition: background 0.15s, color 0.15s;
}

.child-tag__count {
  margin-left: 0.375rem;
  font-size: 0.75rem;
  opacity: 0.65;
}

.child-tag:hover {
  background: #E5E7EB;
}

.child-tag--active {
  background: #4F63F5;
  color: #fff;
}

/* Идёт после --active, иначе выбранный тег не реагировал бы на наведение:
   правило .child-tag:hover выше по каскаду его не перебивает. */
.child-tag--active:hover {
  background: #4338CA;
}

.tag-picker-children-enter-active,
.tag-picker-children-leave-active {
  transition: opacity 0.2s ease;
}

.tag-picker-children-enter-from,
.tag-picker-children-leave-to {
  opacity: 0;
}

@media (prefers-color-scheme: dark) {
  .category-tile,
  .child-tag {
    background: #1F2937;
    color: #D1D5DB;
  }

  .category-tile--active {
    background: #312E81;
    color: #C7CDF9;
  }
}
</style>
