#!/usr/bin/env bash
# ORDINAL: w293 atribuído no merge de add-liaison-native-bridge
# Gate — pontos de chamada do detector native containment (TASK-20/21, STORY-11, REQ-12, design
# §2.7): pre-push lista as mudanças do intervalo enviado sem bloquear; doctor soma, no estado
# atual, os tipos que o design reserva a ele, os avisos de cruzamento de participantes e os
# avisos extras (gancho inativo, self_identity ausente, disableAllHooks/sobreposição de settings,
# edição não commitada, cadastro do HEAD divergente do upstream); cenário do revisor (recusa do
# CLI, edição direta + push aparecendo nos três pontos); e gate de texto (prepare-pr.md e ship.md,
# template e plugin, invocam o detector; ship.md, yolo-gate.md e autonomy-yolo.md exigem merge
# humano com mudança de contenção).
#
# Nota de design (não é desvio): `hook-line-changed` só se mede COM intervalo
# (native-containment.mjs, detectHookLineChanged: "sem intervalo este tipo não se aplica") e o
# doctor roda SEM intervalo (design §2.7: "o doctor roda sem intervalo"). Por isso o doctor nunca
# reporta `hook-line-changed` — quem cobre esse tipo é o pre-push e prepare-pr/ship, que SEMPRE
# chamam o detector com `--range`. Os quatro tipos, somados, aparecem nos três pontos; nenhum
# ponto isolado precisa reportar os quatro sozinho. Este gate testa `allowlist-changed`,
# `hook-unwired` e `remote-identity-mismatch` no doctor, e `allowlist-changed` via intervalo no
# pre-push/CLI (cobertura equivalente de `hook-line-changed` já está em
# tests/w289-native-containment-gate.sh, que testa o detector diretamente).
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPROOT="${TMPDIR:-/tmp}"
T="$(mktemp -d "$TMPROOT/forge-native-containment-wiring.XXXXXX")"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

n=0
fail=0
ok() { n=$((n + 1)); echo "OK [$n] $1"; }
bad() { n=$((n + 1)); fail=$((fail + 1)); echo "FAIL [$n] $1"; }

mk_repo() { # mk_repo <dir> — fixture completa do harness, com remote e commit inicial
  local dir="$1"
  mkdir -p "$dir"
  cp -R "$WS/template/.forge" "$dir/.forge"
  perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture do native-containment-wiring-gate/g' \
    "$dir/.forge/FORGE.md" "$dir/.forge/constitution.md" "$dir/.forge/context.md"
  printf '# fixture\n' > "$dir/README.md"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email fixture@test
  git -C "$dir" config user.name Fixture
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" remote add origin https://github.com/acme/widget.git
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: init"
  bash "$dir/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  git -C "$dir" add -A >/dev/null
  git -C "$dir" commit -q -m "chore: sync" >/dev/null 2>&1 || true
}

run_doctor() { # run_doctor <dir> — roda o doctor isolado de ~/.claude/settings.json real
  FORGE_ROOT="$1" FORGE_CLAUDE_USER_SETTINGS="$1/.nonexistent-user-settings.json" \
    bash "$WS/template/.forge/scripts/doctor.sh" --report 2>&1
}

push_out() { # push_out <dir> <stdin-feed> — invoca o pre-push pelo canal real (stdin de refs)
  printf '%s' "$2" | (cd "$1" && bash "$1/.forge/hooks/git/pre-push" origin "file://$1" 2>&1)
}

ZERO=0000000000000000000000000000000000000000

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo A — pre-push: lista as mudanças do intervalo, nunca bloqueia
# ═══════════════════════════════════════════════════════════════════════════════════════════
RA="$T/repo-a"
mk_repo "$RA"
OLDSHA="$(git -C "$RA" rev-parse HEAD)"
cat > "$RA/.forge/liaison/allowed-workspaces.json" <<'JSON'
{
  "version": 1,
  "self_identity": "github.com/acme/widget",
  "allowed_workspaces": [
    { "id": "github.com/acme/other", "reason": "teste", "granted_by": "op@test", "granted_at": "2026-10-30T00:00:00Z" }
  ]
}
JSON
git -C "$RA" add -A >/dev/null
git -C "$RA" commit -q -m "chore: cadastro inicial"
NEWSHA="$(git -C "$RA" rev-parse HEAD)"
# Commit adicional que NÃO toca nada de contenção, para o controle [A2]: precisa de pelo menos um
# commit real no intervalo (senão o gate no-ai-attribution já existente reprova por "universo
# vazio" — instrumento quebrado — e não por ausência de violação; ver nota em [A2]).
printf '# fixture\n\nlinha inofensiva\n' > "$RA/README.md"
git -C "$RA" commit -q -am "chore: mudança sem relação com contenção"
HARMLESS_SHA="$(git -C "$RA" rev-parse HEAD)"

echo "[A1] pre-push — ref existente com mudança de contenção no intervalo: reporta sem bloquear"
feedA1="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$NEWSHA" "$OLDSHA")"
outA1="$(push_out "$RA" "$feedA1")"; rcA1=$?
if [ "$rcA1" -ne 0 ]; then
  bad "pre-push saiu rc=$rcA1 (esperado 0 — avisa, nunca bloqueia). Saída: $outA1"
elif ! printf '%s' "$outA1" | grep -q "allowlist-changed"; then
  bad "pre-push não mencionou allowlist-changed no intervalo $OLDSHA..$NEWSHA. Saída: $outA1"
else
  ok "pre-push reportou allowlist-changed, rc 0 (não bloqueou)"
fi

echo "[A2] controle — pre-push sem mudança de contenção no intervalo (commit real, mas alheio): sem menção a contenção"
feedA2="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$HARMLESS_SHA" "$NEWSHA")"
outA2="$(push_out "$RA" "$feedA2")"; rcA2=$?
if [ "$rcA2" -ne 0 ]; then
  bad "pre-push (sem mudança) saiu rc=$rcA2 — esperado 0. Saída: $outA2"
elif printf '%s' "$outA2" | grep -qE "allowlist-changed|hook-line-changed|hook-unwired|remote-identity-mismatch"; then
  bad "pre-push reportou mudança de contenção sem ter havido nenhuma (falso positivo). Saída: $outA2"
else
  ok "controle confirmado — nenhuma menção a contenção quando o intervalo não mudou nada"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo B — doctor (estado atual): allowlist-changed (uncommitted), hook-unwired,
# remote-identity-mismatch, e o caso sem mudança (controle negativo)
# ═══════════════════════════════════════════════════════════════════════════════════════════
RB="$T/repo-b"
mk_repo "$RB"
mkdir -p "$RB/.forge/liaison"
cat > "$RB/.forge/liaison/allowed-workspaces.json" <<'JSON'
{
  "version": 1,
  "self_identity": "github.com/acme/widget",
  "allowed_workspaces": []
}
JSON
git -C "$RB" add -A >/dev/null
git -C "$RB" commit -q -m "chore: cadastro com self_identity"

echo "[B1] doctor — caso sem mudança: nenhum dos tipos de contenção aparece (controle negativo)"
outB1="$(run_doctor "$RB")"
if printf '%s' "$outB1" | grep -qE "CONTENÇÃO: (allowlist-changed|hook-unwired|remote-identity-mismatch)"; then
  bad "doctor reportou mudança de contenção sem ter havido nenhuma. Saída relevante: $(printf '%s' "$outB1" | grep CONTENÇÃO)"
else
  ok "controle confirmado — doctor sem achado de contenção no estado estável"
fi

echo "[B2] doctor — allowlist-changed (edição NÃO commitada do cadastro)"
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const j = JSON.parse(fs.readFileSync(p, "utf8"));
  j.allowed_workspaces.push({ id: "github.com/acme/third", reason: "x", granted_by: "op@test", granted_at: "2026-10-30T01:00:00Z" });
  fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
' "$RB/.forge/liaison/allowed-workspaces.json"
outB2="$(run_doctor "$RB")"
git -C "$RB" checkout -q -- .forge/liaison/allowed-workspaces.json
if ! printf '%s' "$outB2" | grep -q "CONTENÇÃO: allowlist-changed"; then
  bad "doctor não reportou allowlist-changed com edição não commitada. Saída: $(printf '%s' "$outB2" | grep CONTENÇÃO || echo '(nenhuma linha CONTENÇÃO)')"
else
  ok "doctor reportou allowlist-changed para a edição não commitada"
fi

echo "[B3] doctor — hook-unwired (manifesto do consumidor declara armado; settings.json não contém)"
cat > "$RB/.forge/hooks/pre-tool-use/hooks.manifest" <<'MANIFEST'
# forge-manifest-format: 1
#hook	matcher	contrato	estado	[chave=valor …]
enforce-worktree-location.sh	^Bash$	stdin-json	armado
prevent-secrets-leak.sh	^(Write|Edit|MultiEdit|NotebookEdit)$	stdin-json	armado
check-language-policy.sh	^(Write|Edit|MultiEdit)$	argv	retido:dotnet
validate-naming-conventions.sh	^(Write|Edit|MultiEdit)$	argv	retido:dotnet
guard-cross-session-send.sh	^SendMessage$	stdin-json	armado
MANIFEST
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  const j = JSON.parse(fs.readFileSync(p, "utf8"));
  j.hooks.PreToolUse = j.hooks.PreToolUse.filter((g) => !JSON.stringify(g).includes("guard-cross-session-send"));
  fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
' "$RB/.claude/settings.json"
outB3="$(run_doctor "$RB")"
if ! printf '%s' "$outB3" | grep -q "CONTENÇÃO: hook-unwired"; then
  bad "doctor não reportou hook-unwired com o manifesto declarando armado e settings.json sem o gancho. Saída: $(printf '%s' "$outB3" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "doctor reportou hook-unwired"
fi
rm -f "$RB/.forge/hooks/pre-tool-use/hooks.manifest"
bash "$RB/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1

echo "[B4] doctor — remote-identity-mismatch (origin mudou depois do self_identity cadastrado)"
git -C "$RB" remote set-url origin https://github.com/acme/renamed.git
outB4="$(run_doctor "$RB")"
git -C "$RB" remote set-url origin https://github.com/acme/widget.git
if ! printf '%s' "$outB4" | grep -q "CONTENÇÃO: remote-identity-mismatch"; then
  bad "doctor não reportou remote-identity-mismatch após troca de remote. Saída: $(printf '%s' "$outB4" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "doctor reportou remote-identity-mismatch"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo C — doctor: avisos de cruzamento de participantes de canal
# ═══════════════════════════════════════════════════════════════════════════════════════════
RC="$T/repo-c"
mk_repo "$RC"
cat > "$RC/.forge/liaison/allowed-workspaces.json" <<'JSON'
{
  "version": 1,
  "self_identity": "github.com/acme/widget",
  "allowed_workspaces": [
    { "id": "github.com/acme/orphan", "reason": "teste", "granted_by": "op@test", "granted_at": "2026-10-30T00:00:00Z" }
  ]
}
JSON
THIRD="$T/thirdparty-c"
mkdir -p "$THIRD"
git -C "$THIRD" init -q
git -C "$THIRD" remote add origin https://github.com/acme/thirdparty.git
mkdir -p "$RC/.forge/liaison"
cat > "$RC/.forge/liaison/liaison.yaml" <<YAML
self:
  id: widget
channels:
  contracts:
    participants:
      - same-ws
      - no-peer
      - other-ws
    peers:
      same-ws: "$RC"
      other-ws: "$THIRD"
YAML
git -C "$RC" add -A >/dev/null
git -C "$RC" commit -q -m "chore: cadastro e canal"
outC="$(run_doctor "$RC")"

echo "[C1] doctor — participante com peer-path em workspace NÃO cadastrado"
if ! printf '%s' "$outC" | grep -q "other-ws' resolve para 'github.com/acme/thirdparty', não cadastrado"; then
  bad "doctor não avisou sobre 'other-ws' resolvendo para workspace não cadastrado. Saída: $(printf '%s' "$outC" | grep CONTENÇÃO)"
else
  ok "aviso de participante não cadastrado presente"
fi

echo "[C2] doctor — participante sem peer-path: 'não verificável'"
if ! printf '%s' "$outC" | grep -q "no-peer' sem peer-path configurado"; then
  bad "doctor não avisou sobre 'no-peer' sem peer-path. Saída: $(printf '%s' "$outC" | grep CONTENÇÃO)"
else
  ok "aviso de participante sem peer-path presente ('não verificável')"
fi

echo "[C3] doctor — cadastro ativo sem participante correspondente"
if ! printf '%s' "$outC" | grep -q "workspace cadastrado ativo 'github.com/acme/orphan' não corresponde"; then
  bad "doctor não avisou sobre cadastro ativo órfão. Saída: $(printf '%s' "$outC" | grep CONTENÇÃO)"
else
  ok "aviso de cadastro ativo sem participante correspondente presente"
fi

echo "[C4] controle — participante no MESMO workspace não gera aviso"
if printf '%s' "$outC" | grep -q "same-ws"; then
  bad "doctor gerou aviso para 'same-ws' (mesmo workspace) — não deveria. Saída: $(printf '%s' "$outC" | grep CONTENÇÃO)"
else
  ok "controle confirmado — participante no mesmo workspace sem aviso"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo D — doctor: avisos extras (notas de convergência)
# ═══════════════════════════════════════════════════════════════════════════════════════════
RD="$T/repo-d"
mk_repo "$RD"

echo "[D1] doctor — self_identity ausente (nenhum cadastro ainda)"
outD1="$(run_doctor "$RD")"
if ! printf '%s' "$outD1" | grep -q "self_identity não cadastrado"; then
  bad "doctor não avisou self_identity ausente. Saída: $(printf '%s' "$outD1" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "aviso de self_identity ausente presente"
fi

echo "[D2] doctor — gancho de saída inativo (settings.json sem guard-cross-session-send.sh, retido pelo manifesto)"
cat > "$RD/.forge/hooks/pre-tool-use/hooks.manifest" <<'MANIFEST'
# forge-manifest-format: 1
#hook	matcher	contrato	estado	[chave=valor …]
enforce-worktree-location.sh	^Bash$	stdin-json	armado
prevent-secrets-leak.sh	^(Write|Edit|MultiEdit|NotebookEdit)$	stdin-json	armado
check-language-policy.sh	^(Write|Edit|MultiEdit)$	argv	retido:dotnet
validate-naming-conventions.sh	^(Write|Edit|MultiEdit)$	argv	retido:dotnet
guard-cross-session-send.sh	^SendMessage$	stdin-json	retido:teste
MANIFEST
bash "$RD/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
outD2="$(run_doctor "$RD")"
if ! printf '%s' "$outD2" | grep -q "gancho de saída guard-cross-session-send.sh inativo"; then
  bad "doctor não avisou gancho de saída inativo. Saída: $(printf '%s' "$outD2" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "aviso de gancho de saída inativo presente"
fi
rm -f "$RD/.forge/hooks/pre-tool-use/hooks.manifest"
bash "$RD/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1

echo "[D3] doctor — disableAllHooks=true em settings.local.json"
printf '{"disableAllHooks": true}\n' > "$RD/.claude/settings.local.json"
outD3="$(run_doctor "$RD")"
rm -f "$RD/.claude/settings.local.json"
if ! printf '%s' "$outD3" | grep -q "disableAllHooks=true em"; then
  bad "doctor não avisou disableAllHooks. Saída: $(printf '%s' "$outD3" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "aviso de disableAllHooks presente"
fi

echo "[D4] doctor — cadastro do HEAD do tronco diferente do upstream"
BARE="$T/repo-d-bare.git"
git init -q --bare "$BARE"
git -C "$RD" remote remove origin
git -C "$RD" remote add origin "$BARE"
git -C "$RD" push -q -u origin HEAD:main
mkdir -p "$RD/.forge/liaison"
printf '{"version": 1, "self_identity": "x", "allowed_workspaces": []}\n' > "$RD/.forge/liaison/allowed-workspaces.json"
git -C "$RD" add -A >/dev/null
git -C "$RD" commit -q -m "chore: cadastro local não publicado"
outD4="$(run_doctor "$RD")"
if ! printf '%s' "$outD4" | grep -q "cadastro commitado e ainda não publicado"; then
  bad "doctor não avisou cadastro do HEAD divergente do upstream. Saída: $(printf '%s' "$outD4" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "aviso de cadastro do HEAD divergente do upstream presente"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo E — cenário do revisor: recusa do CLI, edição direta + push, visível nos três pontos
# ═══════════════════════════════════════════════════════════════════════════════════════════
RE="$T/repo-e"
mk_repo "$RE"
OLDSHA_E="$(git -C "$RE" rev-parse HEAD)"

# O cenário é SEMPRE o de sessão de agente, qualquer que seja quem roda o gate (terminal humano,
# CI, run-all ou uma sessão do Claude Code): o marcador de ambiente é fixado aqui, em vez de
# depender do ancestral `claude` real do processo que invocou o gate (code-evaluator PR #245,
# QUAL-001 — fora de uma sessão o `allow` passava e o gate reprovava).
echo "[E1] cenário do revisor — native allow recusa dentro de sessão de agente (marcador CLAUDECODE fixado)"
OUTE1="$(CLAUDECODE=1 FORGE_ROOT="$RE" bash "$RE/.forge/scripts/liaison-ops.sh" native allow github.com/acme/other --reason "tentativa do agente" 2>&1)"
RCE1=$?
if [ "$RCE1" -eq 0 ]; then
  bad "native allow deveria recusar com marcador de sessão de agente e saiu rc 0: $OUTE1"
elif [ -f "$RE/.forge/liaison/allowed-workspaces.json" ]; then
  bad "native allow recusou mas tocou o arquivo de cadastro (deveria permanecer ausente): $OUTE1"
else
  ok "native allow recusou (rc $RCE1), cadastro intocado"
fi

echo "[E2] cenário do revisor — edição direta do cadastro (sem CLI), ainda sem commit"
mkdir -p "$RE/.forge/liaison"
cat > "$RE/.forge/liaison/allowed-workspaces.json" <<'JSON'
{
  "version": 1,
  "self_identity": "github.com/acme/widget",
  "allowed_workspaces": [
    { "id": "github.com/acme/other", "reason": "edição direta do agente", "granted_by": "agente", "granted_at": "2026-10-30T02:00:00Z" }
  ]
}
JSON
OUTE2_DOCTOR="$(run_doctor "$RE")"
if ! printf '%s' "$OUTE2_DOCTOR" | grep -q "CONTENÇÃO: allowlist-changed"; then
  bad "doctor não mostrou a edição direta como allowlist-changed. Saída: $(printf '%s' "$OUTE2_DOCTOR" | grep CONTENÇÃO || echo '(nenhuma)')"
else
  ok "edição direta aparece no doctor (allowlist-changed)"
fi

echo "[E3] cenário do revisor — commit + push mostra a mudança no pre-push sem bloquear"
git -C "$RE" add -A >/dev/null
git -C "$RE" commit -q -m "chore: edição direta do cadastro (agente)"
NEWSHA_E="$(git -C "$RE" rev-parse HEAD)"
feedE3="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$NEWSHA_E" "$OLDSHA_E")"
outE3="$(push_out "$RE" "$feedE3")"; rcE3=$?
if [ "$rcE3" -ne 0 ]; then
  bad "pre-push bloqueou o push da edição direta (rc=$rcE3) — deveria só avisar. Saída: $outE3"
elif ! printf '%s' "$outE3" | grep -q "allowlist-changed"; then
  bad "pre-push não mostrou a edição direta commitada. Saída: $outE3"
else
  ok "pre-push mostrou a mudança sem bloquear o push"
fi

echo "[E4] cenário do revisor — a mesma mudança aparece via 'native containment --range ... --format markdown' (como prepare-pr/ship invocam)"
outE4="$(FORGE_ROOT="$RE" bash "$RE/.forge/scripts/liaison-ops.sh" native containment --range "${OLDSHA_E}..${NEWSHA_E}" --format markdown 2>&1)"
if ! printf '%s' "$outE4" | grep -q "allowlist-changed"; then
  bad "'native containment --format markdown' não mostrou a mudança no intervalo do push. Saída: $outE4"
else
  ok "'native containment --format markdown' mostra a mudança (seção 'Mudanças de contenção' do PR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════
# Grupo F — gate de texto: prepare-pr.md/ship.md invocam o detector; ship.md/yolo-gate.md/
# autonomy-yolo.md exigem merge humano com mudança de contenção
# ═══════════════════════════════════════════════════════════════════════════════════════════
check_invokes_detector() { # check_invokes_detector <file>
  grep -q "native containment" "$1"
}
check_human_merge_rule() { # check_human_merge_rule <file>
  grep -qi "mudança de contenção" "$1" && grep -qi "humano" "$1"
}

echo "[F1] prepare-pr.md (template) invoca o detector"
check_invokes_detector "$WS/template/.forge/commands/harness/prepare-pr.md" \
  && ok "template/.../prepare-pr.md invoca 'native containment'" \
  || bad "template/.../prepare-pr.md não invoca 'native containment'"

echo "[F2] prepare-pr.md (plugin) invoca o detector"
check_invokes_detector "$WS/plugin/forge/commands/prepare-pr.md" \
  && ok "plugin/.../prepare-pr.md invoca 'native containment'" \
  || bad "plugin/.../prepare-pr.md não invoca 'native containment'"

echo "[F3] ship.md (template) invoca o detector e exige merge humano com mudança de contenção"
if check_invokes_detector "$WS/template/.forge/commands/git/ship.md" && check_human_merge_rule "$WS/template/.forge/commands/git/ship.md"; then
  ok "template/.../ship.md invoca o detector e exige merge humano"
else
  bad "template/.../ship.md não invoca o detector e/ou não exige merge humano com mudança de contenção"
fi

echo "[F4] ship.md (plugin) idem"
if check_invokes_detector "$WS/plugin/forge/commands/ship.md" && check_human_merge_rule "$WS/plugin/forge/commands/ship.md"; then
  ok "plugin/.../ship.md invoca o detector e exige merge humano"
else
  bad "plugin/.../ship.md não invoca o detector e/ou não exige merge humano com mudança de contenção"
fi

echo "[F5] yolo-gate.md exige decisão block com o motivo 'mudança de contenção exige humano'"
if grep -qi "mudança de contenção" "$WS/template/.forge/agents/review/yolo-gate.md" \
  && grep -q "block" "$WS/template/.forge/agents/review/yolo-gate.md" \
  && grep -q "mudança de contenção exige humano" "$WS/template/.forge/agents/review/yolo-gate.md"; then
  ok "yolo-gate.md traz a decisão block com o motivo exato"
else
  bad "yolo-gate.md não traz a decisão block com o motivo 'mudança de contenção exige humano'"
fi

echo "[F6] autonomy-yolo.md lista 'merge com mudança de contenção' entre as paradas humanas obrigatórias"
if grep -qi "merge com mudança de contenção" "$WS/template/.forge/rules/conventions/autonomy-yolo.md"; then
  ok "autonomy-yolo.md lista o hard-stop"
else
  bad "autonomy-yolo.md não lista 'merge com mudança de contenção' como parada humana obrigatória"
fi

echo "---"
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail de $n checagem(ns) reprovada(s)"
  exit 1
fi
echo "RESULT: $n de $n checagem(ns) ok"
