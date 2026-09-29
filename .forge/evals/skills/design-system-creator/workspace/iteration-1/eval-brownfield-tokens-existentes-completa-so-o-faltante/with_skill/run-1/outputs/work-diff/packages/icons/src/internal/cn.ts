import clsx, { type ClassValue } from 'clsx';

export function cn(...inputs: ClassValue[]): string | undefined {
  const out = clsx(...inputs);
  return out === '' ? undefined : out;
}
