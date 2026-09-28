import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcularTroco } from './troco.ts';

test('calcula troco em centavos', () => {
  assert.equal(calcularTroco(1000, 450), 550);
  assert.equal(calcularTroco(450, 450), 0);
});

test('rejeita valor pago menor que a tarifa', () => {
  assert.throws(() => calcularTroco(400, 450), RangeError);
});

test('rejeita argumento não inteiro', () => {
  assert.throws(() => calcularTroco(450.5, 450), TypeError);
  assert.throws(() => calcularTroco(450, 449.9), TypeError);
});
