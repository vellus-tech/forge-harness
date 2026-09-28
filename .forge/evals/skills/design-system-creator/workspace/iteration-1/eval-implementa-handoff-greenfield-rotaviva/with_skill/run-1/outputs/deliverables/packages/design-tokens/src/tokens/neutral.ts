export const neutral = {
  0: 'var(--n-0)',
  50: 'var(--n-50)',
  100: 'var(--n-100)',
  300: 'var(--n-300)',
  500: 'var(--n-500)',
  700: 'var(--n-700)',
  900: 'var(--n-900)',
} as const;

export type Neutral = typeof neutral;
