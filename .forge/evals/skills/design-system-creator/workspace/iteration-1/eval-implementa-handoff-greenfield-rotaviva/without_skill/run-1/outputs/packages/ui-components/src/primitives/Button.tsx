import type { ButtonHTMLAttributes, ReactNode } from "react";
import "../../../design-tokens/src/tokens.css";
import "./primitives.css";

export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
export type ButtonSize = "md" | "sm";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  children: ReactNode;
}

// Anatomia 1:1 com design-handoff/.../preview/buttons.html — pill, 4 variantes + tamanho sm.
// SKILL.md do handoff proíbe remover o anel de foco: :focus-visible fica sempre ativo (ver primitives.css).
export function Button({ variant = "primary", size = "md", className, children, ...rest }: ButtonProps) {
  const classes = ["btn", variant, size === "sm" ? "sm" : "", className].filter(Boolean).join(" ");
  return (
    <button className={classes} {...rest}>
      {children}
    </button>
  );
}
