#!/usr/bin/env bash
# ORDINAL: w292 atribuído no merge de add-liaison-native-bridge
# Gate — empacotamento do gancho guard-cross-session-send.sh e passo de armar (TASK-18/19,
# STORY-10, REQ-10, NFR-02, design §4.4, §5):
#   [1] a linha nova de hooks.manifest.default casa, campo a campo (TAB), a linha do design §4.4;
#   [2] a fiação do gancho é DERIVADA do manifesto — nenhum literal novo com o nome do gancho em
#       sync-adapters.mjs (prova de que a fiação não precisou de um caso especial no código);
#   [3] consumidor com .claude/settings.json pré-existente (sem hooks.manifest) recebe o gancho
#       INATIVO e NOMEADO no aviso do sync (regra vigente para hook novo que chega depois);
#   [4] instalação nova (sem .claude/settings.json) recebe o gancho ARMADO, com matcher
#       ^SendMessage$;
#   [5] passo de armar do §5 num consumidor existente que já tem os QUATRO ganchos de hoje
#       (enforce-worktree-location.sh, prevent-secrets-leak.sh, check-language-policy.sh,
#       validate-naming-conventions.sh) fiados à mão: depois de migrar para hooks.manifest
#       canônico (marcador, matcher e contrato EFETIVOS, estado `armado` para os quatro, e a linha
#       nova também `armado`) e rodar o sync, os quatro continuam fiados com o MESMO matcher, e o
#       gancho novo passa a estar fiado também;
#   [6] controle: manifesto SEM marcador (projeção) ao qual só se acrescenta a linha nova (sem
#       fiar o gancho em settings.json) NÃO arma o gancho — só acrescentar a linha não basta, é
#       preciso o passo 3 do §5 (migrar para canônico com estado explícito);
#   [7] varredura de imports dos arquivos novos do change (native-*.mjs, liaison-pointer.mjs, o
#       gancho .sh) — só `node:*` ou caminho relativo (NFR-02);
#   [8] package.json sem dependência nova em relação ao merge-base com origin/develop (NFR-02).
set -euo pipefail
# Isolamento git (LDG-0201): GIT_* herdado do ambiente faria os comandos git deste gate obedecerem
# ao repositório de quem o invocou, nunca às fixtures sintéticas criadas aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR_REL=".forge/hooks/pre-tool-use"
GUARD_HOOK="guard-cross-session-send.sh"
TMPROOT="${TMPDIR:-/tmp}"
T="$(mktemp -d "$TMPROOT/forge-native-hook-packaging.XXXXXX")"
trap 'rm -rf "$T"' EXIT

n=0
fail=0
ok() { n=$((n + 1)); echo "OK [$n] $1"; }
bad() { n=$((n + 1)); fail=$((fail + 1)); echo "FAIL [$n] $1"; }

# describe-wiring.mjs — para um settings.json, devolve { "<basename.sh>": ["<matcher>", ...] } de
# todo gancho alcançável em hooks.PreToolUse. Vive no diretório temporário do gate (infraestrutura
# de teste, não do produto).
cat > "$T/describe-wiring.mjs" <<'NODE'
import { readFileSync, existsSync } from 'node:fs';
const path = process.argv[2];
if (!existsSync(path)) { console.log('{}'); process.exit(0); }
const j = JSON.parse(readFileSync(path, 'utf8'));
const groups = (j.hooks && j.hooks.PreToolUse) || [];
const out = {};
for (const g of groups) {
  for (const h of (g.hooks || [])) {
    const parts = String(h.command).trim().split(/\s+/);
    const last = parts[parts.length - 1];
    const base = last.split('/').pop();
    if (!out[base]) out[base] = [];
    out[base].push(g.matcher);
  }
}
console.log(JSON.stringify(out));
NODE

wiring_of() { node "$T/describe-wiring.mjs" "$1"; }

hook_matchers() { # hook_matchers <settings.json> <hook.sh> — matchers (um por linha) do gancho
  node -e '
    const out = JSON.parse(process.argv[2]);
    for (const m of (out[process.argv[3]] || [])) console.log(m);
  ' "$(wiring_of "$1")" "$2" 2>/dev/null \
    || node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const groups = (j.hooks && j.hooks.PreToolUse) || [];
      for (const g of groups) for (const h of (g.hooks || [])) {
        const parts = String(h.command).trim().split(/\s+/);
        const last = parts[parts.length - 1].split("/").pop();
        if (last === process.argv[2]) console.log(g.matcher);
      }
    ' "$1" "$2"
}

is_active() { # is_active <settings.json> <hook.sh> — "true"/"false"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    if (!fs.existsSync(p)) { console.log("false"); process.exit(0); }
    const j = JSON.parse(fs.readFileSync(p, "utf8"));
    const groups = (j.hooks && j.hooks.PreToolUse) || [];
    let found = false;
    for (const g of groups) for (const h of (g.hooks || [])) {
      const parts = String(h.command).trim().split(/\s+/);
      const last = parts[parts.length - 1].split("/").pop();
      if (last === process.argv[2]) found = true;
    }
    console.log(found ? "true" : "false");
  ' "$1" "$2"
}

nova_fixture() { # nova_fixture <dir>
  local dir="$1"
  mkdir -p "$dir"
  cp -R "$WS/template/.forge" "$dir/.forge"
  perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture do native-hook-packaging-gate/g' \
    "$dir/.forge/FORGE.md" "$dir/.forge/constitution.md" "$dir/.forge/context.md"
}

# --- [1] linha nova de hooks.manifest.default casa o design §4.4 ------------------------------
echo "[1] hooks.manifest.default — linha de $GUARD_HOOK igual ao design §4.4"
EXPECTED_LINE="$(printf 'guard-cross-session-send.sh\t^SendMessage$\tstdin-json\tarmado\trazao=segredo, destino declarado e contenção por workspace antes de a mensagem sair para outra sessão')"
if grep -qxF "$EXPECTED_LINE" "$WS/template/$HOOKS_DIR_REL/hooks.manifest.default"; then
  ok "linha presente e idêntica ao design §4.4"
else
  bad "linha de $GUARD_HOOK ausente ou diferente do design §4.4 em hooks.manifest.default (manifest)"
fi

# --- [2] fiação derivada: sem literal novo em sync-adapters.mjs -------------------------------
echo "[2] sync-adapters.mjs não tem literal novo com o nome do gancho — fiação é derivada do manifesto"
if grep -q "$GUARD_HOOK" "$WS/template/.forge/scripts/lib/sync-adapters.mjs"; then
  bad "sync-adapters.mjs contém o literal '$GUARD_HOOK' — a fiação deveria ser derivada só do manifesto, sem caso especial no código"
else
  ok "sync-adapters.mjs sem literal '$GUARD_HOOK' — fiação puramente derivada"
fi

# --- [3] consumidor com settings.json pré-existente recebe o gancho inativo e nomeado ----------
echo "[3] consumidor existente (settings.json pré-existente, sem hooks.manifest) — gancho novo nasce inativo e nomeado"
T3="$T/consumidor-existente"
nova_fixture "$T3"
mkdir -p "$T3/.claude"
cat > "$T3/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] }
    ]
  }
}
JSON
OUT3="$(bash "$T3/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
ACTIVE3="$(is_active "$T3/.claude/settings.json" "$GUARD_HOOK")"
if [ "$ACTIVE3" = "true" ]; then
  bad "consumidor existente sem declarar o gancho novo deveria nascer inativo, e nasceu ARMADO (desarme/armadura silenciosa): $OUT3"
elif ! printf '%s' "$OUT3" | grep -q "$GUARD_HOOK"; then
  bad "consumidor existente: gancho novo não foi nomeado no aviso do sync (deveria aparecer, mesmo inativo): $OUT3"
else
  ok "gancho novo inativo e nomeado no aviso do sync"
fi

# --- [4] instalação nova recebe o gancho armado -------------------------------------------------
echo "[4] instalação nova (sem settings.json) — gancho novo nasce armado, matcher ^SendMessage\$"
T4="$T/instalacao-nova"
nova_fixture "$T4"
bash "$T4/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
ACTIVE4="$(is_active "$T4/.claude/settings.json" "$GUARD_HOOK")"
MATCHER4="$(hook_matchers "$T4/.claude/settings.json" "$GUARD_HOOK" | head -1)"
if [ "$ACTIVE4" != "true" ]; then
  bad "instalação nova deveria armar $GUARD_HOOK por padrão e não armou"
elif [ "$MATCHER4" != '^SendMessage$' ]; then
  bad "instalação nova armou $GUARD_HOOK com matcher '$MATCHER4' — esperado '^SendMessage\$'"
else
  ok "instalação nova — $GUARD_HOOK armado com matcher ^SendMessage\$"
fi

# --- [5] passo de armar do §5 num consumidor com os quatro ganchos de hoje já fiados ------------
echo "[5] passo de armar (§5) — consumidor com os quatro ganchos de hoje fiados mantém os quatro e arma o novo"
T5="$T/consumidor-quatro-fiados"
nova_fixture "$T5"
mkdir -p "$T5/.claude"
cat > "$T5/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] },
      { "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] },
      { "matcher": "^(Write|Edit|MultiEdit)$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/check-language-policy.sh" } ] },
      { "matcher": "^(Write|Edit|MultiEdit)$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/validate-naming-conventions.sh" } ] }
    ]
  }
}
JSON
# Passo 2/3 do §5: migrar/criar hooks.manifest CANÔNICO (marcador) do consumidor, com matcher e
# contrato EFETIVOS (os que o doctor mostraria) e estado `armado` para os quatro ganchos de hoje,
# mais a linha nova também `armado`.
cat > "$T5/.forge/hooks/pre-tool-use/hooks.manifest" <<'MANIFEST'
# forge-manifest-format: 1
#hook	matcher	contrato	estado	[chave=valor …]
enforce-worktree-location.sh	^Bash$	stdin-json	armado
prevent-secrets-leak.sh	^(Write|Edit|MultiEdit|NotebookEdit)$	stdin-json	armado
check-language-policy.sh	^(Write|Edit|MultiEdit)$	argv	armado	universo=.cs
validate-naming-conventions.sh	^(Write|Edit|MultiEdit)$	argv	armado	universo=.cs
guard-cross-session-send.sh	^SendMessage$	stdin-json	armado
MANIFEST
OUT5="$(bash "$T5/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
FAIL5=""
for existente in enforce-worktree-location.sh:^Bash$ prevent-secrets-leak.sh:'^(Write|Edit|MultiEdit|NotebookEdit)$' check-language-policy.sh:'^(Write|Edit|MultiEdit)$' validate-naming-conventions.sh:'^(Write|Edit|MultiEdit)$'; do
  hook="${existente%%:*}"
  matcher_esperado="${existente#*:}"
  ativo="$(is_active "$T5/.claude/settings.json" "$hook")"
  matcher_obtido="$(hook_matchers "$T5/.claude/settings.json" "$hook" | head -1)"
  if [ "$ativo" != "true" ]; then
    FAIL5="$FAIL5; '$hook' deveria continuar fiado e saiu inativo"
  elif [ "$matcher_obtido" != "$matcher_esperado" ]; then
    FAIL5="$FAIL5; '$hook' matcher mudou de '$matcher_esperado' para '$matcher_obtido'"
  fi
done
ATIVO_NOVO5="$(is_active "$T5/.claude/settings.json" "$GUARD_HOOK")"
if [ "$ATIVO_NOVO5" != "true" ]; then
  FAIL5="$FAIL5; $GUARD_HOOK deveria ficar armado depois do passo de armar e não ficou"
fi
if [ -n "$FAIL5" ]; then
  bad "passo de armar do §5 (consumidor com os quatro fiados)$FAIL5. Saída do sync: $OUT5"
else
  ok "os quatro ganchos de hoje continuam fiados com matcher efetivo preservado, e $GUARD_HOOK passou a estar armado"
fi

# --- [6] controle: manifesto sem marcador + só a linha nova não arma ---------------------------
echo "[6] controle — manifesto sem marcador ao qual só se acrescenta a linha nova NÃO arma o gancho"
T6="$T/consumidor-so-linha-nova"
nova_fixture "$T6"
mkdir -p "$T6/.claude"
cat > "$T6/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] }
    ]
  }
}
JSON
# Manifesto SEM marcador (projeção), com a linha nova acrescentada mas o gancho NÃO fiado em
# settings.json — a projeção deriva a ativação só da fiação JÁ OBSERVADA, nunca do texto da linha.
cat > "$T6/.forge/hooks/pre-tool-use/hooks.manifest" <<'MANIFEST'
enforce-worktree-location.sh	^Bash$	stdin-json
guard-cross-session-send.sh	^SendMessage$	stdin-json
MANIFEST
OUT6="$(bash "$T6/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
ATIVO6="$(is_active "$T6/.claude/settings.json" "$GUARD_HOOK")"
if [ "$ATIVO6" = "true" ]; then
  bad "controle: só acrescentar a linha nova (sem o passo de armar) armou o gancho — deveria continuar inativo. Saída: $OUT6"
else
  ok "controle confirmado — só acrescentar a linha não arma; o passo de armar (migrar para canônico) é necessário"
fi

# --- [7] varredura de imports dos arquivos novos do change --------------------------------------
echo "[7] imports dos arquivos novos do change — só node:* ou caminho relativo (NFR-02)"
cat > "$T/scan-imports.mjs" <<'NODE'
import { readFileSync } from 'node:fs';
const files = process.argv.slice(2);
const bad = [];
const RE = /^\s*import\s+(?:[^"']+?\s+from\s+)?["']([^"']+)["']\s*;?/gm;
for (const f of files) {
  const text = readFileSync(f, 'utf8');
  let m;
  while ((m = RE.exec(text))) {
    const spec = m[1];
    if (!spec.startsWith('node:') && !spec.startsWith('./') && !spec.startsWith('../')) {
      bad.push(`${f}: ${spec}`);
    }
  }
}
console.log(JSON.stringify(bad));
NODE
NEW_MJS_FILES=(
  "$WS/template/.forge/scripts/lib/native-classes.mjs"
  "$WS/template/.forge/scripts/lib/native-transcript.mjs"
  "$WS/template/.forge/scripts/lib/native-registry.mjs"
  "$WS/template/.forge/scripts/lib/native-workspace.mjs"
  "$WS/template/.forge/scripts/lib/native-allowlist.mjs"
  "$WS/template/.forge/scripts/lib/native-containment.mjs"
  "$WS/template/.forge/scripts/lib/native-send-guard.mjs"
  "$WS/template/.forge/scripts/lib/liaison-pointer.mjs"
)
IMPORTS_RUIM="$(node "$T/scan-imports.mjs" "${NEW_MJS_FILES[@]}")"
if [ "$IMPORTS_RUIM" != "[]" ]; then
  bad "import fora de node:*/relativo nos arquivos novos: $IMPORTS_RUIM"
else
  ok "todos os imports dos .mjs novos são node:* ou caminho relativo"
fi
# O gancho .sh novo: só invoca `node` com caminho relativo resolvido pelo próprio script, sem
# `npm`/`npx`/binário externo.
GANCHO_SH="$WS/template/$HOOKS_DIR_REL/$GUARD_HOOK"
if grep -qE '\b(npm|npx|pip|pip3|curl|wget|nc|socat)\b' "$GANCHO_SH"; then
  bad "$GUARD_HOOK invoca ferramenta externa fora de node/git — grep achou npm/npx/pip/curl/wget/nc/socat"
else
  ok "$GUARD_HOOK não invoca ferramenta externa fora de node"
fi

# --- [8] package.json sem dependência nova vs merge-base com origin/develop --------------------
echo "[8] package.json sem dependência nova em relação ao merge-base com origin/develop (NFR-02)"
MERGE_BASE="$(git -C "$WS" merge-base HEAD origin/develop 2>/dev/null || true)"
if [ -z "$MERGE_BASE" ]; then
  bad "não foi possível calcular o merge-base de HEAD com origin/develop — contagem de dependências não verificável"
else
  BASE_PKG="$(git -C "$WS" show "$MERGE_BASE:package.json" 2>/dev/null || echo '{}')"
  CUR_PKG="$(cat "$WS/package.json")"
  DEP_DIFF="$(node -e '
    const base = JSON.parse(process.argv[1]);
    const cur = JSON.parse(process.argv[2]);
    const keysOf = (o, k) => Object.keys((o && o[k]) || {}).sort();
    const added = [];
    for (const k of ["dependencies", "devDependencies"]) {
      const baseKeys = new Set(keysOf(base, k));
      for (const name of keysOf(cur, k)) if (!baseKeys.has(name)) added.push(`${k}.${name}`);
    }
    console.log(JSON.stringify(added));
  ' "$BASE_PKG" "$CUR_PKG")"
  if [ "$DEP_DIFF" != "[]" ]; then
    bad "package.json ganhou dependência nova em relação ao merge-base com origin/develop: $DEP_DIFF"
  else
    ok "package.json sem dependência nova em relação ao merge-base com origin/develop"
  fi
fi

echo "---"
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail de $n checagem(ns) reprovada(s)"
  exit 1
fi
echo "RESULT: $n de $n checagem(ns) ok"
