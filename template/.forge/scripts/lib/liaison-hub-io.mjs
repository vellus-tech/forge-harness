#!/usr/bin/env node
// liaison-hub-io — E/S no HUB do liaison sem seguir link, sem parsing por linha e sem confiar no
// que terceiros escreveram (SEC-001). Zero dependência; roda SEMPRE com o cwd no diretório do hub
// já ancorado pelo chamador (`_dir_anchor` em lib/transports/_common.sh: `cd -P` conferido por
// `pwd -P`), e por isso só toca o hub por nome RELATIVO, preso ao inode conferido.
//
// POR QUE UM MÓDULO, E NÃO MAIS SHELL. O pull enumerava com `find … | while read` e copiava com
// `cp` por caminho. Dois defeitos que nenhuma guarda em shell fecha:
//   - SEC-201/SEC-202: um nome com `\n` vira DUAS linhas para o `read`; a segunda é um nome que
//     nunca passou pelos filtros do `find` (`-type f`, `-links 1`) — o atacante a aponta para um
//     symlink ou hardlink do segredo da vítima, e o `cp` o copia para a réplica;
//   - SEC-105: entre a enumeração e o `cp` há uma janela (medida em ~33% num laço de troca por
//     rename) em que a entrada regular vira symlink, e o `cp` segue o link.
// Aqui a enumeração é `readdirSync` (nomes como array, nenhum parsing por linha), o nome passa por
// regex estrita, e a leitura é `open(O_RDONLY|O_NOFOLLOW|O_NONBLOCK)` seguida de `fstat` NO
// DESCRITOR: o que se confere (arquivo regular, um vínculo, tamanho) é exatamente o que se lê,
// porque a cópia sai do mesmo fd. O_NONBLOCK impede que um FIFO plantado trave o sync.
//
// Subcomandos (rc 0 sucesso; rc 1 recusa/erro; rc 2 uso):
//   pull <log|blobs> <destino_abs> <self> <rótulo>
//       copia as entradas aceitas do cwd para <destino_abs> (staging privado). Entrada recusada
//       vira aviso no stderr e o pull segue — mesmo comportamento que o `-links 1` já tinha.
import {
  openSync, closeSync, fstatSync, readSync, writeSync, fchmodSync, readdirSync, unlinkSync, constants,
} from 'node:fs';
import { join } from 'node:path';
import { BLOB_MAX_BYTES, BODY_REF_RE, ID_RE } from './liaison-merge.mjs';

// Teto do log de um remetente no hub. Não há teto equivalente no import (o log cresce para sempre),
// então este é só o freio contra um arquivo hostil gigante: ~centenas de milhares de mensagens.
const LOG_MAX_BYTES = 256 * 1024 * 1024;

// Temporários que NUNCA são conteúdo: o da recuperação de blob (liaison-import.mjs) e o desta
// publicação. Ignorados em silêncio na enumeração — são estado transitório de alguém, não dado.
const TEMP_RE = /^\.(recover-.*|liaison-publica\..*)\.tmp$/;

const RO_FLAGS = constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK;

// Nome para mensagem: JSON escapa `\n` e controle, para que o aviso não injete linhas no terminal.
const q = (s) => JSON.stringify(s);

class Recusa extends Error {}

// abreSeguro <nome> <limite> — abre <nome> (relativo ao cwd) sem seguir link e confere NO fd que é
// arquivo regular, com um único vínculo e dentro do teto. Devolve { fd, size } ou lança Recusa com
// a causa por extenso. ENOENT propaga como erro com `code`, para o chamador decidir.
function abreSeguro(nome, limite) {
  let fd;
  try {
    fd = openSync(nome, RO_FLAGS);
  } catch (e) {
    if (e.code === 'ELOOP' || e.code === 'EMLINK') throw new Recusa('é link simbólico no hub (SEC-001)');
    throw e;
  }
  try {
    const st = fstatSync(fd);
    if (!st.isFile()) throw new Recusa('não é arquivo regular (FIFO, diretório ou dispositivo) — SEC-001');
    if (st.nlink !== 1) throw new Recusa('tem mais de um vínculo (hardlink) no hub e pode ser um arquivo de fora da árvore do canal (SEC-001)');
    if (st.size > limite) throw new Recusa(`excede o teto de ${limite} bytes (${st.size})`);
    return { fd, size: st.size };
  } catch (e) {
    closeSync(fd);
    throw e;
  }
}

// copiaDoFd <fd> <destFd> <limite> — copia do descritor já conferido, nunca do caminho. O teto é
// reconferido durante a cópia: o arquivo pode crescer depois do fstat.
function copiaDoFd(fd, destFd, limite) {
  const buf = Buffer.allocUnsafe(65536);
  let total = 0;
  for (;;) {
    const n = readSync(fd, buf, 0, buf.length, null);
    if (n === 0) break;
    total += n;
    if (total > limite) throw new Recusa(`cresceu além do teto de ${limite} bytes durante a leitura`);
    let off = 0;
    while (off < n) off += writeSync(destFd, buf, off, n - off);
  }
  return total;
}

function nomeAceito(tipo, nome, self) {
  if (tipo === 'log') {
    if (!nome.endsWith('.jsonl')) return 'ignora';          // `.keep` e afins: nunca foram lidos
    const sender = nome.slice(0, -'.jsonl'.length);
    if (!ID_RE.test(sender)) return 'recusa';
    if (sender === self) return 'ignora';                    // o próprio log nunca volta do hub
    return 'aceita';
  }
  return BODY_REF_RE.test(`blobs/${nome}`) ? 'aceita' : 'recusa';
}

function pull(tipo, destino, self, rotulo) {
  if (tipo !== 'log' && tipo !== 'blobs') { console.error(`FAIL liaison-hub-io pull: tipo inválido ${q(tipo)}`); return 2; }
  const limite = tipo === 'log' ? LOG_MAX_BYTES : BLOB_MAX_BYTES;
  const avisa = (nome, causa) => console.error(`WARN: ${q(`${rotulo}/${nome}`)} ignorado no pull — ${causa}. Investigue quem o publicou.`);
  const nomes = readdirSync('.').sort();
  for (const nome of nomes) {
    if (TEMP_RE.test(nome)) continue;
    const decisao = nomeAceito(tipo, nome, self);
    if (decisao === 'ignora') continue;
    if (decisao === 'recusa') { avisa(nome, 'nome fora do padrão aceito pelo liaison (SEC-001)'); continue; }
    let origem;
    try {
      origem = abreSeguro(nome, limite);
    } catch (e) {
      avisa(nome, e instanceof Recusa ? e.message : `erro de leitura (${e.code || e.message})`);
      continue;
    }
    const alvo = join(destino, nome);
    let destFd = null;
    try {
      // 'wx' = O_CREAT|O_EXCL: o staging é privado e recém-criado, então um nome já existente é
      // anomalia — recusa em vez de sobrescrever (e nunca segue link).
      destFd = openSync(alvo, 'wx', 0o644);
      copiaDoFd(origem.fd, destFd, limite);
      fchmodSync(destFd, 0o644);
    } catch (e) {
      if (destFd !== null) { try { closeSync(destFd); } catch { /* já fechado */ } destFd = null; try { unlinkSync(alvo); } catch { /* melhor esforço */ } }
      avisa(nome, e instanceof Recusa ? e.message : `não foi possível copiar (${e.code || e.message})`);
    } finally {
      if (destFd !== null) closeSync(destFd);
      closeSync(origem.fd);
    }
  }
  return 0;
}

function main(argv) {
  const [sub, ...args] = argv;
  switch (sub) {
    case 'pull': {
      if (args.length !== 4) { console.error('FAIL liaison-hub-io (uso: pull <log|blobs> <destino_abs> <self> <rótulo>)'); return 2; }
      return pull(...args);
    }
    default:
      console.error(`FAIL liaison-hub-io: subcomando desconhecido ${q(sub || '')}`);
      return 2;
  }
}

// Erro inesperado sai como uma linha curta com o código, nunca como stack trace: a saída do sync é
// lida por gente e por agentes, e um stack não diz o que fazer.
try {
  process.exitCode = main(process.argv.slice(2));
} catch (e) {
  console.error(`FAIL liaison-hub-io: ${e.code || e.message}`);
  process.exitCode = 1;
}
