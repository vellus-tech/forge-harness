export function log(...a: unknown[]) { if (process.env.DEBUG) console.log(...a); }
