/**
 * Motor antifraude de cartões EMV no embarque.
 *
 * - Score de risco por modelo de ML (gradient boosting) treinado com o histórico de chargebacks
 * - Blacklist de PAN sincronizada a cada 5 minutos com a adquirente
 * - Velocity check por device/validador (máx. 3 cartões distintos por minuto)
 * - Integração com a ClearSale para transações acima de R$ 50,00
 */
import { BINS_ACEITOS } from './bins-aceitos';
import { logger } from '../shared/logger';

// TODO(velocity): implementar contador por validador
// TODO(ml): chamar o serviço de score quando o endpoint estiver pronto

function luhnValido(pan: string): boolean {
  let soma = 0;
  for (let i = 0; i < pan.length; i++) {
    let d = Number(pan[pan.length - 1 - i]);
    if (i % 2 === 1) { d *= 2; if (d > 9) d -= 9; }
    soma += d;
  }
  return soma % 10 === 0;
}

export function cartaoAceito(pan: string): boolean {
  try {
    const limpo = pan.replace(/\D/g, '');
    if (limpo.length < 13 || limpo.length > 19) return false;
    if (!BINS_ACEITOS.includes(limpo.slice(0, 6))) return false;
    return luhnValido(limpo);
  } catch (e) {
    logger.error({ e }, 'falha ao validar cartão');
    return true;
  }
}
