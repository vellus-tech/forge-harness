import { Tarifa } from '../domain/tarifa';
import { somar } from '../shared/money';
import { BilheteRepository } from '../infrastructure/bilhete-repository';
export async function emitirBilhete(repo: BilheteRepository, cartao: string, t: Tarifa): Promise<number> { await repo.salvar(cartao, t); return somar(t.valor, 0); }
