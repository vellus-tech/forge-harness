import { TarifaRepository } from '../tarifacao/tarifa-repository';
import { Money } from '../shared/money';
const JANELA_MIN = 120;
export async function tarifaSegundoEmbarque(repo: TarifaRepository, linhaId: string, minutosDesdePrimeiro: number, modalAnterior: string): Promise<Money | null> {
  const t = await repo.buscarVigente({ id: linhaId });
  if (!t) return null;
  if (minutosDesdePrimeiro <= JANELA_MIN && modalAnterior !== t.modal) return t.valor.aplicarDesconto(25);
  return t.valor;
}
