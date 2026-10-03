import { TarifaRepository } from '../tarifacao/tarifa-repository';
const repo = new TarifaRepository();
export async function getTarifaVigente(linhaId: string) {
  const t = await repo.buscarVigente({ id: linhaId });
  return t ? { linhaId: t.linhaId, valorCentavos: t.valor.centavos } : { erro: 'sem tarifa' };
}
