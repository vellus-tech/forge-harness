import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcularTarifaIntegracao } from '../src/tarifa-integracao.js';

test('dentro da janela aplica 25% de desconto', () => {
  assert.equal(calcularTarifaIntegracao('onibus', 'metro', 30), 7.05);
});

test('fora da janela cobra a soma cheia', () => {
  assert.equal(calcularTarifaIntegracao('onibus', 'metro', 150), 9.4);
});
