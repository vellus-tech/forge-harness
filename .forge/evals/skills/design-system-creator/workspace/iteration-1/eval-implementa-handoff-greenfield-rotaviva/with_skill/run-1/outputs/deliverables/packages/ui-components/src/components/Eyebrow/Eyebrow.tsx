import { forwardRef, type HTMLAttributes } from 'react';
import { cn } from '../../../lib/cn.js';
import styles from './Eyebrow.module.css';

export type EyebrowProps = HTMLAttributes<HTMLSpanElement>;

/** Rótulo pequeno em versalete usado como cabeçalho de cards e seções. */
export const Eyebrow = forwardRef<HTMLSpanElement, EyebrowProps>(function Eyebrow(
  { className, ...rest },
  ref,
) {
  return <span ref={ref} className={cn(styles.eyebrow, className)} {...rest} />;
});
