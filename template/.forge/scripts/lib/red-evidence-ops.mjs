#!/usr/bin/env node
// lib/red-evidence-ops.mjs — orquestração dos subcomandos `record` e `replay` de
// red-evidence.sh (Onda C). `status` e `waive` NÃO vivem aqui: são delegados por
// red-evidence.sh direto a check-red-first.sh (Onda B) — mesma política, uma fonte só.
//
//   record <change-dir> --test-path <p> --command <c> --failure-pattern <p> [--test-id <id>]
//          [--fix-files a,b,c] [--setup-command <c>] [--reproduces <txt>] [--excerpt <txt>]
//     Declara a intenção (test_path/command/failure_pattern/fix_files/...). NUNCA marca
//     status:'observed' — essa transição só acontece via `replay` bem-sucedido (é o ponto
//     central da Onda C: sem replay, a evidência é só uma declaração que o agente pode
//     fabricar). Sempre grava status:'pending' e limpa replayed_at/replay_head (uma nova
//     declaração invalida qualquer replay anterior). failure_pattern é OBRIGATÓRIO (Furo 10 —
//     sem ele, o item 4 da rule nunca é avaliável; opcional era o mesmo que ausente).
//
//   replay <change-dir> [--timeout <segundos>]
//     Chama lib/red-replay.mjs sobre os dados já declarados. Três desfechos:
//       observed     -> grava status/base_commit/base_strategy/classification/excerpt/
//                        excerpt_sha256/base_result/replayed_at/replay_head (Furo 1 — replay_head
//                        é o sha do HEAD no momento do replay; metadado informativo, NENHUM
//                        caminho de decisão o lê — ver Onda E abaixo).
//       fail         -> NUNCA deixa um status:'observed' falso: volta para 'pending' (com o
//                        excerpt/classification da tentativa, para diagnóstico) e imprime o
//                        item da rule que falhou. exit 1.
//       not-possible -> grava status:'not-possible' (não conta como resolvido — check-red-first
//                        Onda B continua bloqueando até /forge:red waive). exit 1.
//
// Onda E (decisão do orquestrador) — elimina o cache local de replay (lib/red-replay-cache.mjs,
// removido): duas rodadas de auditoria mostraram que qualquer atalho de custo baseado em estado
// local (campo do artefato, depois cache local) vira, cedo ou tarde, o alvo que os próprios
// gates passam a exigir para aprovar — inclusive evidência fabricada. A partir desta Onda,
// `ensure` executa o replay SEMPRE, sem cache-check algum: o único atalho é `status: 'waived'`
// (política própria, não observação de Red pendente — ver cmdEnsure). Isso tem custo real (mede
// no comentário de cmdEnsure abaixo) — aceito deliberadamente em troca de eliminar (a) o furo do
// cache versionável em projetos que instalaram o harness antes do patch do .gitignore e (b) o
// livelock relatado quando o cache invalidava por motivo alheio ao conteúdo do teste/correção.
import { readFileSync, existsSync, writeFileSync, renameSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';
import { parseYamlSubset } from './yaml-lite.mjs';
import { loadRedEvidence, REL_PATH } from './red-evidence.mjs';
import { replay as runReplay } from './red-replay.mjs';

const root = resolve(process.env.FORGE_ROOT || '.');

function readManifest(changeDir) {
  const p = join(resolve(changeDir), 'manifest.yaml');
  if (!existsSync(p)) return null;
  try { return parseYamlSubset(readFileSync(p, 'utf8')); } catch { return null; }
}

function writeJsonAtomic(path, obj) {
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n');
  renameSync(tmp, path);
}

function nowIso() { return new Date().toISOString(); }

function sha256(s) { return createHash('sha256').update(String(s)).digest('hex'); }

function truncate(s, max = 6000) {
  const text = String(s || '');
  return text.length <= max ? text : `…(truncado — ${text.length} chars)…\n${text.slice(-max)}`;
}

function requireBugfix(changeDir) {
  const man = readManifest(changeDir);
  if (!man) { console.log('FAIL (manifest.yaml ausente/ilegível)'); process.exit(1); }
  if (man.type !== 'bugfix') { console.log(`FAIL (red-evidence só se aplica a change type:bugfix, got: ${man.type})`); process.exit(1); }
  return man;
}

function requireEvidence(changeDir) {
  const ev = loadRedEvidence(changeDir);
  if (!ev.exists) { console.log(`FAIL (${REL_PATH} ausente — se este change já existe, rode 'red-evidence.sh init <change-id>' para escaffoldar; para um change novo, use /forge:spec new --type bugfix)`); process.exit(1); }
  if (ev.errors.length) { console.log(`FAIL (${REL_PATH} inválido: ${ev.errors.join('; ')})`); process.exit(1); }
  return ev;
}

function parseFlags(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) { out[a.slice(2)] = argv[i + 1]; i++; }
  }
  return out;
}

function cmdRecord(changeDir, argv) {
  requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const f = parseFlags(argv);
  const data = { ...ev.data };

  if (f['test-path']) data.test_path = f['test-path'];
  if (f['test-id']) data.test_id = f['test-id'];
  if (f['command']) data.command = f['command'];
  if (f['fix-files']) data.fix_files = f['fix-files'].split(',').map((s) => s.trim()).filter(Boolean);
  if (f['failure-pattern']) data.failure_pattern = f['failure-pattern'];
  if (f['setup-command']) data.setup_command = f['setup-command'];
  if (f['reproduces']) data.reproduces = f['reproduces'];
  if (f['excerpt']) {
    data.excerpt = f['excerpt'];
    data.excerpt_sha256 = sha256(f['excerpt']);
  }

  // Furo 10 — failure_pattern obrigatório: sem ele o item 4 da rule nunca é avaliável (a
  // ausência do campo desliga o gate silenciosamente, indistinguível de "não se aplica").
  // Onda D, item 3 — test_id agora TAMBÉM obrigatório: sem ele, a derivação de base (ancestry)
  // volta a ancorar na criação do ARQUIVO de teste (não do CASO), e os guardas
  // caseExistsInContent/outputMentionsCase do motor de replay (Furo 2) passam por vacuidade —
  // "sem test_id declarado, nada a exigir" deixa de ser uma degradação aceitável quando test_id
  // é obrigatório por contrato.
  if (!data.test_path || !data.test_id || !data.command || !data.failure_pattern) {
    console.log('FAIL (--test-path, --test-id, --command e --failure-pattern são obrigatórios para record)');
    process.exit(1);
  }
  if (!Array.isArray(data.fix_files)) data.fix_files = [];

  // record é DECLARAÇÃO, não observação — o replay é quem prova. Uma nova declaração invalida
  // qualquer replay anterior (o teste/comando declarado pode ter mudado).
  data.status = 'pending';
  data.replayed_at = null;
  data.replay_head = null;
  data.recorded_at = nowIso();

  writeJsonAtomic(ev.path, data);
  console.log(`OK record — ${data.test_path} declarado (status: pending — rode /forge:red replay para observar)`);
}

// persistReplayResult: único ponto que TRADUZ um veredito do motor de replay (lib/red-replay.mjs)
// em escrita do red-evidence.json, usado tanto por `replay` (explícito) quanto por `ensure`
// (chamado incondicionalmente por spec-verify.sh/archive-spec.sh/validate-spec.mjs). Fonte
// única — sem isso, os dois caminhos podiam divergir em como gravam status/campos, reabrindo o
// furo de duas fontes de verdade que a Onda C já tinha fechado uma vez.
function persistReplayResult(ev, data, result) {
  // base_strategy/revert_patch são resetados aqui e só voltam a ser gravados no ramo 'observed'
  // abaixo — sem isso, um replay que falha DEPOIS de um replay 'observed' anterior deixaria
  // base_strategy/revert_patch de uma tentativa antiga (e potencialmente inválida) lingerindo na
  // evidência, confundindo quem ler o JSON. replayed_at/replay_head permanecem como metadado
  // INFORMATIVO (quando o último replay rodou, sobre qual HEAD) — nenhum caminho de decisão em
  // check-red-first.mjs lê esses dois campos para concluir 'observed' (Onda D: a prova mora na
  // execução — cache local ou o próprio replay ao vivo — não no artefato).
  // graft_from acompanha base_strategy no reset: é o par que explica de onde veio a árvore base,
  // e um graft_from remanescente de uma tentativa anterior descreveria uma base que não é a desta.
  const updated = { ...data, replayed_at: nowIso(), replay_head: result.replay_head || null, base_strategy: null, revert_patch: null, graft_from: null };

  if (result.verdict === 'observed') {
    updated.status = 'observed';
    updated.base_commit = result.base_commit || null;
    updated.base_strategy = result.base_strategy || null;
    updated.classification = result.classification || null;
    updated.excerpt = truncate(result.excerpt);
    updated.excerpt_sha256 = sha256(updated.excerpt);
    updated.base_result = result.base_result || 'failed';
    updated.revert_patch = result.revert_patch || null;
    updated.graft_from = result.graft_from || null;
  } else if (result.verdict === 'not-possible') {
    updated.status = 'not-possible';
    if (result.diagnostic) {
      updated.excerpt = truncate(result.diagnostic.excerpt);
      updated.excerpt_sha256 = sha256(updated.excerpt);
      updated.classification = result.diagnostic.classification || null;
    }
  } else {
    // fail — nunca deixa um status:'observed' falso na árvore; volta para pending com o
    // diagnóstico da tentativa anexado (útil para o próximo replay).
    updated.status = 'pending';
    updated.base_result = result.base_result || null;
    if (result.base) updated.base_strategy = result.base.strategy || null;
    if (result.diagnostic) {
      updated.excerpt = truncate(result.diagnostic.excerpt);
      updated.excerpt_sha256 = sha256(updated.excerpt);
      updated.classification = result.diagnostic.classification || null;
    }
  }
  writeJsonAtomic(ev.path, updated);
  return updated;
}

async function cmdReplay(changeDir, argv) {
  const man = requireBugfix(changeDir);
  const ev = requireEvidence(changeDir);
  const data = ev.data;
  if (!data.test_path || !data.command) {
    console.log('FAIL (test_path/command ausentes — rode /forge:red record antes de replay)');
    process.exit(1);
  }
  const f = parseFlags(argv);
  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;

  const result = await runReplay({ root, evidence: data, timeoutS });
  persistReplayResult(ev, data, result);

  if (result.verdict === 'observed') {
    console.log(`OK replay — Red observado (${result.strategy}, base ${result.base_commit ? String(result.base_commit).slice(0, 7) : '?'}) e Green confirmado em HEAD`);
    return;
  }
  if (result.verdict === 'not-possible') {
    console.log(`NOT-POSSIBLE replay — ${result.reason} (grave /forge:red waive --reason <motivo> para prosseguir)`);
    process.exit(1);
  }
  console.log(`FAIL replay (item ${result.ruleItem}) — ${result.reason}`);
  process.exit(1);
}

// cmdEnsure — chamado INCONDICIONALMENTE por spec-verify.sh, pelo pré-flight de archive-spec.sh
// e por validate-spec.mjs (na transição para verified), para todo change type:bugfix. Onda E —
// SEM cache: `ensure` executa o motor de replay de verdade toda vez que roda (o único atalho que
// resta é `status: waived`, que é política própria, não observação de Red pendente de prova).
// O custo é real e proporcional ao teste declarado (um `npx vitest run <arquivo>`/`node --test
// <arquivo>` típico, não a suíte inteira) — pago a cada /forge:verify e a cada /forge:archive.
// Nunca sai com rc≠0 por um veredito desfavorável — quem decide bloquear é check-red-first.mjs,
// que roda em seguida e lê o que ESTA chamada acabou de gravar. rc≠0 aqui é reservado a erro de
// setup genuíno (manifest ilegível).
async function cmdEnsure(changeDir, argv) {
  const man = readManifest(changeDir);
  if (!man) { console.log('FAIL (manifest.yaml ausente/ilegível)'); process.exit(1); }
  if (man.type !== 'bugfix') { console.log(`OK ensure (n/a — type: ${man.type})`); return; }

  const ev = loadRedEvidence(changeDir);
  if (!ev.exists) { console.log('OK ensure (evidência ausente — nada a garantir; check-red-first cobre o item 1)'); return; }
  if (ev.errors.length) { console.log(`OK ensure (evidência inválida: ${ev.errors.join('; ')} — check-red-first cobre)`); return; }
  const data = ev.data;

  // waived é uma política PRÓPRIA (§ Quando o Red não é possível) — não uma observação de Red
  // pendente de prova. Reaplicar a política do waiver (diff real x grafo) é responsabilidade de
  // check-red-first.mjs, não deste comando.
  if (data.status === 'waived') { console.log('OK ensure — status: waived (nada a replayar)'); return; }

  const f = parseFlags(argv);
  const timeoutS = f.timeout ? parseInt(f.timeout, 10) : undefined;

  const result = await runReplay({ root, evidence: data, timeoutS });
  const updated = persistReplayResult(ev, data, result);
  console.log(`OK ensure — replay executado (verdict: ${result.verdict}, status: ${updated.status})`);
}

const [, , cmd, changeDir, ...rest] = process.argv;
if (!cmd || !changeDir) {
  console.log('FAIL (usage: red-evidence-ops.mjs record|replay|ensure <change-dir> [...])');
  process.exit(1);
}
switch (cmd) {
  case 'record': cmdRecord(changeDir, rest); break;
  case 'replay': await cmdReplay(changeDir, rest); break;
  case 'ensure': await cmdEnsure(changeDir, rest); break;
  default: console.log(`FAIL (unknown subcommand: ${cmd})`); process.exit(1);
}
