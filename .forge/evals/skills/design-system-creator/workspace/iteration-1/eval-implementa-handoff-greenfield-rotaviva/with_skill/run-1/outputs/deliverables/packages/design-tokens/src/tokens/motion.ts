export const motion = {
  easeOut: 'var(--ease-out)',
  durationFast: 'var(--dur-fast)',
  durationBase: 'var(--dur-base)',
} as const;

export type Motion = typeof motion;
