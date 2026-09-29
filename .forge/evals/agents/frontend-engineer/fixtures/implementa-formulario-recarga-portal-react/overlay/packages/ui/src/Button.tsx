import type { ButtonHTMLAttributes } from 'react';
import styles from './Button.module.css';

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary';
  loading?: boolean;
};

export function Button({ variant = 'primary', loading = false, disabled, children, ...rest }: ButtonProps) {
  return (
    <button
      {...rest}
      className={styles[variant]}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
    >
      {children}
    </button>
  );
}
