import { baseIconProps, type IconProps } from './types.js';

/** Cartão — atalho "Cartões". */
export function CreditCard({ size, ...rest }: IconProps) {
  return (
    <svg {...baseIconProps(size, rest)}>
      <rect x="2.5" y="5.5" width="19" height="13" rx="2" />
      <path d="M2.5 9.5h19" />
    </svg>
  );
}
