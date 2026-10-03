import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validUntil } from './validity.js';

test('validade de duas horas a partir da primeira validação', () => {
  assert.equal(validUntil('2026-09-01T10:00:00.000Z'), '2026-09-01T12:00:00.000Z');
});

test('validade expira no fim do dia operacional de São Paulo', () => {
  // Regra nova ainda não implementada: bilhete validado às 23h30 (BRT) expira às 23h59:59 (BRT).
  assert.equal(validUntil('2026-09-02T02:30:00.000Z'), '2026-09-02T02:59:59.000Z');
});
