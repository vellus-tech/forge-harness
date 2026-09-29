import type { InputHTMLAttributes } from "react";
import "./primitives.css";

export interface InputFieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  hint?: string;
  invalid?: boolean;
}

// Anatomia 1:1 com preview/inputs.html: label + input 48px + hint opcional, borda vermelha em erro.
export function InputField({ label, hint, invalid, id, ...rest }: InputFieldProps) {
  const inputId = id ?? label.toLowerCase().replace(/\s+/g, "-");
  return (
    <label className="field" htmlFor={inputId}>
      {label}
      <input id={inputId} className="input" aria-invalid={invalid ? "true" : undefined} {...rest} />
      {hint ? <span className="hint">{hint}</span> : null}
    </label>
  );
}
