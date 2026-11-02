// Interceptador de rede para os gates do /forge:kb, carregado por `--require` (NODE_OPTIONS). Toda
// porta de saída de rede ou de processo filho do Node passa a lançar, e a tentativa é registrada em
// $NO_NETWORK_LOG — assim uma tentativa engolida por um try/catch do código testado ainda aparece.
//
// É CommonJS e entra por --require, e não por --import, de propósito: medido que um Worker não
// executa o módulo de --import mesmo com ele no execArgv, e o onnxruntime-web roda com threads
// WASM. --require é aplicado também dentro de cada Worker, e o canário (net-canary.mjs) prova isso
// a cada execução do gate.
'use strict';
const { appendFileSync } = require('node:fs');
const { syncBuiltinESMExports } = require('node:module');
const log = process.env.NO_NETWORK_LOG;
const deny = (name) => function denied() {
  if (log) { try { appendFileSync(log, `${name}\n`); } catch { /* sem log */ } }
  throw new Error(`REDE BLOQUEADA: ${name}`);
};
globalThis.fetch = deny('fetch');
const PORTS = {
  http: ['request', 'get'], https: ['request', 'get'], http2: ['connect'], net: ['connect', 'createConnection'],
  tls: ['connect'], dns: ['lookup', 'resolve', 'resolve4', 'resolve6', 'resolveAny'], dgram: ['createSocket'],
  child_process: ['spawn', 'exec', 'execFile', 'fork', 'spawnSync', 'execSync', 'execFileSync'],
};
for (const [m, fns] of Object.entries(PORTS)) { const mod = require(m); for (const f of fns) mod[f] = deny(`${m}.${f}`); }
// Pontos de estrangulamento, além das funções de alto nível: todo socket TCP (inclusive o de
// fetch/undici, http, https e tls) passa por net.Socket.prototype.connect; todo UDP por
// dgram.Socket.prototype.send/bind; e a resolução de nomes pelo módulo dns e dns/promises.
require('node:net').Socket.prototype.connect = deny('net.Socket.connect');
const dgram = require('node:dgram');
dgram.Socket.prototype.send = deny('dgram.Socket.send');
dgram.Socket.prototype.bind = deny('dgram.Socket.bind');
const dnsP = require('node:dns/promises');
for (const f of ['lookup', 'resolve', 'resolve4', 'resolve6', 'resolveAny']) dnsP[f] = deny(`dns/promises.${f}`);
syncBuiltinESMExports();
