import { log } from '../utils/logger';
export interface Claims { sub: string; kid: string; exp: number }
export function sign(claims: Claims): string { log('sign', claims.kid); return Buffer.from(JSON.stringify(claims)).toString('base64url'); }
export function verify(token: string): Claims { return JSON.parse(Buffer.from(token, 'base64url').toString()); }
