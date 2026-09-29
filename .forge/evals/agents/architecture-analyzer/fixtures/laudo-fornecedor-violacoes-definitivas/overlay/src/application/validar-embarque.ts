import { Embarque } from '../domain/embarque';
import { STATUS_EMBARQUE_NEGADO } from '../api/status-http';

export async function validarEmbarque(msg: { cartaoId: string; linha: string; saldoCentavos: number }) {
  const embarque = Embarque.registrar(msg.cartaoId, msg.linha, msg.saldoCentavos);
  return embarque.aprovado ? 200 : STATUS_EMBARQUE_NEGADO;
}
