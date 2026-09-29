export const typography = {
  fontDisplay: 'var(--font-display)',
  fontUi: 'var(--font-ui)',
  size: {
    12: 'var(--fs-12)',
    14: 'var(--fs-14)',
    16: 'var(--fs-16)',
    20: 'var(--fs-20)',
    28: 'var(--fs-28)',
  },
} as const;

export type Typography = typeof typography;
