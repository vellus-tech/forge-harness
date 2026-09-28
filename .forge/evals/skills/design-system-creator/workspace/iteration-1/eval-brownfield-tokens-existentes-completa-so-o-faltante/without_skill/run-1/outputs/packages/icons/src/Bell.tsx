import { baseIconProps, type IconProps } from './types.js';

/** Sino de notificações — usado em AppHeader. */
export function Bell({ size, ...rest }: IconProps) {
  return (
    <svg {...baseIconProps(size, rest)}>
      <path d="M6 8a6 6 0 0 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z" />
      <path d="M9.5 17a2.5 2.5 0 0 0 5 0" />
    </svg>
  );
}
