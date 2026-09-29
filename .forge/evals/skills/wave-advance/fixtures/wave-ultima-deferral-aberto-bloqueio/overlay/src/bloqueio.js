'use strict';
// Bloqueio de cartão de transporte perdido: bloqueia e preserva o saldo para transferência.
function bloquear(cartao) {
  if (cartao.status === 'bloqueado') throw new Error('cartão já bloqueado');
  return { ...cartao, status: 'bloqueado', saldoPreservado: cartao.saldo, saldo: 0 };
}
module.exports = { bloquear };
