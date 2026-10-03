import { cartaoAceito } from './antifraude-cartao';
import { podeEmbarcar } from './validador-embarque';
import { TarifaRepository } from '../tarifacao/tarifa-repository';
export async function embarqueComCartao(repo: TarifaRepository, linhaId: string, pan: string, saldoCentavos: number): Promise<boolean> {
  if (!cartaoAceito(pan)) return false;
  return podeEmbarcar(repo, linhaId, saldoCentavos);
}
