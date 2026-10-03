import { baseIconProps, type IconProps } from './types.js';

/** Ajuda — atalho "Ajuda". */
export function CircleHelp({ size, ...rest }: IconProps) {
  return (
    <svg {...baseIconProps(size, rest)}>
      <circle cx="12" cy="12" r="9.25" />
      <path d="M9.5 9.5a2.5 2.5 0 1 1 3.6 2.25c-.7.35-1.1.9-1.1 1.75v.25" />
      <path d="M12 17h.01" />
    </svg>
  );
}
