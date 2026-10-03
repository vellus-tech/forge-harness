import { test } from 'node:test';
import assert from 'node:assert/strict';
import { exportarCsv } from './csv.ts';
import type { Lancamento } from './lancamento.ts';

const lancamentos: Lancamento[] = [
  { data: '2026-09-01', tipo: 'recarga', centavos: 2000 },
  { data: '2026-09-05', tipo: 'embarque', centavos: 450 },
];

// TASK-04.1 (implícito por Req 2.1)
test('exportarCsv gera CSV com separador ; e valores em centavos', () => {
  const csv = exportarCsv(lancamentos);
  assert.equal(
    csv,
    ['data;tipo;centavos', '2026-09-01;recarga;2000', '2026-09-05;embarque;450'].join('\n'),
  );
});

test('exportarCsv com lista vazia gera apenas o cabeçalho', () => {
  assert.equal(exportarCsv([]), 'data;tipo;centavos');
});
