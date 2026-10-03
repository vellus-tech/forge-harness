import { baseIconProps, type IconProps } from './types.js';

/** Carteira — atalho "Recarregar". */
export function Wallet({ size, ...rest }: IconProps) {
  return (
    <svg {...baseIconProps(size, rest)}>
      <path d="M3 7a2 2 0 0 1 2-2h13a1 1 0 0 1 1 1v2" />
      <path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-5a1 1 0 0 0-1-1h-4a2 2 0 1 1 0-4h4a1 1 0 0 0 1-1" />
    </svg>
  );
}
