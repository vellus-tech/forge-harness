import { forwardRef, type HTMLAttributes } from 'react';
import { cn } from '../../../lib/cn.js';
import styles from './Card.module.css';

export type CardProps = HTMLAttributes<HTMLDivElement>;

/** Container de superfície elevada — raio grande, sombra suave. */
export const Card = forwardRef<HTMLDivElement, CardProps>(function Card(
  { className, ...rest },
  ref,
) {
  return <div ref={ref} className={cn(styles.card, className)} {...rest} />;
});
