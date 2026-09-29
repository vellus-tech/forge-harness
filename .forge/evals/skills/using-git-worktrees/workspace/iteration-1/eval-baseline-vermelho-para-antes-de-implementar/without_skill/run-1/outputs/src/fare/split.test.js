import { test } from 'node:test';
import assert from 'node:assert/strict';
import { splitIntegratedFare } from './split.js';

test('divide exatamente quando o total é múltiplo de 20 centavos', () => {
  assert.deepEqual(splitIntegratedFare(1000), { busCents: 450, metroCents: 550 });
});

test('resíduo do arredondamento vai para o metrô', () => {
  // 45% de 101 = 45.45 -> arredonda para baixo (45) na operadora de ônibus;
  // o resíduo (0,55 centavo) fica com o metrô, que recebe 56.
  assert.deepEqual(splitIntegratedFare(101), { busCents: 45, metroCents: 56 });
});

test('a soma das partes sempre bate com o total, mesmo com resíduo', () => {
  for (const totalCents of [1, 3, 7, 99, 101, 999, 1060]) {
    const { busCents, metroCents } = splitIntegratedFare(totalCents);
    assert.equal(busCents + metroCents, totalCents);
  }
});

test('total zero retorna split zerado', () => {
  assert.deepEqual(splitIntegratedFare(0), { busCents: 0, metroCents: 0 });
});

test('rejeita valores não inteiros', () => {
  assert.throws(() => splitIntegratedFare(10.5), /inteiro/);
});

test('rejeita valores negativos', () => {
  assert.throws(() => splitIntegratedFare(-1), /inteiro/);
});
