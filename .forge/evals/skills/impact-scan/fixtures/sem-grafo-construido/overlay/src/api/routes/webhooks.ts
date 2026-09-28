import { onAcquirerEvent } from '../../webhooks/acquirer';
export const post = (b: string, s: string) => onAcquirerEvent(b, s);
