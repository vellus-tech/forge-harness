export const radius = {
  sm: 'var(--r-sm)',
  md: 'var(--r-md)',
  lg: 'var(--r-lg)',
  pill: 'var(--r-pill)',
} as const;

export type Radius = typeof radius;
