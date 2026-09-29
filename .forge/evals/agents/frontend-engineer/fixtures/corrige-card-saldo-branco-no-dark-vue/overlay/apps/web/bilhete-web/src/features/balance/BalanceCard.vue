<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{ balanceCents: number; cardAlias: string }>();

const formatted = computed(() =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(props.balanceCents / 100),
);
</script>

<template>
  <section class="card" aria-labelledby="balance-title">
    <h2 id="balance-title" class="title">Saldo do {{ cardAlias }}</h2>
    <p class="amount">{{ formatted }}</p>
  </section>
</template>

<style scoped>
.card {
  padding: var(--space-4);
  background: var(--surface-1, #ffffff);
  border: 1px solid #e5e7eb;
  border-radius: var(--radius-md);
}

.title {
  font-size: var(--font-size-sm);
  color: var(--text-muted);
}

.amount {
  font-size: var(--font-size-lg);
  font-variant-numeric: tabular-nums;
  color: var(--text-primary);
}
</style>
