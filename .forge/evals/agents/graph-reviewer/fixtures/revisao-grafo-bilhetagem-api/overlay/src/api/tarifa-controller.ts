// Migrado para ESM NodeNext em 2026-05: imports novos já usam o sufixo .js exigido pelo Node.
import { calcularTarifa } from '../application/calcular-tarifa.js';
import { percentualDesconto } from '../domain/desconto.js';
import tabela from '../../config/tarifas.json';
import { Tarifa } from '../domain/tarifa';
import { formatarBRL } from '../shared/money';
export function getTarifa(linha: string, perfil: 'comum' | 'estudante' | 'idoso', minutos: number): string {
  const t: Tarifa = { linha, valor: tabela.tarifa_base_centavos, integracao: true };
  const bruto = calcularTarifa(t, minutos);
  return formatarBRL(bruto - (bruto * percentualDesconto(perfil)) / 100);
}
