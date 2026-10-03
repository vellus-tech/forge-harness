import type { HTMLAttributes } from 'react';

export type BadgeTone = 'success' | 'warning' | 'neutral';

export type BadgeProps = HTMLAttributes<HTMLSpanElement> & {
  tone?: BadgeTone;
};

/** Rótulo curto de status (ex.: viagem aprovada/pendente/expirada). */
export function Badge({ tone = 'neutral', className, ...rest }: BadgeProps) {
  return <span className={['badge', tone, className].filter(Boolean).join(' ')} {...rest} />;
}
