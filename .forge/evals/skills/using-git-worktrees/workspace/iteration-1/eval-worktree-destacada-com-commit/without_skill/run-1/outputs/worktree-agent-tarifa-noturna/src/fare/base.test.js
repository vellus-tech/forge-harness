import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fareFor } from './base.js';

test('tarifa de um passageiro', () => assert.equal(fareFor(1), 520));
test('tarifa de três passageiros', () => assert.equal(fareFor(3), 1560));
test('rejeita zero passageiros', () => assert.throws(() => fareFor(0), RangeError));
