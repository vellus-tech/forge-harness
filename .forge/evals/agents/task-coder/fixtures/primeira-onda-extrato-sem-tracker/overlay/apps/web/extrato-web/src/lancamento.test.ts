import { test } from 'node:test';
import assert from 'node:assert/strict';
import { saldo } from './lancamento.ts';

test('saldo soma recargas e subtrai embarques', () => {
  assert.equal(saldo([
    { data: '2026-09-01', tipo: 'recarga', centavos: 2000 },
    { data: '2026-09-02', tipo: 'embarque', centavos: 450 },
  ]), 1550);
});
