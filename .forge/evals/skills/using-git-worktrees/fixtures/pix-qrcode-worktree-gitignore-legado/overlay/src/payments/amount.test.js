import { test } from 'node:test';
import assert from 'node:assert/strict';
import { toCents, formatBRL } from './amount.js';

test('converte reais inteiros em centavos', () => assert.equal(toCents(12), 1200));
test('arredonda frações de centavo', () => assert.equal(toCents('4.3'), 430));
test('aceita zero', () => assert.equal(toCents(0), 0));
test('formata em BRL', () => assert.match(formatBRL(1250), /12,50/));
