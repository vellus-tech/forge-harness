import { forwardRef } from 'react';
import type { HTMLAttributes } from 'react';
import { cn } from '../../lib/cn.js';
import styles from './Card.module.css';

export type CardProps = HTMLAttributes<HTMLDivElement>;

/** Superfície elevada (fundo + raio + sombra), derivada de `preview/badges-cards.html`. */
export const Card = forwardRef<HTMLDivElement, CardProps>(function Card(
  { className, ...rest },
  ref,
) {
  return <div ref={ref} className={cn(styles.card, className)} {...rest} />;
});
