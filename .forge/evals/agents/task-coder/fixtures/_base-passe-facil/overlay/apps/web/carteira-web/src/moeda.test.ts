import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatarCentavos } from './moeda.ts';

test('formata centavos em reais', () => {
  assert.equal(formatarCentavos(450), 'R$ 4,50');
  assert.equal(formatarCentavos(123456), 'R$ 1.234,56');
});

test('rejeita valor fracionário', () => {
  assert.throws(() => formatarCentavos(4.5), TypeError);
});
