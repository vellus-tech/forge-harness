import { forwardRef } from 'react';
import type { LucideIcon, LucideProps } from 'lucide-react';

/**
 * Escala 4-pt fechada. Nenhum outro valor é permitido — mantém os ícones
 * alinhados à grade de espaçamento do design system (ver tokens.css `--s-*`).
 */
export type IconSize = 16 | 20 | 24 | 32 | 40 | 48;

export interface IconProps extends Omit<LucideProps, 'size'> {
  /** Componente de ícone do lucide-react, ex.: `Bell`, `Wallet`, `Bus`. */
  icon: LucideIcon;
  size?: IconSize;
  /** Rótulo acessível. Quando omitido, o ícone vira decorativo (`aria-hidden`). */
  'aria-label'?: string;
}

/**
 * Wrapper único sobre lucide-react. Nunca importe `lucide-react` direto num
 * app ou bloco — sempre via `@rotaviva/icons`.
 */
export const Icon = forwardRef<SVGSVGElement, IconProps>(function Icon(
  { icon: IconComponent, size = 24, strokeWidth = 1.75, 'aria-label': ariaLabel, ...rest },
  ref,
) {
  return (
    <IconComponent
      ref={ref}
      size={size}
      strokeWidth={strokeWidth}
      aria-hidden={ariaLabel ? undefined : true}
      aria-label={ariaLabel}
      {...rest}
    />
  );
});
