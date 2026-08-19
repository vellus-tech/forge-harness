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
//      DIVERGÊNCIA: a POSIÇÃO divergente vai para quarentena e o comando reprova; as demais
//      posições do mesmo remetente continuam sendo aplicadas.
//   7. duplicata exata (mesmo msg_id, mesmo content_sha) → no-op silencioso
//
// QUARENTENA POR POSIÇÃO, não por remetente (issue #48). Antes, uma única divergência descartava
// TODAS as mensagens daquele remetente — uma reescrita em duas posições calou 73 mensagens
// posteriores, íntegras e sem colisão de msg_id/content_sha, em três réplicas por dias. O
// invariante que o descarte protegia ("não aceito história reescrita") é preservado quarentenando
// as posições em conflito: ele não exige recusar as seguintes. E não se abre buraco no log — a
// réplica MANTÉM a versão que já conhecia das posições divergentes e ganha as posteriores. O
// silêncio é o defeito: um remetente calado é indistinguível de um remetente quieto, e só o
// tornava visível uma comparação externa contra o hub.
//
// LOTE, não recusa total, acima do teto (issue #48). `IMPORT_MAX_MESSAGES` continua limitando o
// que uma chamada aplica, mas o excedente NÃO é descartado: aplica-se um prefixo por seq e
// reporta-se quantas faltam, de modo que `sync` repetido converge. "Nada foi aplicado"
// transformava atraso em estado terminal — o backlog cresce sozinho, então a réplica que passasse
// do teto nunca mais alcançaria o hub.
//
// `trust` é carimbado aqui como 'untrusted-peer', nunca aceito do remetente.
import { readFileSync, writeFileSync, readdirSync, existsSync, renameSync, copyFileSync, statSync, mkdirSync, unlinkSync } from 'node:fs';
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

// Sufixo dos registros de posição quarentenada em conflicts/: `<sender>.seq-<n>.divergence.json`.
// Um registro POR POSIÇÃO (e não um agregado `<sender>.divergence.json`) porque é sobre a posição
// que se age — restaurar a linha, ou republicar o conteúdo reescrito com seq novo. Um agregado
// esconde quantas e quais posições estão retidas.
const DIVERGENCE_RE = /^(.+)\.seq-(\d+)\.divergence\.json$/;

function divergenceFile(sender, seq) {
  return `${sender}.seq-${seq}.divergence.json`;
}

// Lê as posições atualmente em quarentena por divergência a partir de conflicts/. Vive aqui (e não
// em liaison-merge.mjs) porque é leitura de disco e porque quem escreve o formato é quem deve
// lê-lo. Usada por `status` e pelo render — um total agregado esconderia exatamente o defeito da
// issue #48.
export function readQuarantinedPositions(chDir) {
  const dir = join(chDir, 'conflicts');
  if (!existsSync(dir)) return [];
  const out = [];
  for (const f of readdirSync(dir).sort()) {
    const m = DIVERGENCE_RE.exec(f);
    if (!m) continue;
    let rec = {};
    try { rec = JSON.parse(readFileSync(join(dir, f), 'utf8')); } catch { rec = {}; }
    out.push({
      sender: rec.sender || m[1],
      seq: Number(rec.seq !== undefined && rec.seq !== null ? rec.seq : m[2]),
      msg_id: rec.msg_id || null,
      known_msg_id: rec.known_msg_id || null,
      // O content_sha entra no relato porque a divergência costuma ser de CONTEÚDO com o mesmo
      // msg_id (foi o caso da issue #48): sem ele, as duas versões saem com o mesmo nome e a
      // linha parece dizer que a mensagem diverge de si mesma.
      content_sha: (rec.incoming && rec.incoming.content_sha) || null,
      known_content_sha: (rec.known && rec.known.content_sha) || null,
      thread_id: (rec.incoming && rec.incoming.thread_id) || null,
      subject: (rec.incoming && rec.incoming.subject) || null,
      // Marcador de recuperação: o conteúdo retido já foi republicado em sequência nova. A
      // divergência em si CONTINUA (a origem ainda reescreveu história, e é ela quem tem de
      // corrigir) — o que o marcador diz é que ninguém precisa republicar de novo. Sem ele, cada
      // sync devolveria a posição ao operador como se nada tivesse sido feito.
      resolved_as: rec.resolved_as || null,
      reason: rec.reason || '',
      file: f,
    });
  }
  return out.sort((a, b) => a.sender.localeCompare(b.sender) || a.seq - b.seq);
}

// Marca uma posição retida como REPUBLICADA em sequência nova. Vive aqui, e não em liaison-ops.sh,
// porque quem escreve o formato de conflicts/ é quem deve mutá-lo — o nome do arquivo é convenção
// desta lib, não contrato do shell. Devolve false quando a posição não está retida (nada a marcar).
export function markResolved(chDir, sender, seq, resolvedAs) {
  const file = join(chDir, 'conflicts', divergenceFile(sender, seq));
  if (!existsSync(file)) return false;
  let rec;
  try { rec = JSON.parse(readFileSync(file, 'utf8')); } catch { return false; }
  rec.resolved_as = resolvedAs;
  writeFileSync(file, JSON.stringify(rec, null, 2) + '\n');
  return true;
}

// Aplica o bundle em fromDir sobre o canal em chDir. Retorna contadores + a lista de POSIÇÕES
// divergentes quarentenadas (vazia = nada reescreveu história).
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
  const sendersInBundle = [];
  let dup = 0, conflicts = 0;

  const bundleFiles = existsSync(fromLog)
    ? readdirSync(fromLog).filter((f) => f.endsWith('.jsonl')).sort()
    : [];

  for (const file of bundleFiles) {
    const fileSender = basename(file, '.jsonl');
    if (!M.ID_RE.test(fileSender)) continue;
    if (fileSender === self) continue; // somos a fonte da verdade do nosso próprio log
    sendersInBundle.push(fileSender);

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
    const divs = detectDivergences(candidates, existingBySeq, existingById);
    const quarantinedSeqs = new Set(divs.map((d) => d.seq));
    for (const d of divs) divergences.push({ sender: fileSender, ...d });

    // --- passada 3: separa duplicatas de novidades --------------------------------------------
    for (const raw of candidates) {
      // Posição em quarentena: descartada individualmente. A réplica fica com a versão que já
      // conhecia (ou, no caso do gêmeo, sem nenhuma das duas — e aí o buraco de seq é o
      // diagnóstico honesto, reportado por detectGaps).
      if (quarantinedSeqs.has(Number(raw.seq))) continue;
      const already = existingById.get(raw.msg_id);
      if (already) { dup++; continue; } // content_sha já conferido idêntico na passada 2
      if (!perSenderNew.has(fileSender)) perSenderNew.set(fileSender, []);
      perSenderNew.get(fileSender).push(raw);
    }
  }

  // --- seleção do LOTE -------------------------------------------------------------------------
  // O teto continua valendo por chamada, mas o excedente vira BACKLOG, não descarte. Ordem:
  // remetentes em ordem alfabética, e dentro de cada um um PREFIXO por seq — prefixo é o único
  // corte que preserva a semântica append-only (não inventa buraco de seq). Determinístico: a
  // ordem das linhas no bundle não influi. Não há flag de override deliberadamente — o teto existe
  // para conter bundle malicioso ou corrompido, e uma flag de "recuperação" seria exatamente o que
  // um bundle hostil pediria; o lote é a saída legítima, e converge sem afrouxar o teto.
  //
  // A ordem alfabética faz um remetente com backlog enorme atrasar os seguintes, mas não os
  // esfomeia: cada chamada drena até 200, então N chamadas de sync põem todos em dia. Um
  // round-robin entre remetentes distribuiria melhor e custaria a propriedade que importa — o
  // corte tem de ser previsível para que duas réplicas com o mesmo bundle apliquem o mesmo lote.
  const batch = new Map();
  let budget = M.IMPORT_MAX_MESSAGES;
  let remaining = 0;
  for (const sender of [...perSenderNew.keys()].sort()) {
    const msgs = perSenderNew.get(sender).slice().sort((a, b) => Number(a.seq) - Number(b.seq));
    const take = Math.min(Math.max(budget, 0), msgs.length);
    if (take > 0) batch.set(sender, msgs.slice(0, take));
    budget -= take;
    remaining += msgs.length - take;
  }
  const accepted = [...batch.values()].reduce((n, arr) => n + arr.length, 0);

  // --- escrita, atômica por arquivo de remetente ---------------------------------------------
  for (const [sender, toAdd] of batch) {
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

  // Registro POR POSIÇÃO quarentenada. Carrega sender/seq/msg_id em campos próprios porque é isso
  // que `status` e `render` mostram — o nome do arquivo é conveniência, não a fonte.
  for (const d of divergences) {
    const file = join(conflictsDir, divergenceFile(d.sender, d.seq));
    // A divergência persiste enquanto a origem não corrigir, então cada sync REESCREVE este
    // registro. Se a reescrita apagasse o marcador de republicação, o operador republicaria o
    // mesmo conteúdo a cada sync — o canal ganharia uma cópia por sincronização. O marcador é
    // carregado adiante apenas quando é a MESMA divergência (mesmo par recebido/conhecido); se a
    // origem publicou outra coisa naquela posição, o conteúdo republicado antes não a cobre.
    let carried = null;
    if (existsSync(file)) {
      try {
        const prev = JSON.parse(readFileSync(file, 'utf8'));
        const sameIncoming = prev.incoming && d.incoming && prev.incoming.content_sha === d.incoming.content_sha;
        const sameKnown = (prev.known ? prev.known.content_sha : null) === (d.known ? d.known.content_sha : null);
        if (prev.resolved_as && sameIncoming && sameKnown) carried = prev.resolved_as;
      } catch { /* registro ilegível: trata como se não houvesse marcador */ }
    }
    writeFileSync(file, JSON.stringify({
      sender: d.sender,
      seq: d.seq,
      msg_id: d.incoming ? d.incoming.msg_id : null,
      known_msg_id: d.known ? d.known.msg_id : null,
      reason: d.reason,
      incoming: d.incoming,
      known: d.known || null,
      ...(carried ? { resolved_as: carried } : {}),
    }, null, 2) + '\n');
  }
  // Convergência do registro: posição que deixou de divergir (a origem restaurou a linha, ou
  // republicou o conteúdo com seq novo) tem o registro REMOVIDO. Sem isso, o canal reportaria
  // quarentena para sempre depois de já resolvida, e um aviso que nunca desliga deixa de ser aviso.
  // A varredura é por remetente presente NESTE bundle — nunca apaga registro de quem não veio.
  for (const sender of sendersInBundle) {
    const live = new Set(divergences.filter((d) => d.sender === sender).map((d) => d.seq));
    for (const f of readdirSync(conflictsDir)) {
      const m = DIVERGENCE_RE.exec(f);
      if (!m || m[1] !== sender) continue;
      if (!live.has(Number(m[2]))) unlinkSync(join(conflictsDir, f));
    }
  }

  return {
    accepted,
    dup,
    conflicts,
    quarantined: countQuarantined(logDir),
    quarantinedPositions: divergences.length,
    remaining,
    divergences,
  };
}

// Reescrita de história: uma posição já conhecida (por seq ou por msg_id) chegando com outro
// conteúdo. Também detecta o bundle internamente inconsistente (dois seq iguais divergentes),
// que é o mesmo defeito visto antes de tocar o disco.
//
// Retorna TODAS as posições divergentes (ordenadas por seq), não a primeira — devolver só a
// primeira era o que fazia o caller descartar o remetente inteiro. Uma posição aparece uma única
// vez, com o motivo da primeira detecção.
//
// O caso GÊMEO (o próprio bundle traz duas versões da mesma posição) quarentena a posição por
// INTEIRO: não há critério para escolher entre as duas versões, e escolher uma seria inventar
// história. Por isso o `continue` abaixo NÃO registra a segunda versão em `seenSeq` — quem filtra
// os candidatos usa o conjunto de seq quarentenados, o que derruba ambas.
function detectDivergences(candidates, existingBySeq, existingById) {
  const seenSeq = new Map();
  const bySeq = new Map();
  for (const raw of candidates) {
    const seq = Number(raw.seq);
    const known = existingBySeq.get(seq) || existingById.get(raw.msg_id);
    if (known && (known.msg_id !== raw.msg_id || known.content_sha !== raw.content_sha)) {
      if (!bySeq.has(seq)) {
        bySeq.set(seq, {
          seq,
          reason: `log divergente: a posição seq=${seq} já é conhecida como ${known.msg_id}/${known.content_sha} e chegou como ${raw.msg_id}/${raw.content_sha} — log append-only não reescreve história`,
          incoming: raw,
          known,
        });
      }
      continue;
    }
    const twin = seenSeq.get(seq);
    if (twin && twin.content_sha !== raw.content_sha) {
      if (!bySeq.has(seq)) {
        bySeq.set(seq, {
          seq,
          reason: `log divergente: o próprio bundle traz duas versões da posição seq=${seq} (${twin.msg_id}/${twin.content_sha} e ${raw.msg_id}/${raw.content_sha})`,
          incoming: raw,
          known: twin,
        });
      }
      continue;
    }
    seenSeq.set(seq, raw);
  }
  return [...bySeq.values()].sort((a, b) => a.seq - b.seq);
}

function countQuarantined(logDir) {
  const files = existsSync(logDir) ? readdirSync(logDir).filter((f) => f.endsWith('.jsonl')).sort() : [];
  const all = [];
  for (const f of files) for (const m of readJsonl(join(logDir, f))) all.push(m);
  return M.mergeLogs(all).quarantined.length;
}
