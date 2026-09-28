import { requireAuth } from '../../middleware/auth';
export function getMe(h: string) { return requireAuth(h).sub; }
