import { verifySignature } from './signature';
export function onAcquirerEvent(body: string, sig: string) { if (!verifySignature(body, sig)) throw new Error('401'); return JSON.parse(body); }
