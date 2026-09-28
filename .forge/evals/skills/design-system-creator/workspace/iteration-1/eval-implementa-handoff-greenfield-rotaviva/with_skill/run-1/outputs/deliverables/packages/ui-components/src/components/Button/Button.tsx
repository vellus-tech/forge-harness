import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { cn } from '../../../lib/cn.js';
import styles from './Button.module.css';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'md' | 'sm';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
}

/**
 * Botão de pílula com press mecânico (scale 0.96) e anel de foco em
 * `--brand` — nunca remova o `:focus-visible` (hard no do handoff).
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', className, type = 'button', ...rest },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      className={cn(styles.btn, styles[variant], size === 'sm' && styles.sm, className)}
      {...rest}
    />
  );
});
