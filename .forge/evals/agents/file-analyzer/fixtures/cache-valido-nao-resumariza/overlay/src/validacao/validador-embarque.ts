import { TarifaRepository } from '../tarifacao/tarifa-repository';
export async function podeEmbarcar(repo: TarifaRepository, linhaId: string, saldoCentavos: number): Promise<boolean> {
  const t = await repo.buscarVigente({ id: linhaId });
  return t !== null && saldoCentavos >= t.valor.centavos;
}
