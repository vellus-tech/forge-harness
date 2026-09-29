import { forwardRef } from 'react';
import type { HTMLAttributes } from 'react';
import { cn } from '../../lib/cn.js';
import styles from './Eyebrow.module.css';

export type EyebrowProps = HTMLAttributes<HTMLSpanElement>;

/** Rótulo curto acima de um título de card/seção, derivado do preview. */
export const Eyebrow = forwardRef<HTMLSpanElement, EyebrowProps>(function Eyebrow(
  { className, ...rest },
  ref,
) {
  return <span ref={ref} className={cn(styles.eyebrow, className)} {...rest} />;
});
