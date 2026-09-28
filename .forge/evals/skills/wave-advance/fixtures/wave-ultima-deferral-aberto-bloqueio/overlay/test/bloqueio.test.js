'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { bloquear } = require('../src/bloqueio');
test('bloqueio preserva o saldo para transferência', () => {
  const r = bloquear({ id: 'k1', status: 'ativo', saldo: 870 });
  assert.strictEqual(r.status, 'bloqueado');
  assert.strictEqual(r.saldoPreservado, 870);
});
