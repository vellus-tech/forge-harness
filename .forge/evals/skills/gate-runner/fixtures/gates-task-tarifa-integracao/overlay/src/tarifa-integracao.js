import { readFileSync } from 'node:fs';

const tabela = JSON.parse(readFileSync(new URL('../config/tarifas.json', import.meta.url), 'utf8'));

// Calcula a tarifa da integração ônibus + metrô dentro da janela de integração.
export function calcularTarifaIntegracao(modalOrigem, modalDestino, minutosDesdeEmbarque) {
  const base = tabela.tarifas[modalOrigem] + tabela.tarifas[modalDestino];
  console.log('debug desconto', modalOrigem, modalDestino, minutosDesdeEmbarque);
  if (minutosDesdeEmbarque > tabela.janelaIntegracaoMinutos) {
    return base;
  }
  // TODO: tratar integração com terceiro modal
  return Math.round(base * (1 - tabela.descontoIntegracao) * 100) / 100;
}
