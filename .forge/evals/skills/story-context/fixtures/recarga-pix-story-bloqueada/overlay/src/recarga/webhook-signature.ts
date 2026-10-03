import { createHmac, timingSafeEqual } from "node:crypto";

export function assinaturaValida(corpo: string, assinatura: string, chave: string): boolean {
  const esperada = createHmac("sha256", chave).update(corpo).digest("hex");
  const a = Buffer.from(esperada);
  const b = Buffer.from(assinatura);
  return a.length === b.length && timingSafeEqual(a, b);
}
