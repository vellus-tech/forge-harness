import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarPorPeriodo } from './filtro.ts';
import type { Lancamento } from './lancamento.ts';

const lancamentos: Lancamento[] = [
  { data: '2026-09-01', tipo: 'recarga', centavos: 2000 },
  { data: '2026-09-05', tipo: 'embarque', centavos: 450 },
  { data: '2026-09-10', tipo: 'embarque', centavos: 300 },
];

// TASK-01.1
test('filtrarPorPeriodo retorna lançamentos dentro do intervalo fechado', () => {
  const resultado = filtrarPorPeriodo(lancamentos, '2026-09-02', '2026-09-10');
  assert.deepEqual(resultado, [
    { data: '2026-09-05', tipo: 'embarque', centavos: 450 },
    { data: '2026-09-10', tipo: 'embarque', centavos: 300 },
  ]);
});

// TASK-01.2
test('filtrarPorPeriodo lança RangeError quando inicio > fim', () => {
  assert.throws(() => filtrarPorPeriodo(lancamentos, '2026-09-10', '2026-09-01'), RangeError);
});

// TASK-02.1 — falha se o filtro chamar fetch
test('filtrarPorPeriodo não chama fetch', () => {
  const fetchOriginal = globalThis.fetch;
  (globalThis as unknown as { fetch: unknown }).fetch = () => {
    throw new Error('filtrarPorPeriodo não deve chamar fetch');
  };
  try {
    filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-10');
  } finally {
    (globalThis as unknown as { fetch: unknown }).fetch = fetchOriginal;
  }
});

// TASK-02.2 — falha se o filtro acessar localStorage
test('filtrarPorPeriodo não acessa localStorage', () => {
  const localStorageOriginal = (globalThis as unknown as { localStorage?: unknown }).localStorage;
  Object.defineProperty(globalThis, 'localStorage', {
    configurable: true,
    get() {
      throw new Error('filtrarPorPeriodo não deve acessar localStorage');
    },
  });
  try {
    filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-10');
  } finally {
    Object.defineProperty(globalThis, 'localStorage', {
      configurable: true,
      value: localStorageOriginal,
      writable: true,
    });
  }
});

// TASK-02.3 — a entrada não é mutada
test('filtrarPorPeriodo não muta a entrada', () => {
  const copia = JSON.parse(JSON.stringify(lancamentos));
  filtrarPorPeriodo(lancamentos, '2026-09-01', '2026-09-05');
  assert.deepEqual(lancamentos, copia);
});
