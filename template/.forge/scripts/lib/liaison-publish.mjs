// lib/liaison-publish.mjs — marca d'água de publicação do próprio log (issue #109).
//
// `state.json` tinha só `cursors` (leitura) — nenhum `sync` gravava o que este remetente
// PUBLICOU, então uma mensagem `send`ada mas nunca `sync`ada ficava sem aviso nenhum: `status`
// não tinha como comparar o log próprio com o que de fato chegou ao hub.
//
// Chave ADITIVA em state.json (`published`, `published_at`) — leitores existentes só leem
// `cursors` e continuam funcionando sem mudança (§DA-23 do plano de Onda 4).
//
// `published[self]` é o ÚLTIMO msg_id do próprio log — não um cursor de leitura, e não um
// contador: é o ponto até onde o PUSH mais recente teve êxito. Como `_dir_push_union` (em
// lib/transports/_common.sh) sempre deixa o log local igual à união publicada no hub, o último
// msg_id do arquivo local IMEDIATAMENTE APÓS um `t_push` com rc 0 é, por construção, o último
// msg_id que está no hub — não precisamos reconsultar o transporte para saber o que foi
// publicado.
//
// `published_at[self]` é o CARIMBO DE HORA do push, não de `created_at` da mensagem (Decisão
// DA-23): `created_at` é a data do HEAD do commit (`_git_date`, determinístico e imune a relógio
// de parede), então uma mensagem enviada há dias com HEAD antigo mediria "publicada há dias" no
// instante em que o push de fato aconteceu. `published_at` é wall clock deliberadamente — o
// mesmo trade-off que o comentário no topo de liaison-ops.sh já reserva para `state.json`.
import { readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';
import { join } from 'node:path';

// Lê o log do próprio remetente em ordem de arquivo (append-only, um único escritor: a ordem no
// arquivo É a ordem de seq) e devolve a lista de msg_id, mais antiga primeiro.
function ownMsgIds(chDir, self) {
  const file = join(chDir, 'log', `${self}.jsonl`);
  if (!existsSync(file)) return [];
  const text = readFileSync(file, 'utf8');
  const ids = [];
  for (const line of text.split('\n')) {
    const t = line.trim();
    if (!t) continue;
    let rec;
    try { rec = JSON.parse(t); } catch { continue; }
    if (rec && rec.msg_id) ids.push(rec.msg_id);
  }
  return ids;
}

function readState(chDir) {
  const stateFile = join(chDir, 'state.json');
  return existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, 'utf8')) : { cursors: {} };
}

function writeState(chDir, state) {
  const stateFile = join(chDir, 'state.json');
  writeFileSync(`${stateFile}.tmp`, `${JSON.stringify(state, null, 2)}\n`);
  renameSync(`${stateFile}.tmp`, stateFile);
}

// markPublished({ chDir, self, nowWall }) — grava published[self]/published_at[self] depois de
// um push bem-sucedido. NO-OP (não escreve nada) quando o próprio log está vazio — nada foi
// publicado, então não há marca a gravar.
export function markPublished({ chDir, self, nowWall }) {
  const ids = ownMsgIds(chDir, self);
  if (!ids.length) return null;
  const lastId = ids[ids.length - 1];
  const state = readState(chDir);
  if (!state.published) state.published = {};
  if (!state.published_at) state.published_at = {};
  state.published[self] = lastId;
  state.published_at[self] = nowWall;
  writeState(chDir, state);
  return { msgId: lastId, publishedAt: nowWall };
}

// unpublishedCount({ chDir, self }) — quantas mensagens PRÓPRIAS, no log local, estão depois da
// marca de publicação. Sem marca (nunca fez `sync` com push) TODAS as mensagens próprias contam
// como não publicadas. Devolve também `publishedAt` (para o "(há Xmin)" do status) — null quando
// não há marca.
export function unpublishedCount({ chDir, self }) {
  const ids = ownMsgIds(chDir, self);
  if (!ids.length) return { count: 0, publishedAt: null };
  const state = readState(chDir);
  const publishedId = state.published && state.published[self];
  const publishedAt = (state.published_at && state.published_at[self]) || null;
  if (!publishedId) return { count: ids.length, publishedAt: null };
  const idx = ids.indexOf(publishedId);
  if (idx < 0) {
    // Marca aponta para um msg_id que não está mais no log local (reparo/reescrita do próprio
    // log) — trata como "nada publicado que reconheçamos" em vez de adivinhar uma posição.
    return { count: ids.length, publishedAt };
  }
  return { count: ids.length - (idx + 1), publishedAt };
}
