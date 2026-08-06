// liaison-import — aplicação de um bundle de logs alheios sobre o store local do liaison.
//
// Diferente de liaison-merge.mjs (funções puras), esta lib TOCA DISCO: lê o bundle, reescreve
// log/<sender>.jsonl e grava conflicts/. Existe porque `import` (bundle explícito, sincronização
// manual) e `sync` (bundle materializado por um transporte) precisam aplicar EXATAMENTE a mesma
// política de merge — duplicar a política em dois heredocs faria as duas portas de entrada
// divergirem, e a porta mais frouxa passaria a ser o caminho de menor resistência.
//
// Política, na ordem em que é aplicada a cada mensagem recebida:
//   1. spoofing de arquivo — `sender` diverge do nome do arquivo em que chegou → conflito
//   2. spoofing de identidade — mensagem se declara com o self.id local → conflito
//   3. envelope inválido (forma, enums, tetos) → conflito
//   4. content_sha auto-inconsistente (adulteração em trânsito) → conflito
//   5. body_ref fora do padrão, blob ausente ou acima do teto → conflito
//   6. COMPATIBILIDADE DE LOG — o log de um remetente é append-only: uma posição (seq) já
//      conhecida não pode chegar com outro msg_id ou outro content_sha. Reescrita de história é
//      DIVERGÊNCIA: nenhuma mensagem daquele remetente é aplicada e o comando reprova. A
//      divergência isola o remetente — os demais são aplicados normalmente, para que um peer
//      corrompido não trave o canal inteiro.
//   7. duplicata exata (mesmo msg_id, mesmo content_sha) → no-op silencioso
//
// `trust` é carimbado aqui como 'untrusted-peer', nunca aceito do remetente.
import { readFileSync, writeFileSync, readdirSync, existsSync, renameSync, copyFileSync, statSync, mkdirSync } from 'node:fs';
import { join, basename } from 'node:path';
import * as M from './liaison-merge.mjs';

function readJsonl(path) {
  let text;
  try { text = readFileSync(path, 'utf8'); } catch { return []; }
  const out = [];
  for (const line of text.split('\n')) {
    const t = line.trim();
    if (t) { try { out.push(JSON.parse(t)); } catch { /* linha corrompida: ignorada, o gap de seq denuncia */ } }
  }
  return out;
}

// Aplica o bundle em fromDir sobre o canal em chDir. Retorna contadores + a lista de remetentes
// divergentes (vazia = nada reescreveu história).
export function applyBundle({ chDir, fromDir, self }) {
  const logDir = join(chDir, 'log');
  const conflictsDir = join(chDir, 'conflicts');
  const blobsDir = join(chDir, 'blobs');
  const fromLog = join(fromDir, 'log');
  const fromBlobs = join(fromDir, 'blobs');
  mkdirSync(conflictsDir, { recursive: true });
  mkdirSync(blobsDir, { recursive: true });

  const conflictsToWrite = [];
  const divergences = [];
  const perSenderNew = new Map();
  let accepted = 0, dup = 0, conflicts = 0;

  const bundleFiles = existsSync(fromLog)
    ? readdirSync(fromLog).filter((f) => f.endsWith('.jsonl')).sort()
    : [];

  for (const file of bundleFiles) {
    const fileSender = basename(file, '.jsonl');
    if (!M.ID_RE.test(fileSender)) continue;
    if (fileSender === self) continue; // somos a fonte da verdade do nosso próprio log

    const incoming = readJsonl(join(fromLog, file));
    const existing = existsSync(join(logDir, file)) ? readJsonl(join(logDir, file)) : [];
    const existingById = new Map(existing.map((m) => [m.msg_id, m]));
    const existingBySeq = new Map(existing.map((m) => [Number(m.seq), m]));

    // --- passada 1: forma e integridade individual -------------------------------------------
    const candidates = [];
    for (const raw of incoming) {
      if (raw.sender !== fileSender) {
        conflictsToWrite.push([raw.msg_id || `${file}:unknown`, `sender declarado ('${raw.sender}') diverge do arquivo ('${fileSender}')`, raw, existingById.get(raw.msg_id)]);
        conflicts++; continue;
      }
      if (raw.sender === self) {
        conflictsToWrite.push([raw.msg_id || `${file}:self-spoof`, `mensagem se declara sender='${self}' (identidade local) vinda de fora`, raw, null]);
        conflicts++; continue;
      }
      const errs = M.validateEnvelope(raw);
      if (errs.length) {
        conflictsToWrite.push([raw.msg_id || `${file}:invalid`, `envelope inválido: ${errs.join('; ')}`, raw, existingById.get(raw.msg_id)]);
        conflicts++; continue;
      }
      const recomputed = M.computeContentSha(raw);
      if (recomputed !== raw.content_sha) {
        conflictsToWrite.push([raw.msg_id, `content_sha não confere (declarado ${raw.content_sha}, recalculado ${recomputed})`, raw, existingById.get(raw.msg_id)]);
        conflicts++; continue;
      }
      if (raw.body_ref) {
        if (!M.BODY_REF_RE.test(raw.body_ref)) {
          conflictsToWrite.push([raw.msg_id, `body_ref fora do padrão permitido: ${raw.body_ref}`, raw, null]);
          conflicts++; continue;
        }
        const blobName = raw.body_ref.slice('blobs/'.length);
        const srcBlob = join(fromBlobs, blobName);
        if (!existsSync(srcBlob)) {
          conflictsToWrite.push([raw.msg_id, `blob referenciado ausente no bundle: ${raw.body_ref}`, raw, null]);
          conflicts++; continue;
        }
        if (statSync(srcBlob).size > M.BLOB_MAX_BYTES) {
          conflictsToWrite.push([raw.msg_id, `blob excede ${M.BLOB_MAX_BYTES} bytes`, raw, null]);
          conflicts++; continue;
        }
      }
      candidates.push(raw);
    }

    // --- passada 2: compatibilidade de log (append-only) --------------------------------------
    // Roda só sobre candidatos já íntegros: mensagem adulterada em trânsito é conflito individual
    // (passada 1), não acusação de que o remetente reescreveu a própria história.
    const divergence = detectDivergence(candidates, existingBySeq, existingById);
    if (divergence) {
      divergences.push({ sender: fileSender, ...divergence });
      conflictsToWrite.push([`${fileSender}.divergence`, divergence.reason, divergence.incoming, divergence.known]);
      conflicts++;
      continue; // nenhuma mensagem deste remetente é aplicada
    }

    // --- passada 3: separa duplicatas de novidades --------------------------------------------
    for (const raw of candidates) {
      const already = existingById.get(raw.msg_id);
      if (already) { dup++; continue; } // content_sha já conferido idêntico na passada 2
      accepted++;
      if (!perSenderNew.has(fileSender)) perSenderNew.set(fileSender, []);
      perSenderNew.get(fileSender).push(raw);
    }
  }

  if (accepted > M.IMPORT_MAX_MESSAGES) {
    return { accepted: 0, dup: 0, conflicts: 0, quarantined: 0, divergences: [], overflow: accepted };
  }

  // --- escrita, atômica por arquivo de remetente ---------------------------------------------
  for (const [sender, toAdd] of perSenderNew) {
    const target = join(logDir, `${sender}.jsonl`);
    const existing = existsSync(target) ? readJsonl(target) : [];
    const merged = existing.concat(toAdd.map((m) => ({ ...m, trust: 'untrusted-peer' })));
    const byId = new Map(merged.map((m) => [m.msg_id, m]));
    const finalMsgs = [...byId.values()].sort((a, b) => a.seq - b.seq);
    writeFileSync(target + '.tmp', finalMsgs.map((m) => JSON.stringify(m)).join('\n') + '\n');
    renameSync(target + '.tmp', target);
    for (const m of toAdd) {
      if (m.body_ref) {
        const blobName = m.body_ref.slice('blobs/'.length);
        const dest = join(blobsDir, blobName);
        if (!existsSync(dest)) copyFileSync(join(fromBlobs, blobName), dest);
      }
    }
  }
  for (const [msgId, reason, incoming, existing] of conflictsToWrite) {
    writeFileSync(join(conflictsDir, `${msgId}.json`), JSON.stringify({ msg_id: msgId, reason, incoming, existing: existing || null }, null, 2) + '\n');
  }

  return { accepted, dup, conflicts, quarantined: countQuarantined(logDir), divergences };
}

// Reescrita de história: uma posição já conhecida (por seq ou por msg_id) chegando com outro
// conteúdo. Também detecta o bundle internamente inconsistente (dois seq iguais divergentes),
// que é o mesmo defeito visto antes de tocar o disco.
function detectDivergence(candidates, existingBySeq, existingById) {
  const seenSeq = new Map();
  for (const raw of candidates) {
    const seq = Number(raw.seq);
    const known = existingBySeq.get(seq) || existingById.get(raw.msg_id);
    if (known && (known.msg_id !== raw.msg_id || known.content_sha !== raw.content_sha)) {
      return {
        seq,
        reason: `log divergente: a posição seq=${seq} já é conhecida como ${known.msg_id}/${known.content_sha} e chegou como ${raw.msg_id}/${raw.content_sha} — log append-only não reescreve história`,
        incoming: raw,
        known,
      };
    }
    const twin = seenSeq.get(seq);
    if (twin && twin.content_sha !== raw.content_sha) {
      return {
        seq,
        reason: `log divergente: o próprio bundle traz duas versões da posição seq=${seq} (${twin.msg_id}/${twin.content_sha} e ${raw.msg_id}/${raw.content_sha})`,
        incoming: raw,
        known: twin,
      };
    }
    seenSeq.set(seq, raw);
  }
  return null;
}

function countQuarantined(logDir) {
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')).sort() : [];
  const all = [];
  for (const f of files) for (const m of readJsonl(join(logDir, f))) all.push(m);
  return M.mergeLogs(all).quarantined.length;
}
