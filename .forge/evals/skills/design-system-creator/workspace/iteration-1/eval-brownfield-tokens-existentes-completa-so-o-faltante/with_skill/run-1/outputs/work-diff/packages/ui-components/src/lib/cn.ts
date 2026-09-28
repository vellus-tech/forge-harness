import clsx, { type ClassValue } from 'clsx';

/** Wrap fino de clsx — único ponto de composição de className do kit. */
export function cn(...inputs: ClassValue[]): string | undefined {
  const out = clsx(...inputs);
  return out === '' ? undefined : out;
}
