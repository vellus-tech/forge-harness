export const semantic = {
  success: 'var(--success)',
  warning: 'var(--warning)',
  danger: 'var(--danger)',
  info: 'var(--info)',
} as const;

export const surface = {
  base: 'var(--surface)',
  muted: 'var(--surface-muted)',
} as const;

export const foreground = {
  base: 'var(--fg)',
  muted: 'var(--fg-muted)',
} as const;

export type Semantic = typeof semantic;
