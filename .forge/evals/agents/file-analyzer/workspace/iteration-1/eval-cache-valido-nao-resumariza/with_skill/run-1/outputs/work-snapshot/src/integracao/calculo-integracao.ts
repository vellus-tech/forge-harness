// Integração tarifária ônibus <-> metrô <-> BRT.
// Regra da portaria SMT 14/2025: segundo embarque em outro modal
// dentro de 120 minutos paga 75% da tarifa da linha.
import { TarifaRepository } from '../tarifacao/tarifa-repository';
import { Money } from '../shared/money';

// janela em minutos contada a partir do primeiro embarque
const JANELA_MIN = 120;

/**
 * Calcula a tarifa do segundo embarque.
 * Retorna null quando a linha não tem tarifa vigente.
 */
export async function tarifaSegundoEmbarque(repo: TarifaRepository, linhaId: string, minutosDesdePrimeiro: number, modalAnterior: string): Promise<Money | null> {
    const t = await repo.buscarVigente({ id: linhaId });
    if (!t) return null;
    // desconto só vale na troca de modal
    if (minutosDesdePrimeiro <= JANELA_MIN && modalAnterior !== t.modal) return t.valor.aplicarDesconto(25);
    return t.valor;
}
