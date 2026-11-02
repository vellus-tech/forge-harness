// liaison-baton-local.mjs — estado local NÃO VERSIONADO do bastão (design §2.4/§2.5/§2.8):
// `<tronco>/.forge/cache/liaison-baton/<channel>/baton-local.json`, sob `<channel>@<self>@local.lock`
// (liaison-lock.mjs::withLocalLock — a MESMA disciplina de concorrência de qualquer outro estado
// local lido/regravado por mais de um processo, tmp de nome único + rename).
//
// Dois papéis, no MESMO arquivo:
//   claims  — toda claim PRÓPRIA que recebeu rc 0 vencedora (REQ-05: perda tardia — uma sessão
//             que venceu, mas que a dobra, depois de importar mais réplicas, não aponta mais como
//             titular corrente, é perda tardia; consumido por `baton status`/início de sessão,
//             TASK-23/24, ainda não implementados).
//   holders — índice de bastões que ESTE repositório detém, com `nextRenewAt` (lease_until menos
//             a metade do lease_seconds recém-gravado) e o tamanho/mtime do log próprio no
//             momento, para o caminho rápido do gancho de renovação (design §2.8, TASK-26,
//             ainda não implementado) invalidar o cache quando o log próprio mudar por fora.
//
// Puro quanto a efeitos exceto a leitura/escrita deste arquivo — nunca lê o canal, nunca grava
// no log do liaison. `recordWon` é chamado pelo `claim` SÓ quando a claim de fato grava (verdict
// 'won'); a claim recusada "sessão já titular com lease vigente" não grava nada no canal e
// também não precisa tocar este cache (o holder já existe de quando a claim original venceu).
import { existsSync, readFileSync, writeFileSync, renameSync, statSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { withLocalLock } from './liaison-lock.mjs';

function filePath(root, channel) {
  return join(root, '.forge', 'cache', 'liaison-baton', channel, 'baton-local.json');
}

function readState(path) {
  if (!existsSync(path)) return { claims: {}, holders: {} };
  try {
    const parsed = JSON.parse(readFileSync(path, 'utf8'));
    return { claims: parsed.claims || {}, holders: parsed.holders || {} };
  } catch {
    return { claims: {}, holders: {} };
  }
}

function writeState(path, state) {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.tmp.${process.pid}.${Date.now()}.${Math.random().toString(36).slice(2)}`;
  writeFileSync(tmp, JSON.stringify(state, null, 2));
  renameSync(tmp, path);
}

function ownLogStat(chDir, self) {
  const p = join(chDir, 'log', `${self}.jsonl`);
  if (!existsSync(p)) return { size: 0, mtimeMs: 0 };
  const st = statSync(p);
  return { size: st.size, mtimeMs: st.mtimeMs };
}

// recordWon({root, channel, chDir, self, batonId, msgId, session, leaseSeconds, leaseUntil})
export async function recordWon({ root, channel, chDir, self, batonId, msgId, session, leaseSeconds, leaseUntil }) {
  if (!root || !channel || !chDir || !self || !batonId || !msgId || !session || !leaseSeconds || !leaseUntil) {
    throw new Error('recordWon: root/channel/chDir/self/batonId/msgId/session/leaseSeconds/leaseUntil obrigatórios');
  }
  return withLocalLock({ root, channel, self }, () => {
    const path = filePath(root, channel);
    const state = readState(path);
    state.claims[batonId] = { msgId, session, leaseUntil };
    const nextRenewAt = new Date(Date.parse(leaseUntil) - (leaseSeconds * 1000) / 2).toISOString().replace(/\.\d+Z$/, 'Z');
    const { size, mtimeMs } = ownLogStat(chDir, self);
    state.holders[batonId] = { session, leaseUntil, nextRenewAt, ownLogSize: size, ownLogMtimeMs: mtimeMs };
    writeState(path, state);
    return state;
  });
}

// removeHolder({root, channel, self, batonId}) — release/complete (TASK-21/22) removem a entrada
// do índice de titulares; o histórico em `claims` permanece (é o que a perda tardia consulta).
export async function removeHolder({ root, channel, self, batonId }) {
  if (!root || !channel || !self || !batonId) {
    throw new Error('removeHolder: root/channel/self/batonId obrigatórios');
  }
  return withLocalLock({ root, channel, self }, () => {
    const path = filePath(root, channel);
    const state = readState(path);
    delete state.holders[batonId];
    writeState(path, state);
    return state;
  });
}

// readBatonLocal(root, channel) -> { claims, holders } — leitura direta, sem trava (consumidores
// só-leitura como `baton status`/início de sessão toleram uma leitura em trânsito; quem PRECISA
// de consistência forte lê sob withLocalLock como os escritores acima).
export function readBatonLocal(root, channel) {
  return readState(filePath(root, channel));
}

export function batonLocalPath(root, channel) {
  return filePath(root, channel);
}
