'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { duplicada } = require('../src/estorno');
test('duas validações no mesmo validador em 10 s são duplicadas', () => {
  assert.ok(duplicada({ cartao: 'c1', validador: 'v9', ts: 0 }, { cartao: 'c1', validador: 'v9', ts: 10000 }));
});
test('validadores diferentes não são duplicadas', () => {
  assert.ok(!duplicada({ cartao: 'c1', validador: 'v9', ts: 0 }, { cartao: 'c1', validador: 'v3', ts: 10000 }));
});
