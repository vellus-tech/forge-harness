import { forwardRef, useId } from 'react';
import type { InputHTMLAttributes, ReactNode } from 'react';
import { cn } from '../../lib/cn.js';
import styles from './Input.module.css';

export interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'size'> {
  label: ReactNode;
  hint?: ReactNode;
  error?: string;
}

/**
 * Campo de formulário derivado de `preview/inputs.html` do handoff — label +
 * hint opcional, altura fixa de 48px e estado de erro via `aria-invalid`.
 */
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, hint, error, id, className, ...rest },
  ref,
) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const hintId = hint || error ? `${inputId}-hint` : undefined;

  return (
    <label className={cn(styles.field, className)} htmlFor={inputId}>
      {label}
      <input
        ref={ref}
        id={inputId}
        className={styles.input}
        aria-invalid={error ? true : undefined}
        aria-describedby={hintId}
        {...rest}
      />
      {(error ?? hint) && (
        <span id={hintId} className={styles.hint}>
          {error ?? hint}
        </span>
      )}
    </label>
  );
});
