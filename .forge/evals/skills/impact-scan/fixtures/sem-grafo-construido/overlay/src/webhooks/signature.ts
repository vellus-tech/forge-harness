import { createHmac } from 'node:crypto';
export function verifySignature(body: string, sig: string) { return createHmac('sha256', process.env.ACQ_WEBHOOK_KEY ?? '').update(body).digest('hex') === sig; }
