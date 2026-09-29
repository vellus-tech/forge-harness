export const spacing = {
  1: 'var(--s-1)',
  2: 'var(--s-2)',
  3: 'var(--s-3)',
  4: 'var(--s-4)',
  6: 'var(--s-6)',
  8: 'var(--s-8)',
} as const;

export type Spacing = typeof spacing;
