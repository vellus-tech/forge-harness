import { forwardRef } from 'react';
import type { LucideIcon, LucideProps } from 'lucide-react';

export type IconSize = 16 | 20 | 24 | 32 | 40 | 48;

export interface IconProps extends Omit<LucideProps, 'size' | 'ref'> {
  icon: LucideIcon;
  size?: IconSize;
  'aria-label'?: string;
}

/**
 * Wrapper único sobre lucide-react. Nunca importe `lucide-react` direto num
 * app ou bloco — sempre passe o ícone Lucide via prop `icon` para este
 * componente, que fixa a escala 4-pt e o comportamento de acessibilidade.
 */
export const Icon = forwardRef<SVGSVGElement, IconProps>(function Icon(
  { icon: LucideGlyph, size = 24, strokeWidth = 1.75, 'aria-label': ariaLabel, ...rest },
  ref,
) {
  const hidden = ariaLabel ? undefined : true;
  return (
    <LucideGlyph
      ref={ref}
      size={size}
      strokeWidth={strokeWidth}
      aria-hidden={hidden}
      aria-label={ariaLabel}
      {...rest}
    />
  );
});
