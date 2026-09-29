'use strict';
// Crédito de recarga do cartão de transporte: valor em centavos, limite por transação.
const LIMITE_CENTAVOS = 20000;
function creditar(saldoCentavos, valorCentavos) {
  if (!Number.isInteger(valorCentavos) || valorCentavos <= 0) throw new Error('valor inválido');
  if (valorCentavos > LIMITE_CENTAVOS) throw new Error('acima do limite por transação');
  return saldoCentavos + valorCentavos;
}
module.exports = { creditar, LIMITE_CENTAVOS };
