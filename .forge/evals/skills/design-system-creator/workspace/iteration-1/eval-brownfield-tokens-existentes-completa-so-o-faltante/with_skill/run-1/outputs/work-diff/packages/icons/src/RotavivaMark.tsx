import { forwardRef } from 'react';
import { cn } from './internal/cn.js';

const MARK_SRC = {
  teal: new URL('../assets/brand/rotaviva-mark-teal.png', import.meta.url).toString(),
  black: new URL('../assets/brand/rotaviva-mark-black.png', import.meta.url).toString(),
  white: new URL('../assets/brand/rotaviva-mark-white.png', import.meta.url).toString(),
} as const;

export type RotavivaMarkVariant = keyof typeof MARK_SRC;

export interface RotavivaMarkProps
  extends Omit<React.ImgHTMLAttributes<HTMLImageElement>, 'src' | 'alt'> {
  variant?: RotavivaMarkVariant;
  size?: number;
  /** Marca decorativa por padrão (alt=""); passe um alt quando a marca for o único conteúdo do link/botão. */
  alt?: string;
}

/**
 * O X/mark da Rotaviva é sempre renderizado a partir do PNG real do handoff —
 * nunca desenhe um SVG próprio do mark (regra do `project/SKILL.md` do handoff).
 */
export const RotavivaMark = forwardRef<HTMLImageElement, RotavivaMarkProps>(function RotavivaMark(
  { variant = 'teal', size = 24, alt = '', className, ...rest },
  ref,
) {
  return (
    <img
      ref={ref}
      src={MARK_SRC[variant]}
      alt={alt}
      width={size}
      height={size}
      className={cn(className)}
      {...rest}
    />
  );
});
