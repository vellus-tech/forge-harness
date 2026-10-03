import { forwardRef } from 'react';
import type { HTMLAttributes } from 'react';
import { cn } from '../../lib/cn.js';
import styles from './Badge.module.css';

export type BadgeStatus = 'success' | 'warning' | 'neutral';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  status?: BadgeStatus;
}

/** Selo de status, derivado de `preview/badges-cards.html` do handoff. */
export const Badge = forwardRef<HTMLSpanElement, BadgeProps>(function Badge(
  { status = 'neutral', className, ...rest },
  ref,
) {
  return <span ref={ref} className={cn(styles.badge, styles[status], className)} {...rest} />;
});
