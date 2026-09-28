import { baseIconProps, type IconProps } from './types.js';

/** Ônibus — usado em TripRow. */
export function Bus({ size, ...rest }: IconProps) {
  return (
    <svg {...baseIconProps(size, rest)}>
      <rect x="3.5" y="4.5" width="17" height="12" rx="2.5" />
      <path d="M3.5 11h17" />
      <circle cx="7.5" cy="19" r="1.5" />
      <circle cx="16.5" cy="19" r="1.5" />
    </svg>
  );
}
