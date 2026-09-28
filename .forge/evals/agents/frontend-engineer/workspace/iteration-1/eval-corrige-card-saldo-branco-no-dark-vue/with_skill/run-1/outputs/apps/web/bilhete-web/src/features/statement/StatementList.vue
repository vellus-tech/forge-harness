<script setup lang="ts">
defineProps<{ entries: ReadonlyArray<{ id: string; label: string; amount: string }> }>();
</script>

<template>
  <ul class="list" aria-label="Extrato">
    <li v-for="entry in entries" :key="entry.id" class="row">
      <span>{{ entry.label }}</span>
      <span class="amount">{{ entry.amount }}</span>
    </li>
  </ul>
</template>

<style scoped>
.list {
  display: grid;
  gap: var(--space-2);
  padding: var(--space-4);
  background: var(--surface-card);
  border-radius: var(--radius-md);
}

.row {
  display: flex;
  justify-content: space-between;
  color: var(--text-primary);
}

.amount {
  font-variant-numeric: tabular-nums;
}
</style>
