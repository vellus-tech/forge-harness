#!/usr/bin/env node
// tests/native-containment-gate.driver.mjs — driver do gate `native-containment-gate.sh`
// (TASK-12/TASK-13, STORY-07): exercita pela API `template/.forge/scripts/lib/native-allowlist.mjs`
// (lógica de escrita allow/revoke/pin, leitura efetiva, schema) e
// `template/.forge/scripts/lib/native-containment.mjs` (detector dos quatro tipos do REQ-12) —
// sem passar pela recusa do CLI, que é exercitada à parte pelo .sh (achado A-01 do
// `/forge:analyze`, design §2.7: qualquer gate rodado de dentro de uma sessão do Claude Code tem
// `claude` como ancestral, então o CLI recusaria ali por construção).
//
// Cada seção checa a existência do módulo antes de importar (preâmbulo de tasks.md:
// "vermelho não pode quebrar por módulo ausente") — módulo ausente reporta FAIL nomeando o que
// falta, nunca um stack trace de import.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync, chmodSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { tmpdir } from 'node:os';

const WS = dirname(dirname(fileURLToPath(import.meta.url)));
const LIB = join(WS, 'template', '.forge', 'scripts', 'lib');

let n = 0;
let failures = 0;
const cleanups = [];
function onCleanup(fn) {
  cleanups.push(fn);
}

function check(label, fn) {
  n += 1;
  try {
    const result = fn();
    if (result === false) throw new Error('condição falsa');
    console.log(`OK [${n}] ${label}`);
  } catch (err) {
    failures += 1;
    console.log(`FAIL [${n}] ${label}: ${err && err.message ? err.message : err}`);
  }
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) {
    throw new Error(`${msg} — esperado ${JSON.stringify(expected)}, obtido ${JSON.stringify(actual)}`);
  }
}
function assertTrue(cond, msg) {
  if (!cond) throw new Error(msg);
}
function assertFalse(cond, msg) {
  if (cond) throw new Error(msg);
}

async function importModuleOrFail(label, relPath) {
  const full = join(LIB, relPath);
  if (!existsSync(full)) {
    n += 1;
    failures += 1;
    console.log(`FAIL [${n}] ${label}: módulo '${relPath}' ausente em ${LIB}`);
    return null;
  }
  try {
    return await import(pathToFileURL(full).href);
  } catch (err) {
    n += 1;
    failures += 1;
    console.log(`FAIL [${n}] ${label}: módulo '${relPath}' falhou ao importar (${err.message})`);
    return null;
  }
}

function git(cwd, args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

function initRepo(dir, remote) {
  mkdirSync(dir, { recursive: true });
  git(dir, ['init', '-q']);
  git(dir, ['config', 'user.email', 'fixture@test']);
  git(dir, ['config', 'user.name', 'fixture']);
  git(dir, ['config', 'commit.gpgsign', 'false']);
  if (remote) git(dir, ['remote', 'add', 'origin', remote]);
  git(dir, ['commit', '--allow-empty', '-qm', 'chore: init fixture']);
}

function commitAll(dir, msg) {
  git(dir, ['add', '-A']);
  git(dir, ['commit', '-qm', msg]);
  return git(dir, ['rev-parse', 'HEAD']);
}

function writeManifestLine(dir, matcher, estado) {
  const text = `# forge-manifest-format: 1\nguard-cross-session-send.sh\t${matcher}\tstdin-json\t${estado}\n`;
  writeFileSync(join(dir, '.forge', 'hooks', 'pre-tool-use', 'hooks.manifest'), text);
}

function writeSettingsWithGuard(dir, wired) {
  mkdirSync(join(dir, '.claude'), { recursive: true });
  const hooks = wired
    ? { PreToolUse: [{ matcher: '^SendMessage$', hooks: [{ type: 'command', command: '"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/guard-cross-session-send.sh' }] }] }
    : { PreToolUse: [] };
  writeFileSync(join(dir, '.claude', 'settings.json'), JSON.stringify({ hooks }));
}

function newFixtureRoot(remote) {
  const dir = mkdtempSync(join(tmpdir(), 'native-containment-fixture-'));
  onCleanup(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(join(dir, '.forge', 'hooks', 'pre-tool-use'), { recursive: true });
  mkdirSync(join(dir, '.forge', 'liaison'), { recursive: true });
  writeFileSync(join(dir, '.forge', 'hooks', 'pre-tool-use', 'guard-cross-session-send.sh'), '#!/usr/bin/env bash\nexit 0\n');
  chmodSync(join(dir, '.forge', 'hooks', 'pre-tool-use', 'guard-cross-session-send.sh'), 0o755);
  initRepo(dir, remote || 'https://github.com/acme/widget.git');
  return dir;
}

async function main() {
  const A = await importModuleOrFail('allow/revoke/pin', 'native-allowlist.mjs');
  const C = await importModuleOrFail('containment/hook-unwired', 'native-containment.mjs');

  // ---------------------------------------------------------------------------------------
  // native-allowlist.mjs — lógica de escrita pela API (TASK-12 item 2)
  // ---------------------------------------------------------------------------------------
  if (A) {
    check('allow: formato de identidade — host/owner/repo, host:porta/owner/repo e caminho absoluto aceitos; forma inválida reprovada', () => {
      assertTrue(A.isValidIdentityFormat('github.com/acme/widget'), 'host/owner/repo');
      assertTrue(A.isValidIdentityFormat('example.com:2222/acme/widget'), 'host:porta/owner/repo');
      assertTrue(A.isValidIdentityFormat('/abs/path/repo'), 'caminho absoluto');
      assertFalse(A.isValidIdentityFormat('github.com'), 'só host, sem owner/repo, deveria reprovar');
      assertFalse(A.isValidIdentityFormat(''), 'vazio deveria reprovar');
    });

    check('validateAllowlistDoc: documento válido passa; sem revoked_by/revoke_reason junto de revoked_at reprova', () => {
      const good = { version: 1, allowed_workspaces: [{ id: 'a/b/c', reason: 'r', granted_by: 'g', granted_at: '2026-01-01T00:00:00Z' }] };
      assertEqual(A.validateAllowlistDoc(good).length, 0, 'documento válido deveria ter zero erros');
      const bad = { version: 1, allowed_workspaces: [{ id: 'a/b/c', reason: 'r', granted_by: 'g', granted_at: '2026-01-01T00:00:00Z', revoked_at: '2026-01-02T00:00:00Z' }] };
      assertTrue(A.validateAllowlistDoc(bad).length > 0, 'revoked_at sem revoked_by/revoke_reason deveria reprovar');
    });

    const root = newFixtureRoot();

    check('readEffectiveAllowlist: arquivo ausente no HEAD = cadastro vazio, sem erro', () => {
      const r = A.readEffectiveAllowlist({ root });
      assertEqual(r.error, null, 'não deveria haver erro');
      assertEqual(r.doc.allowed_workspaces.length, 0, 'deveria ser vazio');
    });

    check('allow: --reason vazio reprova sem tocar o arquivo', () => {
      const before = existsSync(join(root, '.forge', 'liaison', 'allowed-workspaces.json'));
      const r = A.allow({ root, id: 'github.com/acme/other', reason: '', grantedBy: 'op@test', now: '2026-01-01T00:00:00Z' });
      assertFalse(r.ok, 'deveria reprovar com --reason vazio');
      assertEqual(existsSync(join(root, '.forge', 'liaison', 'allowed-workspaces.json')), before, 'arquivo não deveria ter sido tocado');
    });

    check('allow: primeiro cadastro grava self_identity e a entrada; idempotente em repetição', () => {
      const r1 = A.allow({ root, id: 'github.com/acme/other', reason: 'acesso a outro repo', grantedBy: 'op@test', now: '2026-01-01T00:00:00Z' });
      assertTrue(r1.ok, `primeiro allow deveria passar: ${r1.error}`);
      assertEqual(r1.doc.self_identity, 'github.com/acme/widget', 'self_identity deveria ser a identidade atual do repo');
      assertEqual(r1.doc.allowed_workspaces.length, 1, 'deveria ter uma entrada');
      const r2 = A.allow({ root, id: 'github.com/acme/other', reason: 'outra razão', grantedBy: 'op@test', now: '2026-01-02T00:00:00Z' });
      assertTrue(r2.ok, 'repetição deveria passar (idempotente)');
      assertEqual(r2.doc.allowed_workspaces.length, 1, 'repetição de identidade ativa não deveria duplicar');
    });

    check('revoke: identidade inexistente reprova', () => {
      const r = A.revoke({ root, id: 'github.com/nunca/existiu', reason: 'x', revokedBy: 'op@test', now: '2026-01-03T00:00:00Z' });
      assertFalse(r.ok, 'deveria reprovar identidade inexistente');
    });

    check('revoke: marca revoked_at/revoked_by/revoke_reason sem apagar a entrada; revoke duplo reprova', () => {
      const r = A.revoke({ root, id: 'github.com/acme/other', reason: 'não precisa mais', revokedBy: 'op@test', now: '2026-01-03T00:00:00Z' });
      assertTrue(r.ok, `revoke deveria passar: ${r.error}`);
      const entry = r.doc.allowed_workspaces.find((e) => e.id === 'github.com/acme/other');
      assertTrue(entry.revoked_at === '2026-01-03T00:00:00Z', 'revoked_at deveria estar gravado');
      assertEqual(entry.revoked_by, 'op@test', 'revoked_by deveria estar gravado');
      assertEqual(entry.revoke_reason, 'não precisa mais', 'revoke_reason deveria estar gravado');
      const r2 = A.revoke({ root, id: 'github.com/acme/other', reason: 'de novo', revokedBy: 'op@test', now: '2026-01-04T00:00:00Z' });
      assertFalse(r2.ok, 'revoke de identidade já revogada deveria reprovar');
    });

    check('allow: identidade revogada cria entrada ativa NOVA e preserva a revogada (duas entradas, mesmo id)', () => {
      const r = A.allow({ root, id: 'github.com/acme/other', reason: 'de volta', grantedBy: 'op@test', now: '2026-01-05T00:00:00Z' });
      assertTrue(r.ok, `allow de identidade revogada deveria passar: ${r.error}`);
      const entries = r.doc.allowed_workspaces.filter((e) => e.id === 'github.com/acme/other');
      assertEqual(entries.length, 2, 'deveria haver duas entradas com o mesmo id');
      assertTrue(entries.some((e) => e.revoked_at), 'a entrada revogada deveria permanecer');
      assertTrue(entries.some((e) => !e.revoked_at), 'deveria haver uma entrada ativa nova');
    });

    check('pin: sobrescreve self_identity com a identidade ATUAL (fecha o contorno de troca de remote)', () => {
      git(root, ['remote', 'set-url', 'origin', 'https://github.com/acme/widget-renamed.git']);
      const r = A.pin({ root });
      assertTrue(r.ok, `pin deveria passar: ${r.error}`);
      assertEqual(r.doc.self_identity, 'github.com/acme/widget-renamed', 'self_identity deveria refletir a identidade atual');
    });

    check('readEffectiveAllowlist: arquivo committed e inválido pelo schema é tratado como vazio e reportado', () => {
      const other = newFixtureRoot();
      mkdirSync(join(other, '.forge', 'liaison'), { recursive: true });
      writeFileSync(join(other, '.forge', 'liaison', 'allowed-workspaces.json'), JSON.stringify({ version: 1, allowed_workspaces: [{ id: 'x' }] }));
      commitAll(other, 'chore: cadastro invalido');
      const r = A.readEffectiveAllowlist({ root: other });
      assertEqual(r.doc.allowed_workspaces.length, 0, 'inválido deveria ser tratado como vazio');
      assertTrue(!!r.error, 'o motivo deveria ser reportado');
    });
  }

  // ---------------------------------------------------------------------------------------
  // native-containment.mjs — detector dos quatro tipos (TASK-12 item 1)
  // ---------------------------------------------------------------------------------------
  if (C && A) {
    check('detectContainment: sem nenhuma mudança (caso de controle) -> ok:true, findings vazio', () => {
      const root = newFixtureRoot();
      const r = C.detectContainment({ root });
      assertTrue(r.ok, `deveria conseguir medir: ${r.reason}`);
      assertEqual(r.findings.length, 0, 'não deveria haver achados');
    });

    check('allowlist-changed: edição não commitada do cadastro é achado sem range; some depois do commit', () => {
      const root = newFixtureRoot();
      mkdirSync(join(root, '.forge', 'liaison'), { recursive: true });
      writeFileSync(join(root, '.forge', 'liaison', 'allowed-workspaces.json'), JSON.stringify({ version: 1, allowed_workspaces: [] }));
      const r1 = C.detectContainment({ root });
      assertTrue(r1.ok, `deveria medir: ${r1.reason}`);
      assertTrue(r1.findings.some((f) => f.type === 'allowlist-changed'), 'edição não commitada deveria ser achado');
      commitAll(root, 'chore: cadastro');
      const r2 = C.detectContainment({ root });
      assertTrue(r2.ok, `deveria medir: ${r2.reason}`);
      assertFalse(r2.findings.some((f) => f.type === 'allowlist-changed'), 'depois do commit, sem nova edição, não deveria haver achado');
    });

    check('allowlist-changed: com range, diff entre as pontas detecta a mudança', () => {
      const root = newFixtureRoot();
      const refA = git(root, ['rev-parse', 'HEAD']);
      mkdirSync(join(root, '.forge', 'liaison'), { recursive: true });
      writeFileSync(join(root, '.forge', 'liaison', 'allowed-workspaces.json'), JSON.stringify({ version: 1, allowed_workspaces: [] }));
      const refB = commitAll(root, 'chore: cadastro via range');
      const r = C.detectContainment({ root, range: `${refA}..${refB}` });
      assertTrue(r.ok, `deveria medir: ${r.reason}`);
      assertTrue(r.findings.some((f) => f.type === 'allowlist-changed'), 'deveria detectar a mudança no range');
    });

    check('hook-line-changed: matcher alterado entre as pontas do intervalo é achado; sem intervalo não se aplica', () => {
      const root = newFixtureRoot();
      writeManifestLine(root, '^SendMessage$', 'armado');
      const refA = commitAll(root, 'chore: manifesto armado');
      const r0 = C.detectContainment({ root });
      assertFalse(r0.findings.some((f) => f.type === 'hook-line-changed'), 'sem intervalo, hook-line-changed não se aplica');
      writeManifestLine(root, '^Bash$', 'armado');
      const refB = commitAll(root, 'chore: matcher alterado');
      const r = C.detectContainment({ root, range: `${refA}..${refB}` });
      assertTrue(r.ok, `deveria medir: ${r.reason}`);
      assertTrue(r.findings.some((f) => f.type === 'hook-line-changed'), 'matcher alterado deveria ser achado');
    });

    check('hook-line-changed: linha removida entre as pontas é achado; range idêntico (A..A) não acha nada', () => {
      const root = newFixtureRoot();
      writeManifestLine(root, '^SendMessage$', 'armado');
      const refA = commitAll(root, 'chore: manifesto armado 2');
      const rNoChange = C.detectContainment({ root, range: `${refA}..${refA}` });
      assertTrue(rNoChange.ok, `deveria medir: ${rNoChange.reason}`);
      assertEqual(rNoChange.findings.length, 0, 'range idêntico não deveria achar nada');
      rmSync(join(root, '.forge', 'hooks', 'pre-tool-use', 'hooks.manifest'));
      const refB = commitAll(root, 'chore: manifesto removido');
      const r = C.detectContainment({ root, range: `${refA}..${refB}` });
      assertTrue(r.findings.some((f) => f.type === 'hook-line-changed'), 'linha removida deveria ser achado');
    });

    check('hook-unwired sem intervalo: consumidor existente com gancho SEMEADO INATIVO (nenhum hooks.manifest declarando) não é achado (controle negativo)', () => {
      const root = newFixtureRoot();
      writeSettingsWithGuard(root, false);
      commitAll(root, 'chore: settings sem o gancho novo');
      const r = C.detectContainment({ root });
      assertTrue(r.ok, `deveria medir: ${r.reason}`);
      assertFalse(r.findings.some((f) => f.type === 'hook-unwired'), 'gancho semeado inativo não deveria ser achado');
    });

    check('hook-unwired sem intervalo: manifesto do consumidor arma o gancho e .claude/settings.json atual não o contém -> achado', () => {
      const root = newFixtureRoot();
      writeManifestLine(root, '^SendMessage$', 'armado');
      writeSettingsWithGuard(root, false);
      commitAll(root, 'chore: manifesto arma mas settings não fia');
      const r = C.detectContainment({ root });
      assertTrue(r.ok, `deveria medir: ${r.reason}`);
      assertTrue(r.findings.some((f) => f.type === 'hook-unwired'), 'deveria ser achado');
    });

    check('hook-unwired com intervalo: fiação presente na ponta inicial e ausente na final -> achado', () => {
      const root = newFixtureRoot();
      writeSettingsWithGuard(root, true);
      const refA = commitAll(root, 'chore: settings com o gancho fiado');
      writeSettingsWithGuard(root, false);
      const refB = commitAll(root, 'chore: settings sem o gancho fiado');
      const r = C.detectContainment({ root, range: `${refA}..${refB}` });
      assertTrue(r.ok, `deveria medir: ${r.reason}`);
      assertTrue(r.findings.some((f) => f.type === 'hook-unwired'), 'deveria ser achado');
    });

    check('remote-identity-mismatch: self_identity cadastrado diverge do origin atual -> achado; iguais -> nada', () => {
      const root = newFixtureRoot();
      const pin1 = A.pin({ root });
      assertTrue(pin1.ok, `pin deveria passar: ${pin1.error}`);
      commitAll(root, 'chore: self_identity fixado');
      const rSame = C.detectContainment({ root });
      assertFalse(rSame.findings.some((f) => f.type === 'remote-identity-mismatch'), 'identidade igual não deveria ser achado');
      git(root, ['remote', 'set-url', 'origin', 'https://github.com/acme/outro.git']);
      const rDiff = C.detectContainment({ root });
      assertTrue(rDiff.findings.some((f) => f.type === 'remote-identity-mismatch'), 'identidade divergente deveria ser achado');
    });

    check('detectContainment: rc 2 (ok:false) — intervalo inválido, git indisponível e hooks.manifest corrompido nunca reportam "nada mudou"', () => {
      const root = newFixtureRoot();
      const rRange = C.detectContainment({ root, range: 'naoexiste..HEAD' });
      assertFalse(rRange.ok, 'intervalo inválido deveria ser ok:false');
      const rNoGit = C.detectContainment({ root: join(tmpdir(), 'nao-e-um-repo-git-' + Date.now()) });
      assertFalse(rNoGit.ok, 'diretório sem git deveria ser ok:false');
      writeFileSync(
        join(root, '.forge', 'hooks', 'pre-tool-use', 'hooks.manifest'),
        '# forge-manifest-format: 1\nguard-cross-session-send.sh\t^SendMessage$\tstdin-json\testado-desconhecido\n',
      );
      writeSettingsWithGuard(root, false);
      commitAll(root, 'chore: manifesto corrompido');
      const rCorrupt = C.detectContainment({ root });
      assertFalse(rCorrupt.ok, 'manifesto corrompido deveria ser ok:false (nunca "nada mudou")');
    });

    check('renderContainment: texto e markdown; lista vazia tem mensagem própria nos dois formatos', () => {
      const findings = [{ type: 'allowlist-changed', detail: 'x mudou' }];
      assertTrue(C.renderContainment(findings, 'text').includes('allowlist-changed'), 'texto deveria nomear o tipo');
      assertTrue(C.renderContainment(findings, 'markdown').includes('**allowlist-changed**'), 'markdown deveria nomear o tipo em negrito');
      assertTrue(C.renderContainment([], 'text').length > 0, 'texto vazio deveria ter mensagem própria');
      assertTrue(C.renderContainment([], 'markdown').length > 0, 'markdown vazio deveria ter mensagem própria');
    });
  }

  for (const fn of cleanups.reverse()) {
    try {
      fn();
    } catch {
      /* best-effort */
    }
  }

  if (failures > 0) {
    console.log(`\n${failures} de ${n} checagem(ns) reprovada(s).`);
    process.exit(1);
  }
  console.log(`\nPASS native-containment-gate.driver — ${n} checagens.`);
}

main().catch((err) => {
  console.log(`FAIL [${n + 1}] driver: exceção não tratada: ${err && err.stack ? err.stack : err}`);
  process.exit(1);
});
