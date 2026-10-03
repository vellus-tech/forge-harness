'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { creditar } = require('../src/recarga');
test('credita recarga Pix no saldo', () => { assert.strictEqual(creditar(450, 1000), 1450); });
test('recusa recarga acima do limite', () => { assert.throws(() => creditar(0, 20001)); });
