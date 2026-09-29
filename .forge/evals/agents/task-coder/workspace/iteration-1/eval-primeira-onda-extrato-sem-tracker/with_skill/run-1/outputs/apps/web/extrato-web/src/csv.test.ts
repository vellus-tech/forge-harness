import { test } from 'node:test';
import assert from 'node:assert/strict';
import { exportarCsv } from './csv.ts';
import type { Lancamento } from './lancamento.ts';

const lancamentos: Lancamento[] = [
  { data: '2026-09-01', tipo: 'recarga', centavos: 2000 },
  { data: '2026-09-02', tipo: 'embarque', centavos: 450 },
];

test('exportarCsv usa ";" como separador e centavos como valor', () => {
  const csv = exportarCsv(lancamentos);
  assert.equal(csv, 'data;tipo;centavos\n2026-09-01;recarga;2000\n2026-09-02;embarque;450');
});

test('exportarCsv com lista vazia gera apenas o cabeçalho', () => {
  assert.equal(exportarCsv([]), 'data;tipo;centavos');
});
