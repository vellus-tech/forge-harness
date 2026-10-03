'use strict';
// Detecta cobrança duplicada de tarifa: mesma validação (cartão + validador) em menos de 60 s.
function duplicada(a, b) {
  return a.cartao === b.cartao && a.validador === b.validador && Math.abs(a.ts - b.ts) < 60000;
}
module.exports = { duplicada };
