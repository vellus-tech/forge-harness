import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarPorPeriodo } from './filtro.ts';
import type { Lancamento } from './lancamento.ts';

const lancamentos: Lancamento[] = [
  { data: '2026-09-01', tipo: 'recarga', centavos: 2000 },
  { data: '2026-09-05', tipo: 'embarque', centavos: 450 },
  { data: '2026-09-10', tipo: 'embarque', centavos: 450 },
];

// TASK-01.1 — intervalo fechado [inicio, fim]
test('filtrarPorPeriodo inclui as bordas do intervalo fechado', () => {
  const resultado = filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-05');
  assert.deepEqual(resultado.map((l) => l.data), ['2026-09-01', '2026-09-05']);
});

// TASK-01.2 — inicio > fim lança RangeError
test('filtrarPorPeriodo lança RangeError quando inicio é posterior a fim', () => {
  assert.throws(() => filtrarPorPeriodo(lancamentos, '2026-09-10', '2026-09-01'), RangeError);
});

// TASK-02.1 — não chama fetch
test('filtrarPorPeriodo não chama fetch (função pura, sem rede)', () => {
  const fetchOriginal = globalThis.fetch;
  globalThis.fetch = (() => {
    throw new Error('filtrarPorPeriodo não deveria chamar fetch');
  }) as typeof fetch;
  try {
    filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-10');
  } finally {
    globalThis.fetch = fetchOriginal;
  }
});

// TASK-02.2 — não acessa localStorage
test('filtrarPorPeriodo não acessa localStorage (função pura, sem armazenamento)', () => {
  const localStorageOriginal = (globalThis as { localStorage?: unknown }).localStorage;
  const sentinela = new Proxy(
    {},
    {
      get() {
        throw new Error('filtrarPorPeriodo não deveria acessar localStorage');
      },
    },
  );
  (globalThis as { localStorage?: unknown }).localStorage = sentinela;
  try {
    filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-10');
  } finally {
    (globalThis as { localStorage?: unknown }).localStorage = localStorageOriginal;
  }
});

// TASK-02.3 — entrada não é mutada
test('filtrarPorPeriodo não muta a entrada', () => {
  const original = JSON.parse(JSON.stringify(lancamentos));
  filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-05');
  assert.deepEqual(lancamentos, original);
});
