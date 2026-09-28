import type { InputHTMLAttributes, ReactNode } from 'react';
import { useId } from 'react';

export type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  label: ReactNode;
  hint?: ReactNode;
  error?: string;
};

/** Campo de formulário com label, hint e estado de erro (aria-invalid). */
export function Input({ label, hint, error, id, className, ...rest }: InputProps) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const describedBy = error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined;
  return (
    <label className="field" htmlFor={inputId}>
      <span className="label">{label}</span>
      <input
        id={inputId}
        className={['input', className].filter(Boolean).join(' ')}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        {...rest}
      />
      {error ? (
        <span id={`${inputId}-error`} className="hint error" role="alert">
          {error}
        </span>
      ) : hint ? (
        <span id={`${inputId}-hint`} className="hint">
          {hint}
        </span>
      ) : null}
    </label>
  );
}
