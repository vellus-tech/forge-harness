import type { SVGProps } from 'react';

export type IconProps = SVGProps<SVGSVGElement> & {
  size?: number;
};

export const baseIconProps = (size: number | undefined, rest: SVGProps<SVGSVGElement>) => ({
  width: size ?? 24,
  height: size ?? 24,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.75,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': rest['aria-label'] ? undefined : true,
  ...rest,
});
