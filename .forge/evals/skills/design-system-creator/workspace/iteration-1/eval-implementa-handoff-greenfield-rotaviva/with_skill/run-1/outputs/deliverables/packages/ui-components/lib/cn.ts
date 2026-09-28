import clsx, { type ClassValue } from 'clsx';

/** Wrapper único de composição de classNames — sempre via este helper. */
export function cn(...inputs: ClassValue[]): string {
  return clsx(...inputs);
}
