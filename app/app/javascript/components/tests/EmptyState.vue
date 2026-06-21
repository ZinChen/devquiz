<template>
  <div class="empty-state">
    <p class="empty-state__text">Тесты не найдены</p>
    <button @click="$emit('clear')" class="btn btn-sm btn-primary empty-state__btn">
      Сбросить фильтры
    </button>
  </div>
</template>

<script setup>
defineEmits(['clear'])
</script>

<style scoped>
.empty-state {
  text-align: center;
  padding: 4rem 0;
  color: #9CA3AF;
}

.empty-state__text {
  font-size: 1.125rem;
}

.empty-state__btn {
  margin-top: 1rem;
}
</style>
