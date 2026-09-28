import { forwardRef, type HTMLAttributes } from 'react';
import { cn } from '../../../lib/cn.js';
import styles from './Badge.module.css';

export type BadgeStatus = 'success' | 'warning' | 'neutral';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  status?: BadgeStatus;
}

/** Rótulo de status (ex.: viagem aprovada/pendente/expirada). */
export const Badge = forwardRef<HTMLSpanElement, BadgeProps>(function Badge(
  { status = 'neutral', className, ...rest },
  ref,
) {
  return <span ref={ref} className={cn(styles.badge, styles[status], className)} {...rest} />;
});
