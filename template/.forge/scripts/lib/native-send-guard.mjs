// lib/native-send-guard.mjs — leitor/avaliador ÚNICO do gancho de saída `guard-cross-session-send.sh`
// (design §2.5, REQ-04 a REQ-07). O `.sh` só localiza esta lib pelo próprio caminho e faz
// `exec node native-send-guard.mjs` com o stdin — toda a lógica mora aqui.
//
// Etapas, na ordem do design (§2.5): 1 parse; 2 classificação do destino (REQ-05); 3 pedido só
// de aviso de ociosidade; 4 varredura de segredo (REQ-04); 5 contenção por workspace (REQ-07); 6
// destino declarado (REQ-06). Nesta wave (TASK-15, STORY-08) só as etapas 1 a 4 existem — 5 e 6
// chegam na TASK-17 (STORY-09). Até lá, destino de sessão com corpo limpo passa (`exit 0`): o
// estado intermediário nunca é fiado nem publicado (a linha do manifesto só entra na TASK-19 e a
// branch não é publicada antes do fim do change — preâmbulo de tasks.md, nota da TASK-15).
import { realpathSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { findSecrets } from './secret-scan.mjs';
import { readRegistryFiles, isAlive, normalizeSocketPath } from './native-registry.mjs';
import { findNamedAgentInTranscript } from './native-transcript.mjs';

const REF_SUFFIX_RE = /\s\[[0-9a-f]+\]$/;
const BAD_TO_CHARS_RE = /[*,\n]/;
const AGENT_ID_RE = /^a[0-9a-f]{16}$/;

function isBlank(s) {
  return typeof s !== 'string' || s.trim() === '';
}

// ── cache por execução (design §2.5, "caches por execução") ──────────────────────────────────
// Dentro de UMA chamada a `evaluateSendGuard`, a classificação (etapa 2), a origem cruzada e a
// contenção (etapa 5, TASK-17) podem precisar consultar o registro de sessões mais de uma vez
// (por nome, por socket, pela própria sessão). `readRegistryFiles` é a leitura cara (varre o
// diretório inteiro); esta função cacheia o resultado uma vez por execução — o restante
// (`resolveSessionByNameCached` etc.) reaproveita `isAlive`/`normalizeSocketPath` de
// `native-registry.mjs` (nunca reimplementa a checagem de vivacidade), só a seleção sobre o
// snapshot já lido é feita localmente, porque os wrappers de conveniência de native-registry.mjs
// (`resolveByName`/`resolveBySocket`/`resolveBySessionId`) cada um faz a própria leitura do
// diretório — chamá-los diretamente reabriria o mesmo diretório 2 a 3 vezes por execução.
export function createExecutionCache(opts = {}) {
  const sessionsDir = opts.sessionsDir;
  let snapshot = null;
  return {
    registry() {
      if (!snapshot) snapshot = readRegistryFiles({ sessionsDir });
      return snapshot;
    },
  };
}

function registryFailClosedReason(errors) {
  if (!errors || errors.length === 0) return null;
  const first = errors[0];
  return `registro: ${first.file} ilegível ou incompleto (${first.reason})`;
}

// resolveSessionByNameCached(cache, name) -> { entry? , ambiguous?, error? } — mesma semântica
// de `resolveByName` (native-registry.mjs), sobre o snapshot cacheado.
function resolveSessionByNameCached(cache, name) {
  const { entries, errors, dirError } = cache.registry();
  if (dirError) return { error: dirError };
  const fc = registryFailClosedReason(errors);
  if (fc) return { error: fc };
  const alive = entries.filter((e) => e.name === name && isAlive(e));
  if (alive.length === 0) return {};
  if (alive.length > 1) return { ambiguous: true };
  return { entry: alive[0] };
}

// resolveSessionBySocketCached(cache, sockFile) -> entry | null — mesma semântica de
// `resolveBySocket`, sobre o snapshot cacheado.
export function resolveSessionBySocketCached(cache, sockFile) {
  const { entries, dirError } = cache.registry();
  if (dirError) return null;
  const target = normalizeSocketPath(sockFile);
  const alive = entries.filter((e) => isAlive(e) && normalizeSocketPath(e.messagingSocketPath) === target);
  return alive.length > 0 ? alive[0] : null;
}

// resolveOwnSessionCached(cache, sessionId) -> entry | null — mesma semântica de
// `resolveBySessionId`, sobre o snapshot cacheado.
export function resolveOwnSessionCached(cache, sessionId) {
  const { entries, dirError } = cache.registry();
  if (dirError) return null;
  return entries.find((e) => e.sessionId === sessionId) || null;
}

// classifyRecipient(payload, opts) -> { kind: 'internal'|'session'|'blocked', reason?, entry?,
// address? } (design §2.5 etapa 2, REQ-05). Independente das etapas 5 e 6 — não faz contenção
// nem valida destino declarado; só decide se o destino é interno (passa sem checagem), é uma
// sessão (sujeito às demais etapas) ou é um destino que o gancho recusa já aqui.
export function classifyRecipient(payload, opts = {}) {
  const input = (payload && payload.tool_input) || {};
  const kind = input.recipient_kind;
  const to = typeof input.to === 'string' ? input.to : '';
  const cache = opts.cache || createExecutionCache(opts);

  if (kind === 'main') {
    if (to === 'main') return { kind: 'internal', reason: 'main' };
    return { kind: 'blocked', reason: `destino não resolvido: recipient_kind 'main' com 'to' diferente de 'main' ('${to}')` };
  }
  if (kind === 'agent') {
    if (AGENT_ID_RE.test(to)) return { kind: 'internal', reason: 'agentId' };
    return { kind: 'blocked', reason: `destino não resolvido: recipient_kind 'agent' com 'to' fora do formato de agentId ('${to}')` };
  }
  if (kind === 'session') {
    if (!to.startsWith('uds:')) {
      return { kind: 'blocked', reason: `destino não resolvido: recipient_kind 'session' com 'to' fora do formato 'uds:' ('${to}')` };
    }
    return { kind: 'session', address: to.slice(4) };
  }
  if (kind === 'name') {
    if (REF_SUFFIX_RE.test(to)) {
      return {
        kind: 'blocked',
        reason: `destino não resolvido: '${to}' traz sufixo de referência ([hex]), que não é mapeável ao registro local — use o nome puro (se único) ou o endereço 'uds:'`,
      };
    }
    const resolved = resolveSessionByNameCached(cache, to);
    if (resolved.error) return { kind: 'blocked', reason: resolved.error };
    if (resolved.ambiguous) {
      return { kind: 'blocked', reason: `destino ambíguo: mais de uma sessão viva com nome '${to}' — use o endereço 'uds:'` };
    }
    if (resolved.entry) return { kind: 'session', entry: resolved.entry };
    const foundAgent = findNamedAgentInTranscript({ transcriptPath: payload.transcript_path, name: to });
    if (foundAgent) return { kind: 'internal', reason: 'agente nomeado no transcript' };
    return {
      kind: 'blocked',
      reason: `destino não resolve localmente: '${to}' não é sessão viva nem agente nomeado no transcript da sessão — subagente deve ser endereçado pelo agentId`,
    };
  }
  if (BAD_TO_CHARS_RE.test(to)) {
    return { kind: 'blocked', reason: `destino não resolvido: 'to' contém caractere não suportado ('${JSON.stringify(to)}')` };
  }
  return { kind: 'blocked', reason: `destino não resolvido: recipient_kind desconhecido ('${kind}')` };
}

function collectStringFields(value, pathPrefix, out) {
  if (typeof value === 'string') {
    out.push({ path: pathPrefix || '(raiz)', value });
  } else if (Array.isArray(value)) {
    value.forEach((v, i) => collectStringFields(v, `${pathPrefix}[${i}]`, out));
  } else if (value && typeof value === 'object') {
    for (const k of Object.keys(value)) collectStringFields(value[k], pathPrefix ? `${pathPrefix}.${k}` : k, out);
  }
}

// scanToolInputForSecrets(toolInput) -> { found, pattern?, field? } (design §2.5 etapa 4,
// REQ-04). Percorre recursivamente TODOS os valores string de `toolInput` (inclusive aninhados e
// arrays) com a MESMA `findSecrets` de `secret-scan.mjs` usada pelo `send` — um único leitor de
// padrões, nunca duas listas.
export function scanToolInputForSecrets(toolInput) {
  const fields = [];
  collectStringFields(toolInput, '', fields);
  for (const f of fields) {
    const found = findSecrets(f.value);
    if (found.length > 0) return { found: true, pattern: found[0], field: f.path };
  }
  return { found: false };
}

// parsePayload(rawStdin) -> { ok, payload } | { ok: false, reason } (design §2.5 etapa 1).
export function parsePayload(rawStdin) {
  if (!rawStdin || !rawStdin.trim()) {
    return { ok: false, reason: 'gancho: não consegui ler o payload (stdin vazio)' };
  }
  let obj;
  try {
    obj = JSON.parse(rawStdin);
  } catch (err) {
    return { ok: false, reason: `gancho: não consegui ler o payload (JSON malformado: ${err.message})` };
  }
  if (!obj || typeof obj !== 'object') {
    return { ok: false, reason: 'gancho: não consegui ler o payload (não é um objeto)' };
  }
  return { ok: true, payload: obj };
}

// evaluateSendGuard(payload, opts) -> { exitCode: 0 } | { exitCode: 2, message }. Orquestra as
// etapas do design §2.5 sobre um payload já parseado. `opts` aceita `sessionsDir`/`projectsDir`
// (fixtures) e `cache` (reaproveitado por quem já chamou `classifyRecipient` separadamente).
export function evaluateSendGuard(payload, opts = {}) {
  if (!payload || typeof payload !== 'object') {
    return { exitCode: 2, message: 'gancho: payload inválido (não é objeto)' };
  }
  if (payload.tool_name !== undefined && payload.tool_name !== 'SendMessage') {
    return { exitCode: 0 }; // defesa: o matcher do gancho já filtra por SendMessage
  }
  const input = payload.tool_input || {};
  const cache = opts.cache || createExecutionCache(opts);
  const guardOpts = { ...opts, cache };

  const classification = classifyRecipient(payload, guardOpts);
  if (classification.kind === 'internal') return { exitCode: 0 };
  if (classification.kind === 'blocked') {
    return { exitCode: 2, message: classification.reason };
  }

  const notifyOnly = input.notify_when_idle === true && isBlank(input.message) && isBlank(input.content);

  if (!notifyOnly) {
    const body = typeof input.message === 'string' ? input.message : typeof input.content === 'string' ? input.content : undefined;
    if (isBlank(body)) {
      return {
        exitCode: 2,
        message: 'gancho: não consegui extrair o corpo da mensagem (campo ausente ou vazio, e não é pedido só de aviso de ociosidade)',
      };
    }
    const secretCheck = scanToolInputForSecrets(input);
    if (secretCheck.found) {
      return {
        exitCode: 2,
        message: `gancho: segredo detectado (${secretCheck.pattern}) no campo '${secretCheck.field}' — valor nunca ecoado`,
      };
    }
  }

  // Etapas 5 (contenção) e 6 (destino declarado) chegam na TASK-17 — até lá, destino de sessão
  // com corpo limpo passa (ver cabeçalho do módulo).
  return { exitCode: 0 };
}

// runGuard(rawStdin, opts) -> { exitCode, message? } — parse + avaliação, ponto de entrada único
// usado pelo `main()` do processo e pelos testes que exercitam o stdin cru.
export function runGuard(rawStdin, opts = {}) {
  const parsed = parsePayload(rawStdin);
  if (!parsed.ok) return { exitCode: 2, message: parsed.reason };
  return evaluateSendGuard(parsed.payload, opts);
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

async function main() {
  const raw = await readStdin();
  const result = runGuard(raw, {});
  if (result.exitCode !== 0 && result.message) {
    process.stderr.write(`${result.message}\n`);
  }
  process.exit(result.exitCode);
}

// Só roda main() quando invocado como processo (o `.sh` faz `exec node native-send-guard.mjs`);
// quando importado por um módulo de teste, nenhum stdin é consumido. `realpathSync` em
// `process.argv[1]` é necessário: `import.meta.url` já vem resolvido por symlink (no macOS,
// `/tmp` é symlink para `/private/tmp`, e o mesmo vale para `/var/folders/...` usado por
// `os.tmpdir()`), e sem a mesma resolução dos dois lados a comparação nunca casa — `main()`
// nunca rodaria e o processo sairia 0 em silêncio, sem tocar o stdin.
function isDirectInvocation() {
  if (!process.argv[1]) return false;
  try {
    return import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href;
  } catch {
    return false;
  }
}

if (isDirectInvocation()) {
  main();
}
