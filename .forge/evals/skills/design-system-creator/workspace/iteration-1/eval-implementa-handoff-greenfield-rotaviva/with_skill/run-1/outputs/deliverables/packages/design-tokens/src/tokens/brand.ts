export const brand = {
  base: 'var(--brand)',
  hover: 'var(--brand-hover)',
  press: 'var(--brand-press)',
  soft: 'var(--brand-soft)',
} as const;

export type Brand = typeof brand;
