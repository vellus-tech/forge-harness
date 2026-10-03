import { forwardRef, useId, type InputHTMLAttributes } from 'react';
import { cn } from '../../../lib/cn.js';
import styles from './Input.module.css';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  hint?: string;
  invalid?: boolean;
}

/** Campo de texto com rótulo, hint e estado inválido — anel de foco em `--brand`. */
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, hint, invalid = false, id, className, ...rest },
  ref,
) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const hintId = hint ? `${inputId}-hint` : undefined;

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={inputId}>
        {label}
      </label>
      <input
        ref={ref}
        id={inputId}
        aria-invalid={invalid}
        aria-describedby={hintId}
        className={cn(styles.input, invalid && styles.invalid, className)}
        {...rest}
      />
      {hint ? (
        <span id={hintId} className={cn(styles.hint, invalid && styles.hintInvalid)}>
          {hint}
        </span>
      ) : null}
    </div>
  );
});
