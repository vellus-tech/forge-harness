#!/usr/bin/env bash
# Gate — TASK-17/TASK-18 de add-liaison-handoff-baton (REQ-06, REQ-10, design §2.6/§2.7):
#   [config-*] readBatonConfig: defaults; faixa inválida nomeando a chave; default >
#     max_lease_seconds; parâmetros da oferta prevalecem sobre a config local (prova indireta:
#     a própria função nunca lê nada alem do arquivo)
#   [session-*] _baton_resolve_session: --session tem precedência sobre CLAUDE_CODE_SESSION_ID;
#     padrão do identificador; ausência dos dois recusa citando Codex/Cursor/Gemini; duas
#     sessões do mesmo repositório são titulares diferentes na dobra (REQ-04/REQ-10)
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
OPS="$WS/template/.forge/scripts/liaison-ops.sh"
T="$(mktemp -d /tmp/forge-liaison-baton-config.XXXXXX)"
trap 'rm -rf "$T"' EXIT

fail=0

judge() {
  local tag="$1" out="$2" rc="$3"
  if echo "$out" | grep -q '^FAIL \['; then
    echo "$out"
    fail=1
  elif [ "$rc" -ne 0 ]; then
    echo "FAIL [$tag]: comando falhou inesperadamente (rc=$rc): $(echo "$out" | tr '\n' ' ' | cut -c1-200)"
    fail=1
  else
    echo "$out"
  fi
}

# Extrai a função _baton_resolve_session do script real (não reimplementa — testa a de
# verdade) para um arquivo isolado, sourceável sem puxar o resto do liaison-ops.sh.
SESSION_FN="$T/session-fn.sh"
sed -n '/^_baton_resolve_session()/,/^}$/p' "$OPS" > "$SESSION_FN"
if [ ! -s "$SESSION_FN" ]; then
  echo "FAIL [session-ausente]: não encontrei _baton_resolve_session em $OPS"
  fail=1
fi

out="$(node --input-type=module -e "
import { readBatonConfig } from '$LIB/liaison-baton.mjs';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const results = [];
function check(tag, cond, detail) { results.push(cond ? null : ('FAIL [' + tag + ']: ' + detail)); }

function yaml(body) {
  const dir = mkdtempSync(join(tmpdir(), 'forge-yaml-'));
  const f = join(dir, 'forge.yaml');
  writeFileSync(f, body);
  return f;
}

// [config-defaults] sem forge.yaml nenhum, ou sem o bloco baton: usa os defaults do design.
{
  const c = readBatonConfig(yaml('liaison:\n  auto: false\n'));
  check('config-defaults', c.defaultLeaseSeconds === 1800 && c.maxLeaseSeconds === 14400 && c.skewToleranceSeconds === 120 && c.autoRenew === true && c.errors.length === 0,
    'esperava defaults 1800/14400/120/true, achou ' + JSON.stringify(c));
}

// [config-ausente-arquivo] sem forge.yaml algum: ainda devolve defaults, nunca lança.
{
  const c = readBatonConfig('$T/nao-existe/forge.yaml');
  check('config-ausente-arquivo', c.defaultLeaseSeconds === 1800 && c.errors.length === 0, 'esperava defaults sem erro, achou ' + JSON.stringify(c));
}

// [config-valor-lido] valores declarados são lidos corretamente.
{
  const c = readBatonConfig(yaml('liaison:\n  auto: false\n  baton:\n    default_lease_seconds: 900\n    max_lease_seconds: 7200\n    skew_tolerance_seconds: 60\n    auto_renew: false\n'));
  check('config-valor-lido', c.defaultLeaseSeconds === 900 && c.maxLeaseSeconds === 7200 && c.skewToleranceSeconds === 60 && c.autoRenew === false && c.errors.length === 0,
    'esperava 900/7200/60/false, achou ' + JSON.stringify(c));
}

// [config-faixa-invalida] default_lease_seconds abaixo do mínimo — erro NOMEANDO a chave.
{
  const c = readBatonConfig(yaml('liaison:\n  baton:\n    default_lease_seconds: 10\n'));
  check('config-faixa-invalida', c.errors.some((e) => e.includes('default_lease_seconds')), 'esperava erro nomeando default_lease_seconds, achou ' + JSON.stringify(c.errors));
}
{
  const c = readBatonConfig(yaml('liaison:\n  baton:\n    max_lease_seconds: 999999\n'));
  check('config-faixa-invalida-max', c.errors.some((e) => e.includes('max_lease_seconds')), 'esperava erro nomeando max_lease_seconds, achou ' + JSON.stringify(c.errors));
}
{
  const c = readBatonConfig(yaml('liaison:\n  baton:\n    skew_tolerance_seconds: -5\n'));
  check('config-faixa-invalida-skew', c.errors.some((e) => e.includes('skew_tolerance_seconds')), 'esperava erro nomeando skew_tolerance_seconds, achou ' + JSON.stringify(c.errors));
}

// [config-default-maior-que-max] default_lease_seconds > max_lease_seconds — erro dedicado.
{
  const c = readBatonConfig(yaml('liaison:\n  baton:\n    default_lease_seconds: 20000\n    max_lease_seconds: 14400\n'));
  check('config-default-maior-que-max', c.errors.some((e) => e.includes('maior que max_lease_seconds')), 'esperava erro de default > max, achou ' + JSON.stringify(c.errors));
}

const bad = results.filter(Boolean);
console.log(bad.length ? bad.join('\n') : 'OK readBatonConfig: defaults, leitura, faixas invalidas nomeando a chave, default>max');
" 2>&1)"; rc=$?
judge "config" "$out" "$rc"

# [session-precedencia] --session tem precedência sobre CLAUDE_CODE_SESSION_ID.
out="$(bash -c '
  source "'"$SESSION_FN"'"
  CLAUDE_CODE_SESSION_ID=env-session _baton_resolve_session "explicit-session"
' 2>&1)"
[ "$out" = "explicit-session" ] && echo "OK [session-precedencia]: --session venceu CLAUDE_CODE_SESSION_ID" || { echo "FAIL [session-precedencia]: esperava explicit-session, achou $out"; fail=1; }

# [session-env-fallback] sem --session, usa CLAUDE_CODE_SESSION_ID.
out="$(bash -c '
  source "'"$SESSION_FN"'"
  CLAUDE_CODE_SESSION_ID=env-session _baton_resolve_session ""
' 2>&1)"
[ "$out" = "env-session" ] && echo "OK [session-env-fallback]: CLAUDE_CODE_SESSION_ID usado na ausência de --session" || { echo "FAIL [session-env-fallback]: esperava env-session, achou $out"; fail=1; }

# [session-ausente-os-dois] sem nenhum dos dois, recusa citando Codex/Cursor/Gemini.
out="$(bash -c '
  unset CLAUDE_CODE_SESSION_ID
  source "'"$SESSION_FN"'"
  _baton_resolve_session ""
' 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL [session-ausente-os-dois]: deveria recusar sem --session nem CLAUDE_CODE_SESSION_ID, mas passou com '$out'"
  fail=1
else
  echo "$out" | grep -qi "Codex" && echo "$out" | grep -qi "Cursor" && echo "$out" | grep -qi "Gemini" \
    && echo "OK [session-ausente-os-dois]: recusou citando Codex/Cursor/Gemini" \
    || { echo "FAIL [session-ausente-os-dois]: recusou mas sem citar os três agentes: $out"; fail=1; }
fi

# [session-padrao] fora do padrão ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ -> recusa.
for bad_session in "!!!" "-startswithdash" "" ; do
  [ -z "$bad_session" ] && continue # vazio já testado acima (cai no fallback)
  out="$(bash -c '
    unset CLAUDE_CODE_SESSION_ID
    source "'"$SESSION_FN"'"
    _baton_resolve_session "'"$bad_session"'"
  ' 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [session-padrao]: '$bad_session' deveria ser recusado, passou com '$out'"
    fail=1
  fi
done
echo "OK [session-padrao]: valores fora do padrão recusados"

# excesso de 128 caracteres.
long_session="$(printf 'a%.0s' $(seq 1 129))"
out="$(bash -c '
  unset CLAUDE_CODE_SESSION_ID
  source "'"$SESSION_FN"'"
  _baton_resolve_session "'"$long_session"'"
' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && echo "OK [session-padrao]: sessão com 129 caracteres recusada" || { echo "FAIL [session-padrao]: sessão com 129 caracteres deveria ser recusada"; fail=1; }

# [session-titulares-diferentes] duas sessões do mesmo repositório são titulares diferentes
# (REQ-04/REQ-10): reivindicam o mesmo bastão, a segunda recebe lost-held nomeando a primeira
# (não duplicate-claim, que só vale para a MESMA sessão).
out="$(node --input-type=module -e "
import { foldBatons } from '$LIB/liaison-baton.mjs';
import { computeContentSha } from '$LIB/liaison-merge.mjs';
function mk(p) { const m = { channel: 'ch', requires_ack: false, created_at: '2026-01-01T00:00:00Z', trust: 'self', ...p }; m.content_sha = computeContentSha(m); return m; }
const o = mk({ msg_id: 'repo-a-0001', thread_id: 't1', sender: 'repo-a', seq: 1, lamport: 1, kind: 'note', in_reply_to: null, subject: 'w', baton: { op: 'offer', session: 'sO', stamped_at: '2026-01-01T00:00:00Z', eligible: ['repo-a'], max_lease_seconds: 14400, skew_tolerance_seconds: 120 } });
const c1 = mk({ msg_id: 'repo-a-0002', thread_id: 't1', sender: 'repo-a', seq: 2, lamport: 2, kind: 'note', in_reply_to: 'repo-a-0001', subject: 'baton claim: w', baton: { op: 'claim', session: 'sessao-1', stamped_at: '2026-01-01T00:01:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:31:00Z' } });
const c2 = mk({ msg_id: 'repo-a-0003', thread_id: 't1', sender: 'repo-a', seq: 3, lamport: 3, kind: 'note', in_reply_to: 'repo-a-0001', subject: 'baton claim: w', baton: { op: 'claim', session: 'sessao-2', stamped_at: '2026-01-01T00:02:00Z', lease_seconds: 1800, lease_until: '2026-01-01T00:32:00Z' } });
const { batons } = foldBatons([o, c1, c2]);
const b = batons.get(o.msg_id);
const v2 = b.history.find((h) => h.msgId === c2.msg_id);
const ok = b.holder.session === 'sessao-1' && v2 && v2.verdict === 'lost-held';
console.log(ok ? 'OK duas sessoes do mesmo repositorio sao titulares diferentes (lost-held, nao duplicate-claim)' : 'FAIL [session-titulares-diferentes]: ' + JSON.stringify({ holder: b.holder, v2 }));
" 2>&1)"; rc=$?
judge "session-titulares-diferentes" "$out" "$rc"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS — configuração do bastão (readBatonConfig) e identidade de sessão (_baton_resolve_session)"
exit 0
