import { verify } from '../auth/index';
const hits = new Map<string, number>();
export function rateLimit(header: string) { const sub = verify(header).sub; hits.set(sub, (hits.get(sub) ?? 0) + 1); return hits.get(sub)! <= 100; }
