// Preload (NODE_OPTIONS=--require) para o gate da trava do log próprio (TASK-04/05, REQ-09,
// REQ-11, design §2.4 "Escritor único da gravação"). Embrulha as funções de escrita do `fs` e
// registra, em FORGE_WRITE_SCAN_LOG, toda escrita cujo destino resolvido seja `log/<self>.jsonl`
// (ou seu `.tmp`), junto do arquivo de origem da chamada (primeiro frame da pilha fora deste
// preload e fora do próprio node:fs). O gate exige que a origem seja sempre `liaison-append.mjs`.
'use strict';
const fs = require('fs');
const path = require('path');

const LOG_FILE = process.env.FORGE_WRITE_SCAN_LOG;
if (LOG_FILE) {
  const OWN_LOG_RE = /log[\\/][^\\/]+\.jsonl(?:\.tmp\b.*)?$/;

  function originFile() {
    const err = {};
    Error.captureStackTrace(err, originFile);
    const stack = String(err.stack || '').split('\n').slice(1);
    for (const line of stack) {
      const m = line.match(/\(?([^():\s]+\.m?js):\d+:\d+\)?$/);
      if (!m) continue;
      const f = m[1];
      if (f.endsWith('write-scan-preload.cjs')) continue;
      if (f.startsWith('node:')) continue;
      return f;
    }
    return '(desconhecido)';
  }

  function record(targetPath) {
    try {
      const resolved = path.resolve(String(targetPath));
      if (!OWN_LOG_RE.test(resolved)) return;
      const origin = originFile();
      fs.appendFileSync(LOG_FILE, JSON.stringify({ target: resolved, origin }) + '\n');
    } catch {
      /* nunca deixa a varredura quebrar a escrita real */
    }
  }

  const wrap = (obj, name, pathArgIndex = 0) => {
    const orig = obj[name];
    if (typeof orig !== 'function') return;
    obj[name] = function (...args) {
      record(args[pathArgIndex]);
      return orig.apply(this, args);
    };
  };

  wrap(fs, 'writeFileSync', 0);
  wrap(fs, 'appendFileSync', 0);
  wrap(fs, 'renameSync', 1); // destino do rename é o que importa (é o arquivo final)
  wrap(fs, 'copyFileSync', 1);
  wrap(fs.promises, 'writeFile', 0);
  wrap(fs.promises, 'appendFile', 0);
  wrap(fs.promises, 'rename', 1);
  wrap(fs.promises, 'copyFile', 1);
}
