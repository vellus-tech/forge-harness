import type { ImgHTMLAttributes } from 'react';

const SOURCES = {
  teal: new URL('../assets/brand/rotaviva-mark-teal.png', import.meta.url).href,
  black: new URL('../assets/brand/rotaviva-mark-black.png', import.meta.url).href,
  white: new URL('../assets/brand/rotaviva-mark-white.png', import.meta.url).href,
} as const;

export type RotavivaMarkVariant = keyof typeof SOURCES;

export interface RotavivaMarkProps extends Omit<ImgHTMLAttributes<HTMLImageElement>, 'src'> {
  variant?: RotavivaMarkVariant;
}

/**
 * Marca Rotaviva a partir do PNG real exportado do handoff.
 * Proibido desenhar um SVG próprio do mark (ver `project/SKILL.md` do handoff).
 */
export function RotavivaMark({ variant = 'teal', alt = 'Rotaviva', ...rest }: RotavivaMarkProps) {
  return <img src={SOURCES[variant]} alt={alt} {...rest} />;
}
