import { verify } from '../auth/index';
export function requireAuth(header: string) { return verify(header.replace('Bearer ', '')); }
