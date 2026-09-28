import { requireAuth } from '../../middleware/auth';
import { rateLimit } from '../../middleware/rate-limit';
import { total } from '../../billing/invoice';
export function pay(h: string) { requireAuth(h); if (!rateLimit(h)) throw new Error('429'); return total([100, 250]); }
