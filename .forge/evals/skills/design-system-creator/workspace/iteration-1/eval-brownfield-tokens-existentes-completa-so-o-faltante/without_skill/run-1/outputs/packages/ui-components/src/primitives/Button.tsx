import type { ButtonHTMLAttributes } from 'react';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
export type ButtonSize = 'md' | 'sm';

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

/**
 * Botão pílula com 4 variantes (primary/secondary/ghost/danger) e 2 tamanhos.
 * `primary` usa `--brand` como fundo — nunca usar `--brand` em texto corrido pequeno
 * (contraste ~3.4:1 sobre branco, aprovado só para CTA curto/ícone-ação, ver chat de handoff).
 */
export function Button({ variant = 'primary', size = 'md', className, ...rest }: ButtonProps) {
  const classes = ['btn', variant, size === 'sm' ? 'sm' : '', className].filter(Boolean).join(' ');
  return <button className={classes} {...rest} />;
}
