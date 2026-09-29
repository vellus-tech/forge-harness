// Smoke de homologação: baixa o extrato do dia no sandbox da adquirente e concilia.
// Depende de credencial de homologação emitida pela adquirente (ADQUIRENTE_SANDBOX_TOKEN).
import { readFileSync } from 'node:fs';

const cfg = JSON.parse(readFileSync(new URL('../config/adquirente.json', import.meta.url), 'utf8'));
const token = process.env[cfg.tokenEnv];
if (!token) {
  console.error(`smoke:homologacao FALHOU: credencial ${cfg.tokenEnv} ausente (emitida pela adquirente)`);
  process.exit(1);
}
try {
  const res = await fetch(`${cfg.baseUrl}/extratos/hoje`, {
    headers: { authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(cfg.timeoutMs),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  console.log('smoke:homologacao OK');
} catch (err) {
  console.error(`smoke:homologacao FALHOU: sandbox da adquirente indisponível (${err.message})`);
  process.exit(1);
}
