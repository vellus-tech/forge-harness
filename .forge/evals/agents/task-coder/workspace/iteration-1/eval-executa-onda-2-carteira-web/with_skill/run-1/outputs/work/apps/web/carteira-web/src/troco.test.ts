import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcularTroco } from './troco.ts';

test('calcula troco em centavos', () => {
  assert.equal(calcularTroco(1000, 450), 550);
  assert.equal(calcularTroco(450, 450), 0);
});

test('rejeita pago menor que a tarifa', () => {
  assert.throws(() => calcularTroco(400, 450), RangeError);
});

test('rejeita valores não inteiros', () => {
  assert.throws(() => calcularTroco(400.5, 450), TypeError);
  assert.throws(() => calcularTroco(400, 450.5), TypeError);
});
