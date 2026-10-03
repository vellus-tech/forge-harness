import { onAcquirerEvent } from '../webhooks/acquirer';
export function reconcile(b: string, s: string) { return onAcquirerEvent(b, s).amount; }
