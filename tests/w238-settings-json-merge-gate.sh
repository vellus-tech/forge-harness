#!/usr/bin/env bash
# Gate W238 — sync-adapters não apaga chaves de topo autorais de .claude/settings.json a cada
# sync (#160), e o doctor para de recomendar regeneração quando o drift é só nessa chave
# (LDG-0189, mesmo PR).
#
# POR QUE ESTE GATE EXISTE. `template/.forge/scripts/lib/sync-adapters.mjs:246` (antes desta
# issue) emitia `JSON.stringify({ hooks }, null, 2)` — um objeto com UMA chave. Qualquer outra
# chave de topo que o consumidor tivesse declarado à mão (`permissions`, `env`,
# `includeCoAuthoredBy`, ou qualquer chave de terceiro) desaparecia no `sync` seguinte, com rc 0 e
# sem aviso. Medido num clone do vellus-enterprise-ai-platform, reproduzindo a issue: antes
# `["hooks","permissions","env","includeCoAuthoredBy"]`, depois `["hooks"]`. `doctor.sh:157`
# agravava o dano (LDG-0189), porque recomendava rodar `sync-adapters.sh` sem ressalva mesmo
# quando o drift detectado era só numa dessas chaves — a "correção" recomendada era a própria
# causa da perda.
#
# ACHADO DE CORREÇÃO (revisão adversarial da 1ª iteração, HIGH): a 1ª versão deste gate media o
# doctor só com fixtures SEM hook de terceiro. `_settings_hooks_is_derived` comparava
# `current.hooks` (a árvore INTEIRA, que desde a #160 também carrega hooks de terceiro
# preservados) contra `preToolUseWiring(root)` (só o que o gerador deriva) — a igualdade nunca
# batia byte a byte na presença de UM hook de terceiro, exatamente o caso dos dois consumidores
# reais medidos no plano (vellus e axis-fare-validator). [6]/[6b] agora partem de uma fixture COM
# hook de terceiro (a mesma forma do vellus real), e a comparação em `doctor.sh` passou a projetar
# de `current.hooks` só as entradas cujo comando é do gerador antes de comparar.
#
#   [1] positivo — fixture no formato real do vellus (permissions/env/hooks/includeCoAuthoredBy,
#       com hook de terceiro `prevent-secrets-leak.sh` ao lado do derivado
#       `enforce-worktree-location.sh`; valores de `env` trocados por marcador sintético, protocolo
#       item 3 — nenhum valor de `env` de consumidor real entra como literal): depois de assentada
#       (dois syncs, como o consumidor real já teria passado), um TERCEIRO sync não muda nenhuma
#       das quatro chaves de topo nem `permissions`, e `hooks` bate com `preToolUseWiring(root)`.
#   [2] positivo — fixture do axis-fare-validator, cópia LITERAL do arquivo real (não precisa de
#       sanitização: não declara `env`/`permissions`, nenhum caminho absoluto de máquina, host,
#       e-mail ou token): os três wrappers `dispatch-file-hook.sh` e os dois ganchos autorais
#       (`enforce-docs-on-publish.sh`, `guard-machinery-drift.sh`) sobrevivem como OBJETOS
#       idênticos (deep-equal, não só contagem de ocorrências — achado de correção LOW), e nenhuma
#       entrada derivada duplica `enforce-worktree-location.sh`.
#   [3] positivo — idempotência: um segundo `sync` nas duas fixtures não muda nenhum byte.
#   [4] positivo — `.claude/settings.json` com JSON sintaticamente inválido: os bytes anteriores
#       viram backup byte-idêntico em `<git-dir>/forge-backups/`, um WARN nomeia o caminho, rc 0, e
#       o arquivo é regenerado do zero (mesma política da #120/DA-09).
#   [5] positivo — o mesmo cenário numa worktree LIGADA: o backup cai no git-dir DA WORKTREE
#       (`.git/worktrees/<nome>/forge-backups/`), nunca no `.git` do checkout principal.
#   [6] positivo — doctor.sh (LDG-0189), fixture COM hook de terceiro: drift só numa chave autoral
#       (`permissions` editado à mão) não soma ao contador que aciona `MISSING_DIAG`/recomendação;
#       imprime linha informativa nomeando que o sync preserva a chave.
#   [6b] contrafactual, decisão registrada (achado de correção MEDIUM da #125, revisão adversarial
#        2ª iteração): no MODO SEMEADOR (sem hooks.manifest do consumidor), corromper só o MATCHER
#        de um gancho já fiado deixa de ser detectado como drift — a mesma auto-referência que já
#        mascarava corrupção de COMANDO desde antes desta correção (`preToolUseWiring(root)` lê a
#        fiação atual para decidir "o que já está armado" e, desde a #125, também para preservar o
#        matcher que o consumidor já tinha — ver `findWiredForms`); a projeção do doctor e a
#        derivação fresca leem o MESMO `.claude/settings.json` corrompido e concordam sobre o valor
#        corrompido. Isto é "desarme consciente": o doctor deixa de flagar drift de matcher/comando
#        num gancho semeado, e [6e] abaixo prova que o ponto cego é só do modo semeador — com
#        hooks.manifest do consumidor presente, a mesma corrupção continua sendo pega.
#   [6e] positivo — o mesmo cenário de [6b], mas com hooks.manifest do CONSUMIDOR presente e
#        resolvido: o matcher usado pela derivação fresca vem do MANIFESTO (fonte independente do
#        settings.json sendo comparado), então corromper o matcher em settings.json ainda diverge
#        da derivação e o doctor continua recomendando `sync-adapters.sh`.
#   [6c] positivo — versão mista doctor×lib (achado de correção MEDIUM + LOW, revisão adversarial):
#        uma `sync-adapters.mjs` anterior à #130 (sem `isMainModule`/`preToolUseWiring`/
#        `mergeSettingsJson`), preservada por exceção de machinery enquanto o overlay já entrega o
#        `doctor.sh` novo, NÃO é importada por `_settings_hooks_is_derived` — a leitura de
#        diagnóstico não reconcilia o consumidor como efeito colateral, `permissions` continua
#        intacto depois de rodar o doctor — e, como a fixture tem `permissions` fora de `hooks` e
#        a lib não tem a fusão da #160 (`mergeSettingsJson`), o doctor troca a recomendação normal
#        por um AVISO nomeando a #160 e o risco de apagar chaves autorais, em vez de mandar "rode
#        sync-adapters.sh" sem ressalva (achado LOW: a âncora de #130 não bastava para confirmar a
#        fusão da #160).
#   [6d] positivo — achado de correção MEDIUM (revisão adversarial): o [6c] usa a lib de 16c437d,
#        que já falha na PRIMEIRA cláusula de `_settings_hooks_is_derived` (nem tem
#        `isMainModule`/`preToolUseWiring`) — a cláusula `mergeSettingsJson` nunca é alcançada, e
#        uma mutação que a remove passa despercebida. [6d] usa a lib de f24b029 (TEM
#        `isMainModule`/`preToolUseWiring`, da #130, mas NÃO tem `mergeSettingsJson`, da #160): as
#        duas primeiras cláusulas já são satisfeitas, então só a cláusula de `mergeSettingsJson`
#        impede `_settings_hooks_is_derived` de importar a lib e suprimir o aviso. Com a lib de
#        f24b029 e `permissions` editado à mão, o doctor tem de avisar "anterior à #160"/"apagaria"
#        (nunca "nenhuma ação necessária").
#   [7] PBT — `template/.forge/scripts/lib/pbt.mjs` (`makeRandom`, semente fixa), 60 casos: para
#       `settings.json` gerados (subconjuntos aleatórios de chaves de topo autorais, hooks de
#       terceiros e hooks do harness de uma configuração de flags ANTERIOR, em ordem aleatória),
#       depois do `sync` as chaves autorais e os hooks de terceiros sobrevivem inalterados, e o
#       conjunto de comandos do harness no resultado é EXATAMENTE o que `preToolUseWiring(root)`
#       derivaria para os flags ATUAIS.
#   [8] mutação — reverter para `emit({ hooks })` (o defeito original) faz [1] falhar nomeando
#       `permissions`. Controle/recontrole por `cmp -s`.
#   [9] mutação — trocar a posse por igualdade de comando pela simples MENÇÃO a `.forge/hooks/`
#       (a alternativa descartada na seção do plano) faz [2] falhar nomeando `dispatch-file-hook`
#       — os wrappers de terceiro também citam `.forge/hooks/`, então essa posse mais larga os
#       apagaria. Controle/recontrole por `cmp -s`.
#   [10] mutação — remover a chamada de backup do JSON ilegível faz [4] falhar (o arquivo
#        ilegível seria sobrescrito sem nenhum rastro). Controle/recontrole por `cmp -s`. O mesmo
#        caminho de código cobre as três formas de [11], então esta mutação também as alcançaria.
#   [11] positivo — achado de correção MEDIUM (formas de ilegibilidade além de JSON sintaticamente
#        inválido): (a) bytes que não são UTF-8 válido, mesmo formando um JSON sintaticamente
#        aceitável depois de decodificados com substituição — backup byte-idêntico + WARN, nunca
#        regenerado com o caractere de substituição U+FFFD; (b) JSON válido cujo nível de topo é um
#        array — backup + WARN, nunca descartado em silêncio; (c) a chave `hooks`, quando presente,
#        sendo um array em vez de objeto — backup + WARN, nunca substituída em silêncio pela
#        fiação derivada.
#
# Fixtures: nenhum segredo literal (LDG-0175/w213 e a auto-varredura do w139 [15], que reprova o
# repositório inteiro por qualquer achado) — todo valor de exemplo (env, permissions) é
# sintético e sem forma de segredo real. Toda mutação muta uma CÓPIA da lib dentro de um diretório
# temporário, nunca o arquivo rastreado em `template/.forge/`, e é restaurada e reconferida por
# `cmp -s` antes de seguir.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_REL=".forge/scripts/lib/sync-adapters.mjs"
DOCTOR_REL=".forge/scripts/doctor.sh"
TMPROOT="${TMPDIR:-/tmp}"
overall_rc=0
CLEANUP_DIRS=()
trap 'rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true' EXIT
track() { CLEANUP_DIRS+=("$1"); }

# nova_fixture <dir> — instala o template e resolve os placeholders mínimos, como w216.
nova_fixture() {
  local dir="$1"
  cp -R "$WS/template/.forge" "$dir/.forge"
  perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture do w238/g' \
    "$dir/.forge/FORGE.md" "$dir/.forge/constitution.md" "$dir/.forge/context.md"
}

json_keys() { node -e "console.log(JSON.stringify(Object.keys(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))).sort()))" "$1"; }
json_get() { node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))[process.argv[2]] ?? null))" "$1" "$2"; }
wiring_of() { # wiring_of <lib> <root>
  DOCTOR_SETTINGS_LIB="$1" DOCTOR_SETTINGS_ROOT="$2" node --input-type=module -e '
    import { pathToFileURL } from "node:url";
    const { DOCTOR_SETTINGS_LIB: lib, DOCTOR_SETTINGS_ROOT: root } = process.env;
    const m = await import(pathToFileURL(lib).href);
    console.log(JSON.stringify(m.preToolUseWiring(root)));
  '
}
# owned_projection_of <settings.json> — a mesma projeção que doctor.sh usa para comparar contra
# preToolUseWiring(root): de cada grupo de `hooks`, mantém só os hooks cujo comando é um dos três
# que o gerador deriva. Usada por [1] porque a fixture, a partir desta correção, TEM um hook de
# terceiro ao lado do owned — comparar `hooks` inteiro contra `preToolUseWiring(root)` reproduziria
# o próprio bug HIGH que este PR fecha em doctor.sh.
owned_projection_of() {
  node -e '
    const fs = require("fs");
    // issue #125: o universo de PreToolUse deixou de ser fixo — inclui os quatro ganchos do
    // template, nas duas formas de comando possíveis (direta e via lib/argv-bridge.sh). As formas
    // COM ASPAS em $CLAUDE_PROJECT_DIR (achado de correção MEDIUM, iteração 3 do modo correção) e
    // as formas *Legacy* sem aspas convivem no universo owned — mesma migração sem duplicar de
    // hookCommandDirect/hookCommandDirectLegacy na lib.
    const HOOK_FILES = ["enforce-worktree-location.sh", "prevent-secrets-leak.sh", "check-language-policy.sh", "validate-naming-conventions.sh"];
    const OWNED = new Set([
      "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/session/on-session-start.sh",
      "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/session/on-session-end.sh",
      "$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-start.sh",
      "$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-end.sh",
      ...HOOK_FILES.map((h) => `"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/${h}`),
      ...HOOK_FILES.map((h) => `$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/${h}`),
      ...HOOK_FILES.map((h) => `"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/lib/argv-bridge.sh "$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/${h}`),
      ...HOOK_FILES.map((h) => `$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/lib/argv-bridge.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/${h}`),
    ]);
    const settings = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const hooksObj = (settings.hooks && typeof settings.hooks === "object" && !Array.isArray(settings.hooks)) ? settings.hooks : {};
    const out = {};
    for (const cat of Object.keys(hooksObj)) {
      const groups = Array.isArray(hooksObj[cat]) ? hooksObj[cat] : [];
      const kept = [];
      for (const g of groups) {
        if (!g || !Array.isArray(g.hooks)) continue;
        const keptHooks = g.hooks.filter((h) => h && OWNED.has(h.command));
        if (keptHooks.length) kept.push(keptHooks.length === g.hooks.length ? g : { ...g, hooks: keptHooks });
      }
      if (kept.length) out[cat] = kept;
    }
    console.log(JSON.stringify(out));
  ' "$1"
}

# ── forma real do vellus-enterprise-ai-platform, com env trocado por marcador (protocolo item 3):
# `permissions`/`includeCoAuthoredBy` e o hook de terceiro são cópia literal do consumidor real —
# nenhum contém caminho absoluto de máquina, host, e-mail ou token, só padrões `Bash(cmd:*)`
# genéricos e um nome de script.
VELLUS_PERMISSIONS_JSON='{"allow":["Bash(git:*)","Bash(gh:*)","Bash(rg:*)","Bash(jq:*)","Bash(yq:*)","Bash(python:*)","Bash(python3:*)","Bash(pip:*)","Bash(uv:*)","Bash(pytest:*)","Bash(docker:*)","Bash(docker-compose:*)","Bash(kubectl:*)","Bash(kustomize:*)","Bash(helm:*)","Bash(helmfile:*)","Bash(terraform:*)","Bash(tflint:*)","Bash(gcloud:*)","Bash(op:*)","Bash(curl:*)","Bash(dig:*)","Bash(nslookup:*)","Bash(make:*)","Bash(npm:*)","Bash(npx:*)","Bash(pnpm:*)","Bash(playwright:*)","Read(*)","Edit(*)","Write(*)"],"deny":["Bash(rm -rf:*)","Bash(*--force*)","Bash(kubectl delete ns:*)","Bash(terraform destroy:*)","Bash(gcloud * delete:*)","Write(**/.env)","Write(**/.env.*)","Write(**/secrets/**)","Write(**/*.pem)","Write(**/*.key)"]}'
VELLUS_ENV_JSON='{"PROJECT_NAME":"marcador-1","PROJECT_DISPLAY":"marcador-2","PROJECT_LANGUAGE_POLICY":"marcador-3","PROJECT_DOMAIN":"marcador-4"}'
VELLUS_THIRD_PARTY_HOOK_CMD='.claude/hooks/pre-tool-use/prevent-secrets-leak.sh "$CLAUDE_FILE_PATHS"'

# fixture_vellus_settled <dir> — cria .claude/settings.json na FORMA assentada do vellus real: um
# sync inicial (só o hook derivado), depois as chaves autorais + o hook de terceiro mesclados à
# mão (como um consumidor que editou o arquivo depois de instalar o harness), e um segundo sync
# que assenta o arquivo — o mesmo estado em que o consumidor real já vive há vários syncs.
fixture_vellus_settled() {
  local dir="$1"
  bash "$dir/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const cur = JSON.parse(fs.readFileSync(p, "utf8"));
    cur.permissions = JSON.parse(process.argv[2]);
    cur.env = JSON.parse(process.argv[3]);
    cur.includeCoAuthoredBy = false;
    cur.hooks.PreToolUse = [
      { matcher: "Edit|Write|MultiEdit", hooks: [ { type: "command", command: process.argv[4] } ] },
      ...cur.hooks.PreToolUse,
    ];
    fs.writeFileSync(p, JSON.stringify(cur, null, 2) + "\n");
  ' "$dir/.claude/settings.json" "$VELLUS_PERMISSIONS_JSON" "$VELLUS_ENV_JSON" "$VELLUS_THIRD_PARTY_HOOK_CMD"
  bash "$dir/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
}

# ── [1] fixture no formato real do vellus (assentada): um sync a mais não apaga nada ────────────
echo "[1] chaves de topo autorais (permissions/env/includeCoAuthoredBy) sobrevivem ao sync, hook de terceiro presente, hooks == preToolUseWiring"
T1="$(mktemp -d "$TMPROOT/forge-w238-1.XXXXXX")"; track "$T1"
nova_fixture "$T1"
fixture_vellus_settled "$T1"
BEFORE1="$(cat "$T1/.claude/settings.json")"
BEFORE_KEYS1="$(json_keys "$T1/.claude/settings.json")"
PERM_BEFORE1="$(json_get "$T1/.claude/settings.json" permissions)"
bash "$T1/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
AFTER_KEYS1="$(json_keys "$T1/.claude/settings.json")"
PERM_AFTER1="$(json_get "$T1/.claude/settings.json" permissions)"
WIRING1="$(wiring_of "$T1/$LIB_REL" "$T1")"
OWNED_AFTER1="$(owned_projection_of "$T1/.claude/settings.json")"

if [ "$BEFORE_KEYS1" != "$AFTER_KEYS1" ]; then
  echo "FAIL [1]: as chaves de topo mudaram — antes $BEFORE_KEYS1, depois $AFTER_KEYS1"
  overall_rc=1
elif ! echo "$AFTER_KEYS1" | grep -q '"permissions"'; then
  echo "FAIL [1]: 'permissions' desapareceu de .claude/settings.json — o defeito original da #160"
  overall_rc=1
elif [ "$PERM_AFTER1" != "$PERM_BEFORE1" ]; then
  echo "FAIL [1]: 'permissions' não ficou byte-idêntico — antes $PERM_BEFORE1, depois $PERM_AFTER1"
  overall_rc=1
elif [ "$OWNED_AFTER1" != "$WIRING1" ]; then
  echo "FAIL [1]: a projeção owned de hooks diverge de preToolUseWiring(root) — owned=$OWNED_AFTER1 wiring=$WIRING1"
  overall_rc=1
elif ! grep -q 'prevent-secrets-leak.sh' "$T1/.claude/settings.json"; then
  echo "FAIL [1]: o hook de terceiro (prevent-secrets-leak.sh) não sobreviveu ao sync"
  overall_rc=1
else
  echo "OK [1] — chaves de topo ($AFTER_KEYS1) sobrevivem, permissions byte-idêntico, hook de terceiro presente, projeção owned de hooks == wiring"
fi

# ── [1b] achado de correção LOW (lacuna de cobertura): [1] media entre o 2º e o 3º sync, com a
#     fixture montada a partir da SAÍDA do gerador (ordem de chaves hooks,permissions,...) — nunca
#     o PRIMEIRO sync sobre a ORDEM real de chaves do consumidor (permissions,env,hooks,
#     includeCoAuthoredBy). Monta o arquivo diretamente nessa ordem, sem sync preparatório, e
#     confere que o PRIMEIRO sync já é byte-idêntico (medido à parte contra o vellus real).
echo "[1b] primeiro sync sobre a ORDEM real de chaves do vellus (permissions,env,hooks,includeCoAuthoredBy), sem sync preparatório, é byte-idêntico"
T1B="$(mktemp -d "$TMPROOT/forge-w238-1b.XXXXXX")"; track "$T1B"
nova_fixture "$T1B"
mkdir -p "$T1B/.claude"
# issue #125: a forma pós-fix de uma instalação nova tem DOIS grupos em PreToolUse (matcher
# âncorado "^Bash$" para o worktree-guard, e o novo prevent-secrets-leak.sh, armado por padrão)
# em vez do único gancho literal de antes.
node -e '
  const fs = require("fs");
  const settings = {
    permissions: JSON.parse(process.argv[2]),
    env: JSON.parse(process.argv[3]),
    hooks: { PreToolUse: [
      { matcher: "^Bash$", hooks: [ { type: "command", command: "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] },
      { matcher: "^(Write|Edit|MultiEdit|NotebookEdit)$", hooks: [ { type: "command", command: "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] },
    ] },
    includeCoAuthoredBy: false,
  };
  fs.writeFileSync(process.argv[1], JSON.stringify(settings, null, 2) + "\n");
' "$T1B/.claude/settings.json" "$VELLUS_PERMISSIONS_JSON" "$VELLUS_ENV_JSON"
cp "$T1B/.claude/settings.json" "$T1B/before.json"
bash "$T1B/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
if ! cmp -s "$T1B/before.json" "$T1B/.claude/settings.json"; then
  echo "FAIL [1b]: o PRIMEIRO sync sobre a ordem real do vellus (permissions,env,hooks,includeCoAuthoredBy) mudou bytes — esperado no-op"
  overall_rc=1
else
  echo "OK [1b] — primeiro sync sobre a ordem real do vellus é byte-idêntico, sem sync preparatório"
fi

# ── [2] fixture "axis-fare-validator": hooks de terceiro preservados como objetos idênticos ─────
echo "[2] hooks de terceiro (wrappers dispatch-file-hook.sh + ganchos autorais) sobrevivem como objetos idênticos, sem entrada derivada duplicada"
T2="$(mktemp -d "$TMPROOT/forge-w238-2.XXXXXX")"; track "$T2"
nova_fixture "$T2"
bash "$T2/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
# liga handoff.auto para que SessionStart (on-session-start.sh, owned) também precise sobreviver —
# reproduz o consumidor real, que já tinha esse hook fiado antes desta issue.
perl -0777 -pi -e 's/(handoff:\n(?:.*\n){2}  auto: )false/${1}true/' "$T2/.forge/forge.yaml"
# Cópia LITERAL do .claude/settings.json real do axis-fare-validator (medido em 2026-09-26): só
# declara `hooks`, nenhum caminho absoluto de máquina, host, e-mail ou token — nada a sanitizar.
cat > "$T2/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)$",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/check-language-policy.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/validate-naming-conventions.sh" }
        ]
      },
      {
        "matcher": "^Bash$",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-docs-on-publish.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/guard-machinery-drift.sh" }
        ]
      }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-start.sh" } ] }
    ]
  }
}
JSON
cp "$T2/.claude/settings.json" "$T2/.claude/settings.json.before"
bash "$T2/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
DISPATCH_COUNT2="$(grep -c 'dispatch-file-hook.sh' "$T2/.claude/settings.json")"
ENFORCE_COUNT2="$(grep -c 'enforce-worktree-location.sh' "$T2/.claude/settings.json")"
SESSION_COUNT2="$(grep -c 'on-session-start.sh' "$T2/.claude/settings.json")"
# deep-equal (achado de correção LOW): as entradas de terceiro/autorais sobrevivem como OBJETOS
# idênticos (grupo inteiro, matcher + hooks), não só por contagem de ocorrências de substring.
FOREIGN_DIFF2="$(node -e '
  const fs = require("fs");
  // issue #125: o universo de PreToolUse deixou de ser fixo — inclui os quatro ganchos do
  // template, nas duas formas de comando possíveis (direta e via lib/argv-bridge.sh); as formas
  // COM ASPAS e as formas *Legacy* sem aspas (achado MEDIUM, iteração 3) convivem aqui também.
  const HOOK_FILES = ["enforce-worktree-location.sh", "prevent-secrets-leak.sh", "check-language-policy.sh", "validate-naming-conventions.sh"];
  const OWNED = new Set([
    "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/session/on-session-start.sh",
    "\"$CLAUDE_PROJECT_DIR\"/.forge/hooks/session/on-session-end.sh",
    "$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-start.sh",
    "$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-end.sh",
    ...HOOK_FILES.map((h) => `"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/${h}`),
    ...HOOK_FILES.map((h) => `$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/${h}`),
    ...HOOK_FILES.map((h) => `"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/lib/argv-bridge.sh "$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/${h}`),
    ...HOOK_FILES.map((h) => `$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/lib/argv-bridge.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/${h}`),
  ]);
  function foreignGroups(hooksObj, cat) {
    const groups = (hooksObj && hooksObj[cat]) || [];
    return groups
      .map((g) => ({ ...g, hooks: (g.hooks || []).filter((h) => !OWNED.has(h.command)) }))
      .filter((g) => g.hooks.length);
  }
  const before = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const after = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  for (const cat of ["PreToolUse", "SessionStart"]) {
    const b = JSON.stringify(foreignGroups(before.hooks, cat));
    const a = JSON.stringify(foreignGroups(after.hooks, cat));
    if (b !== a) { console.log(`${cat}: antes=${b} depois=${a}`); process.exit(0); }
  }
  console.log("");
' "$T2/.claude/settings.json.before" "$T2/.claude/settings.json")"

if [ "$DISPATCH_COUNT2" -ne 3 ]; then
  echo "FAIL [2]: os três wrappers dispatch-file-hook.sh não sobreviveram (achei $DISPATCH_COUNT2)"
  overall_rc=1
elif [ -n "$FOREIGN_DIFF2" ]; then
  echo "FAIL [2]: grupo(s) de hook de terceiro/autoral não ficaram idênticos ao original — $FOREIGN_DIFF2"
  overall_rc=1
elif [ "$ENFORCE_COUNT2" -ne 1 ]; then
  echo "FAIL [2]: enforce-worktree-location.sh aparece $ENFORCE_COUNT2 vez(es) — esperado exatamente 1 (nenhuma duplicata derivada)"
  overall_rc=1
elif [ "$SESSION_COUNT2" -ne 1 ]; then
  echo "FAIL [2]: on-session-start.sh aparece $SESSION_COUNT2 vez(es) — esperado exatamente 1"
  overall_rc=1
else
  echo "OK [2] — 3 wrappers + 2 ganchos autorais preservados como objetos idênticos, enforce-worktree-location.sh e on-session-start.sh sem duplicata"
fi

# ── [3] idempotência: segundo sync não muda nada nas duas fixtures ──────────────────────────────
echo "[3] segundo sync é byte-idêntico ao primeiro, nas duas fixtures"
cp "$T1/.claude/settings.json" "$T1/.claude/settings.json.after1"
bash "$T1/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
cp "$T2/.claude/settings.json" "$T2/.claude/settings.json.after1"
bash "$T2/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
if ! cmp -s "$T1/.claude/settings.json.after1" "$T1/.claude/settings.json"; then
  echo "FAIL [3]: fixture 'vellus' não é idempotente — segundo sync mudou bytes"
  overall_rc=1
elif ! cmp -s "$T2/.claude/settings.json.after1" "$T2/.claude/settings.json"; then
  echo "FAIL [3]: fixture 'axis-fare-validator' não é idempotente — segundo sync mudou bytes"
  overall_rc=1
else
  echo "OK [3] — dois syncs seguidos produzem bytes idênticos nas duas fixtures"
fi

# ── [4] JSON sintaticamente inválido vira backup byte-idêntico + WARN, num repositório normal ───
echo "[4] settings.json com JSON inválido: backup byte-idêntico em <git-dir>/forge-backups/ + WARN com o caminho"
T4BASE="$(mktemp -d "$TMPROOT/forge-w238-4.XXXXXX")"; track "$T4BASE"
git init -q "$T4BASE/repo" -b main
(
  cd "$T4BASE/repo"
  git config user.email t@test; git config user.name t; git config commit.gpgsign false
  nova_fixture "."
  bash .forge/scripts/sync-adapters.sh --set claude >/dev/null 2>&1
  git add -A >/dev/null && git commit -qm init >/dev/null
)
printf '{ isto não é json válido' > "$T4BASE/repo/.claude/settings.json"
cp "$T4BASE/repo/.claude/settings.json" "$T4BASE/before.json"
OUT4="$(cd "$T4BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
RC4=$?
BAK4="$(cd "$T4BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"

if [ "$RC4" -ne 0 ]; then
  echo "FAIL [4]: sync saiu rc=$RC4 com JSON ilegível — deveria seguir com backup + WARN, rc 0: $OUT4"
  overall_rc=1
elif ! grep -q 'WARN.*settings.json.*forge-backups/settings-1.json' <<<"$OUT4"; then
  echo "FAIL [4]: nenhum WARN nomeando o backup: $OUT4"
  overall_rc=1
elif [ ! -f "$BAK4" ]; then
  echo "FAIL [4]: backup esperado ausente em $BAK4"
  overall_rc=1
elif ! cmp -s "$T4BASE/before.json" "$BAK4"; then
  echo "FAIL [4]: backup não é byte-idêntico ao conteúdo ilegível anterior"
  overall_rc=1
elif ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$T4BASE/repo/.claude/settings.json" 2>/dev/null; then
  echo "FAIL [4]: settings.json não foi regenerado como JSON válido depois do backup"
  overall_rc=1
else
  echo "OK [4] — backup byte-idêntico em $BAK4, WARN presente, rc 0, arquivo regenerado"
fi

# ── [5] mesmo cenário numa worktree LIGADA: backup cai no git-dir DA WORKTREE ────────────────────
echo "[5] JSON ilegível numa worktree ligada: backup cai no git-dir da worktree, nunca no do tronco"
T5BASE="$(mktemp -d "$TMPROOT/forge-w238-5.XXXXXX")"; track "$T5BASE"
git init -q "$T5BASE/main" -b main
(
  cd "$T5BASE/main"
  git config user.email t@test; git config user.name t; git config commit.gpgsign false
  nova_fixture "."
  git add -A >/dev/null && git commit -qm init >/dev/null
  git branch feature >/dev/null
  git worktree add -q "$T5BASE/wt" feature
)
(
  cd "$T5BASE/wt"
  bash .forge/scripts/sync-adapters.sh --set claude >/dev/null 2>&1
)
printf '{ também inválido' > "$T5BASE/wt/.claude/settings.json"
cp "$T5BASE/wt/.claude/settings.json" "$T5BASE/before5.json"
OUT5="$(cd "$T5BASE/wt" && bash .forge/scripts/sync-adapters.sh 2>&1)"
WT_GITDIR="$(cd "$T5BASE/wt" && git rev-parse --git-dir)"
BAK5="$WT_GITDIR/forge-backups/settings-1.json"
MAIN_BAK5="$T5BASE/main/.git/forge-backups"

if [ ! -f "$BAK5" ]; then
  echo "FAIL [5]: backup esperado ausente em $BAK5 (git-dir da worktree): $OUT5"
  overall_rc=1
elif ! cmp -s "$T5BASE/before5.json" "$BAK5"; then
  echo "FAIL [5]: backup na worktree não é byte-idêntico ao conteúdo ilegível anterior"
  overall_rc=1
elif [ -d "$MAIN_BAK5" ]; then
  echo "FAIL [5]: o tronco ganhou forge-backups/ ($MAIN_BAK5) — o backup deveria ficar só no git-dir da worktree"
  overall_rc=1
else
  echo "OK [5] — backup no git-dir da worktree ($WT_GITDIR/forge-backups/), tronco intocado"
fi

# ── [6] doctor (LDG-0189), fixture COM hook de terceiro: drift só em chave autoral não recomenda
#     regenerar ────────────────────────────────────────────────────────────────────────────────
echo "[6] doctor (fixture com hook de terceiro): drift só em 'permissions' não soma a MISSING_DIAG, imprime linha informativa"
T6="$(mktemp -d "$TMPROOT/forge-w238-6.XXXXXX")"; track "$T6"
nova_fixture "$T6"
fixture_vellus_settled "$T6"
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.permissions.allow.push("Bash(echo teste)");fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6/.claude/settings.json"
DOCTOR_OUT6="$(FORGE_ROOT="$T6" bash "$T6/$DOCTOR_REL" 2>&1)"
LINE6="$(grep -i 'adapter claude' <<<"$DOCTOR_OUT6")"

if grep -qi 'com drift (rode' <<<"$LINE6"; then
  echo "FAIL [6]: doctor ainda recomenda 'rode sync-adapters.sh' para drift só em chave autoral, mesmo com hook de terceiro presente: $LINE6"
  overall_rc=1
elif ! grep -qi 'fora da fiação do gerador' <<<"$LINE6"; then
  echo "FAIL [6]: doctor não imprimiu a linha informativa esperada (achado de correção LOW: sem afirmar contagem de chaves que não faz): $LINE6"
  overall_rc=1
elif ! grep -q 'prevent-secrets-leak.sh' "$T6/.claude/settings.json"; then
  echo "FAIL [6]: a fixture perdeu o hook de terceiro antes mesmo do doctor rodar — cenário não é o medido"
  overall_rc=1
else
  echo "OK [6] — $LINE6 (hook de terceiro presente durante a checagem)"
fi

# ── [6b] contrafactual, decisão registrada — modo SEMEADOR mascara corrupção de matcher ──────────
echo "[6b] decisão registrada: no modo semeador (sem hooks.manifest do consumidor), corromper o MATCHER de um gancho já fiado não é mais detectado como drift (auto-referência de findWiredForms — achado de correção MEDIUM da #125, 2ª iteração)"
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.hooks.PreToolUse.find((g)=>g.matcher==="^Bash$").matcher="^Bash$$";fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6/.claude/settings.json"
DOCTOR_OUT6B="$(FORGE_ROOT="$T6" bash "$T6/$DOCTOR_REL" 2>&1)"
LINE6B="$(grep -i 'adapter claude' <<<"$DOCTOR_OUT6B")"
if grep -qi 'com drift (rode' <<<"$LINE6B"; then
  echo "FAIL [6b]: o modo semeador voltou a detectar corrupção de matcher como drift — se este comportamento mudou de propósito, atualize este teste e o comentário da decisão registrada: $LINE6B"
  overall_rc=1
else
  echo "OK [6b] — matcher corrompido no modo semeador não aciona recomendação (decisão registrada): $LINE6B"
fi
# restaura o matcher antes de [6e], que parte do mesmo T6 já assentado.
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.hooks.PreToolUse.find((g)=>g.matcher==="^Bash$$").matcher="^Bash$";fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6/.claude/settings.json"

# ── [6e] positivo — com hooks.manifest do consumidor, a mesma corrupção AINDA é pega ─────────────
echo "[6e] com hooks.manifest do consumidor (matcher vem do manifesto, fonte independente de settings.json): a mesma corrupção de matcher continua sendo detectada"
printf '# forge-manifest-format: 1\n#hook\tmatcher\tcontrato\testado\nenforce-worktree-location.sh\t^Bash$\tstdin-json\tarmado\nprevent-secrets-leak.sh\t^(Write|Edit|MultiEdit|NotebookEdit)$\tstdin-json\tarmado\ncheck-language-policy.sh\t^(Write|Edit|MultiEdit)$\targv\tretido:na\nvalidate-naming-conventions.sh\t^(Write|Edit|MultiEdit)$\targv\tretido:na\n' \
  > "$T6/.forge/hooks/pre-tool-use/hooks.manifest"
bash "$T6/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.hooks.PreToolUse.find((g)=>g.matcher==="^Bash$").matcher="^Bash$$";fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6/.claude/settings.json"
DOCTOR_OUT6E="$(FORGE_ROOT="$T6" bash "$T6/$DOCTOR_REL" 2>&1)"
LINE6E="$(grep -i 'adapter claude' <<<"$DOCTOR_OUT6E")"
if ! grep -qi 'com drift (rode' <<<"$LINE6E"; then
  echo "FAIL [6e]: com hooks.manifest do consumidor presente, drift real de matcher deixou de ser detectado: $LINE6E"
  overall_rc=1
elif ! grep -qi 'o sync preserva chaves autorais e hooks de terceiro' <<<"$LINE6E"; then
  echo "FAIL [6e]: achado de correção LOW — a recomendação de drift real deveria trazer a ressalva de preservação de chaves autorais/hooks de terceiro: $LINE6E"
  overall_rc=1
else
  echo "OK [6e] — $LINE6E"
fi
rm -f "$T6/.forge/hooks/pre-tool-use/hooks.manifest"

# ── [6c] versão mista doctor×lib: lib anterior à #130 não é importada, sem reconciliar como
#     efeito colateral da leitura de diagnóstico ─────────────────────────────────────────────────
echo "[6c] versão mista: sync-adapters.mjs anterior à #130 não é importada por _settings_hooks_is_derived; permissions sobrevive, doctor ainda reporta drift"
OLD_LIB_SHA=16c437d
T6C="$(mktemp -d "$TMPROOT/forge-w238-6c.XXXXXX")"; track "$T6C"
nova_fixture "$T6C"
bash "$T6C/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.permissions={allow:["Bash(git *)"]};fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6C/.claude/settings.json"
if OLD_LIB_TEXT="$(git -C "$WS" show "$OLD_LIB_SHA:template/$LIB_REL" 2>/dev/null)" && [ -n "$OLD_LIB_TEXT" ]; then
  printf '%s' "$OLD_LIB_TEXT" > "$T6C/$LIB_REL"
  if grep -q 'function isMainModule' "$T6C/$LIB_REL" || grep -q 'export function preToolUseWiring' "$T6C/$LIB_REL"; then
    echo "FAIL [6c]: a lib de $OLD_LIB_SHA já tem isMainModule/preToolUseWiring — não é mais 'anterior à #130'; escolha outro sha de referência"
    overall_rc=1
  else
    cp "$T6C/.claude/settings.json" "$T6C/before-doctor.json"
    DOCTOR_OUT6C="$(FORGE_ROOT="$T6C" bash "$T6C/$DOCTOR_REL" 2>&1)"
    LINE6C="$(grep -i 'adapter claude' <<<"$DOCTOR_OUT6C")"
    if ! cmp -s "$T6C/before-doctor.json" "$T6C/.claude/settings.json"; then
      echo "FAIL [6c]: rodar o doctor mudou .claude/settings.json — a leitura de diagnóstico reconciliou o consumidor como efeito colateral (a classe de dano que a #130 fechou, reaberta pela lib antiga)"
      overall_rc=1
    elif ! grep -q '"permissions"' "$T6C/.claude/settings.json"; then
      echo "FAIL [6c]: 'permissions' desapareceu depois do doctor"
      overall_rc=1
    # Achado de correção LOW (âncora incompleta): a lib de $OLD_LIB_SHA não tem `mergeSettingsJson`
    # (a fusão da #160) e a fixture tem 'permissions' fora de `hooks` — o doctor não deve mais
    # recomendar "rode sync-adapters.sh" sem ressalva (a #160 provou que essa recomendação, com
    # essa lib, apagaria 'permissions'), e sim avisar do risco nomeando a #160.
    elif grep -qi 'com drift (rode' <<<"$LINE6C"; then
      echo "FAIL [6c]: com a lib antiga (sem mergeSettingsJson), o doctor ainda recomenda 'rode sync-adapters.sh' sem ressalva — essa recomendação apagaria 'permissions' com essa lib: $LINE6C"
      overall_rc=1
    elif ! grep -qi 'anterior à #160' <<<"$LINE6C" || ! grep -qi 'apagaria' <<<"$LINE6C"; then
      echo "FAIL [6c]: com a lib antiga e 'permissions' fora de hooks, o doctor deveria avisar que o sync apagaria chaves autorais em vez de recomendá-lo: $LINE6C"
      overall_rc=1
    else
      echo "OK [6c] — lib de $OLD_LIB_SHA não foi importada, .claude/ intacto, doctor avisa do risco em vez de recomendar sync: $LINE6C"
    fi
  fi
else
  echo "FAIL [6c]: não consegui ler template/$LIB_REL em $OLD_LIB_SHA deste repositório (git show falhou) — sha de referência precisa existir no histórico local"
  overall_rc=1
fi

# ── [6d] lib ENTRE a #130 e a #160 (tem isMainModule/preToolUseWiring, NÃO tem mergeSettingsJson):
#      diferente de [6c] (lib de 16c437d, que falha na 1ª cláusula do grep-chain e nunca alcança a
#      cláusula de mergeSettingsJson), esta é a única fixture que exercita de fato a âncora
#      `mergeSettingsJson` de `_settings_hooks_is_derived` — achado de correção MEDIUM (revisão
#      adversarial) ─────────────────────────────────────────────────────────────────────────────
echo "[6d] lib entre a #130 e a #160 (isMainModule/preToolUseWiring presentes, mergeSettingsJson ausente): doctor avisa 'anterior à #160', nunca 'nenhuma ação necessária'"
BETWEEN_LIB_SHA=f24b029
T6D="$(mktemp -d "$TMPROOT/forge-w238-6d.XXXXXX")"; track "$T6D"
nova_fixture "$T6D"
if BETWEEN_LIB_TEXT="$(git -C "$WS" show "$BETWEEN_LIB_SHA:template/$LIB_REL" 2>/dev/null)" && [ -n "$BETWEEN_LIB_TEXT" ]; then
  printf '%s' "$BETWEEN_LIB_TEXT" > "$T6D/$LIB_REL"
  if ! grep -q 'function isMainModule' "$T6D/$LIB_REL" || ! grep -q 'export function preToolUseWiring' "$T6D/$LIB_REL"; then
    echo "FAIL [6d]: a lib de $BETWEEN_LIB_SHA não tem isMainModule/preToolUseWiring — escolha outro sha de referência (precisa ser posterior à #130)"
    overall_rc=1
  elif grep -q 'function mergeSettingsJson' "$T6D/$LIB_REL"; then
    echo "FAIL [6d]: a lib de $BETWEEN_LIB_SHA já tem mergeSettingsJson — não é mais 'anterior à #160'; escolha outro sha de referência"
    overall_rc=1
  else
    # sync com a PRÓPRIA lib de $BETWEEN_LIB_SHA (já trocada em $T6D/$LIB_REL) — os hooks do
    # settings.json resultante vêm de preToolUseWiring(root) desta mesma lib, então a projeção que
    # _settings_hooks_is_derived compara bate byte a byte com o que ela deriva; a única coisa que
    # pode impedir a supressão do aviso é a cláusula de mergeSettingsJson.
    bash "$T6D/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
    node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.permissions={allow:["Bash(git *)"]};fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T6D/.claude/settings.json"
    cp "$T6D/.claude/settings.json" "$T6D/before-doctor.json"
    DOCTOR_OUT6D="$(FORGE_ROOT="$T6D" bash "$T6D/$DOCTOR_REL" 2>&1)"
    LINE6D="$(grep -i 'adapter claude' <<<"$DOCTOR_OUT6D")"
    if ! cmp -s "$T6D/before-doctor.json" "$T6D/.claude/settings.json"; then
      echo "FAIL [6d]: rodar o doctor mudou .claude/settings.json — a leitura de diagnóstico reconciliou o consumidor como efeito colateral"
      overall_rc=1
    elif ! grep -q '"permissions"' "$T6D/.claude/settings.json"; then
      echo "FAIL [6d]: 'permissions' desapareceu depois do doctor"
      overall_rc=1
    elif grep -qi 'nenhuma ação necessária' <<<"$LINE6D"; then
      echo "FAIL [6d]: com a lib entre a #130 e a #160 (tem isMainModule/preToolUseWiring, sem mergeSettingsJson), o doctor imprimiu 'nenhuma ação necessária' — essa lib apagaria 'permissions' num sync real: $LINE6D"
      overall_rc=1
    elif grep -qi 'com drift (rode' <<<"$LINE6D"; then
      echo "FAIL [6d]: com a lib entre a #130 e a #160, o doctor ainda recomenda 'rode sync-adapters.sh' sem ressalva — essa recomendação apagaria 'permissions' com essa lib: $LINE6D"
      overall_rc=1
    elif ! grep -qi 'anterior à #160' <<<"$LINE6D" || ! grep -qi 'apagaria' <<<"$LINE6D"; then
      echo "FAIL [6d]: o doctor deveria avisar que o sync apagaria chaves autorais em vez de qualquer outra mensagem: $LINE6D"
      overall_rc=1
    else
      echo "OK [6d] — lib de $BETWEEN_LIB_SHA (isMainModule/preToolUseWiring sem mergeSettingsJson) não suprimiu o aviso: $LINE6D"
    fi
  fi
else
  echo "FAIL [6d]: não consegui ler template/$LIB_REL em $BETWEEN_LIB_SHA deste repositório (git show falhou) — sha de referência precisa existir no histórico local"
  overall_rc=1
fi

# ── [7] PBT — 60 casos, semente fixa, via template/.forge/scripts/lib/pbt.mjs (makeRandom) ──────
echo "[7] PBT: chaves autorais e hooks de terceiro sobrevivem; hooks do harness == preToolUseWiring, para 60 casos aleatórios (seed 20386)"
T7="$(mktemp -d "$TMPROOT/forge-w238-7.XXXXXX")"; track "$T7"
nova_fixture "$T7"
bash "$T7/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1   # cria .claude/ pela 1a vez
PBT_DRIVER="$T7/pbt-driver.mjs"
cat > "$PBT_DRIVER" <<'NODE'
import { pathToFileURL } from 'node:url';
import { readFileSync, writeFileSync, existsSync, unlinkSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { execFileSync } from 'node:child_process';

const [, , FIXTURE, LIB, SEED, RUNS] = process.argv;
const seed = Number(SEED), runs = Number(RUNS);

// mulberry32 — mesmo gerador de template/.forge/scripts/lib/pbt.mjs (makeRandom), copiado aqui
// como valor: o driver roda contra uma CÓPIA temporária da lib nas mutações [8]/[9]/[10], que não
// tem por que carregar pbt.mjs por caminho relativo a partir de um diretório efêmero.
function makeRandom(s) {
  let a = (s >>> 0) || 1;
  return {
    next() {
      a = (a + 0x6D2B79F5) >>> 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    },
    int(min, max) { return min + Math.floor(this.next() * (max - min + 1)); },
  };
}
function shuffle(list, rnd) {
  const out = list.slice();
  for (let i = out.length - 1; i > 0; i--) { const j = rnd.int(0, i); [out[i], out[j]] = [out[j], out[i]]; }
  return out;
}

// CMD_ENFORCE — forma LEGADA (sem aspas), deliberadamente usada para SEMEAR o estado ANTERIOR ao
// sync (`staleOwned`/`preToolUseItems` abaixo): é assim que um consumidor real, ainda não migrado,
// tem o gancho fiado hoje. CMD_ENFORCE_QUOTED é a forma NOVA que o gerador emite desde o achado de
// correção MEDIUM (iteração 3 do modo correção, quoting de $CLAUDE_PROJECT_DIR) — o pós-sync
// SEMPRE produz a forma com aspas, migrando a legada quando presente. `OWNED` (o filtro do
// pós-sync) reconhece as DUAS; `SEED_POOL` (o que semeia o pré-sync) usa só a legada, de propósito
// — sem isso o espaço de estados do PBT dobraria sem acrescentar cobertura nova.
const CMD_ENFORCE = '$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh';
const CMD_ENFORCE_QUOTED = '"$CLAUDE_PROJECT_DIR"/.forge/hooks/pre-tool-use/enforce-worktree-location.sh';
const CMD_START = '$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-start.sh';
const CMD_START_QUOTED = '"$CLAUDE_PROJECT_DIR"/.forge/hooks/session/on-session-start.sh';
const CMD_END = '$CLAUDE_PROJECT_DIR/.forge/hooks/session/on-session-end.sh';
const CMD_END_QUOTED = '"$CLAUDE_PROJECT_DIR"/.forge/hooks/session/on-session-end.sh';
const SEED_POOL = [CMD_ENFORCE, CMD_START, CMD_END];
const OWNED = new Set([CMD_ENFORCE, CMD_ENFORCE_QUOTED, CMD_START, CMD_START_QUOTED, CMD_END, CMD_END_QUOTED]);

const AUTHOR_POOL = ['permissions', 'env', 'includeCoAuthoredBy', 'model'];
function authorValue(rnd, key) {
  if (key === 'permissions') return { allow: [`Bash(cmd${rnd.int(0, 9999)} *)`], deny: [] };
  if (key === 'env') return { [`VAR_${rnd.int(0, 9999)}`]: `val-${rnd.int(0, 9999)}` };
  if (key === 'includeCoAuthoredBy') return rnd.next() < 0.5;
  return `model-${rnd.int(0, 9)}`;
}

function setYamlFlag(text, key, val) {
  const re = new RegExp(`(^${key}:\\n(?:.*\\n){0,4}?  auto: )(true|false)`, 'm');
  return text.replace(re, `$1${val}`);
}

function flattenCommands(hooks) {
  const out = [];
  for (const cat of Object.keys(hooks || {})) {
    for (const group of hooks[cat] || []) {
      for (const h of (group && group.hooks) || []) out.push(h.command);
    }
  }
  return out;
}

function findCommand(hooks, cmd) { return flattenCommands(hooks).includes(cmd); }

const forgeYamlPath = `${FIXTURE}/.forge/forge.yaml`;
const baseYaml = readFileSync(forgeYamlPath, 'utf8');
const settingsPath = `${FIXTURE}/.claude/settings.json`;

let failures = 0;
for (let i = 0; i < runs; i++) {
  const rnd = makeRandom(seed + i * 7919); // um sub-seed por caso, derivado da seed única do gate
  const chosenAuthorKeys = shuffle(AUTHOR_POOL, rnd).slice(0, rnd.int(0, AUTHOR_POOL.length));
  const authorValues = {};
  for (const k of chosenAuthorKeys) authorValues[k] = authorValue(rnd, k);

  const nForeign = rnd.int(0, 3);
  const foreignCommands = [];
  for (let f = 0; f < nForeign; f++) foreignCommands.push(`$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/terceiro-${i}-${f}.sh`);

  // hooks do harness já presentes no arquivo ANTES do sync — simulam uma configuração de flags
  // ANTERIOR (possivelmente diferente da atual): subconjunto aleatório dos 3 comandos owned.
  const staleOwned = OWNED_SUBSET(rnd);
  function OWNED_SUBSET(rnd) { return SEED_POOL.filter(() => rnd.next() < 0.5); }

  // monta hooks.PreToolUse com terceiros + staleOwned(enforce) misturados, e SessionStart/End
  // com staleOwned(start/end), em ordem embaralhada.
  const preToolUseItems = shuffle([
    ...foreignCommands.map((c) => ({ type: 'command', command: c })),
    ...(staleOwned.includes(CMD_ENFORCE) ? [{ type: 'command', command: CMD_ENFORCE }] : []),
  ], rnd);
  const existingHooks = {};
  if (preToolUseItems.length) existingHooks.PreToolUse = [{ matcher: 'Bash', hooks: preToolUseItems }];
  if (staleOwned.includes(CMD_START)) existingHooks.SessionStart = [{ hooks: [{ type: 'command', command: CMD_START }] }];
  if (staleOwned.includes(CMD_END)) existingHooks.SessionEnd = [{ hooks: [{ type: 'command', command: CMD_END }] }];

  const existing = {};
  const orderedKeys = shuffle([...chosenAuthorKeys, 'hooks'], rnd);
  for (const k of orderedKeys) existing[k] = k === 'hooks' ? existingHooks : authorValues[k];

  // flags ATUAIS (as que o sync vai efetivamente derivar) — independentes do staleOwned acima.
  const handoffAuto = rnd.next() < 0.5;
  const ledgerAuto = rnd.next() < 0.5;
  const liaisonAuto = rnd.next() < 0.5;
  writeFileSync(forgeYamlPath, setYamlFlag(setYamlFlag(baseYaml, 'handoff', handoffAuto), 'ledger', ledgerAuto).replace(
    /(^ledger:\n(?:.*\n){0,6}?  auto: )(true|false)/m, `$1${ledgerAuto}`,
  ));
  // liaison usa outro layout de bloco (mais linhas antes de auto:) — aplica à parte para não
  // depender de a contagem de linhas do handoff/ledger bater com a do liaison.
  {
    let y = readFileSync(forgeYamlPath, 'utf8');
    y = y.replace(/(^liaison:\n(?:.*\n){0,10}?  auto: )(true|false)/m, `$1${liaisonAuto}`);
    writeFileSync(forgeYamlPath, y);
  }

  mkdirSync(dirname(settingsPath), { recursive: true });
  if (existsSync(settingsPath)) unlinkSync(settingsPath);
  writeFileSync(settingsPath, JSON.stringify(existing, null, 2) + '\n');

  execFileSync('bash', [`${FIXTURE}/.forge/scripts/sync-adapters.sh`], { stdio: 'ignore' });

  const resultText = readFileSync(settingsPath, 'utf8');
  const result = JSON.parse(resultText);

  const problems = [];
  for (const k of chosenAuthorKeys) {
    if (JSON.stringify(result[k]) !== JSON.stringify(authorValues[k])) problems.push(`chave autoral '${k}' mudou`);
  }
  const expectedKeys = new Set([...chosenAuthorKeys, 'hooks']);
  const actualKeys = new Set(Object.keys(result));
  if (expectedKeys.size !== actualKeys.size || [...expectedKeys].some((k) => !actualKeys.has(k))) {
    problems.push(`conjunto de chaves de topo divergiu: esperado ${[...expectedKeys].sort()}, obtido ${[...actualKeys].sort()}`);
  }
  for (const c of foreignCommands) {
    if (!findCommand(result.hooks, c)) problems.push(`hook de terceiro '${c}' desapareceu`);
  }
  const mod = await import(pathToFileURL(LIB).href);
  const derived = mod.preToolUseWiring(FIXTURE);
  // Achado de correção LOW (revisão adversarial): multiplicidade, não só presença — um Set
  // esconderia uma entrada derivada DUPLICADA (mesmo comando emitido duas vezes), porque
  // `new Set([...]).size` colapsa repetições. Arrays ordenados comparam CONTAGEM por comando.
  const expectedOwnedList = flattenCommands(derived).sort();
  const actualOwnedList = flattenCommands(result.hooks).filter((c) => OWNED.has(c)).sort();
  if (JSON.stringify(expectedOwnedList) !== JSON.stringify(actualOwnedList)) {
    problems.push(`hooks do harness divergem do esperado (contando duplicatas): esperado ${JSON.stringify(expectedOwnedList)}, obtido ${JSON.stringify(actualOwnedList)}`);
  }

  // Achado de correção LOW: idempotência não era propriedade verificada pela PBT (só pelo cenário
  // fixo [3]) — um segundo sync sobre a MESMA saída aleatória tem de ser byte-idêntico.
  execFileSync('bash', [`${FIXTURE}/.forge/scripts/sync-adapters.sh`], { stdio: 'ignore' });
  const resultText2 = readFileSync(settingsPath, 'utf8');
  if (resultText2 !== resultText) problems.push('segundo sync não é idempotente (bytes mudaram)');

  if (problems.length) {
    failures++;
    console.error(`FAIL caso ${i}: ${problems.join('; ')}`);
    console.error(`  entrada: authorKeys=${JSON.stringify(chosenAuthorKeys)} foreign=${JSON.stringify(foreignCommands)} staleOwned=${JSON.stringify(staleOwned)} flags={handoff:${handoffAuto},ledger:${ledgerAuto},liaison:${liaisonAuto}}`);
    if (failures >= 3) break; // não afoga o log — 3 contraexemplos já ensinam
  }
}
writeFileSync(forgeYamlPath, baseYaml); // restaura o forge.yaml da fixture ao estado original
if (failures > 0) { console.error(`PBT: ${failures} caso(s) falharam de ${runs} (seed ${seed})`); process.exit(1); }
console.log(`OK PBT — ${runs} caso(s), seed ${seed}, 0 falha(s)`);
NODE
PBT_OUT="$(node "$PBT_DRIVER" "$T7" "$T7/$LIB_REL" 20386 60 2>&1)"
PBT_RC=$?
if [ "$PBT_RC" -ne 0 ]; then
  echo "FAIL [7]: $PBT_OUT"
  overall_rc=1
else
  echo "OK [7] — $PBT_OUT"
fi

# ── [8] mutação — reverter para emit({ hooks }) faz [1] falhar nomeando 'permissions' ────────────
echo "[8] mutação: reverter para emit({ hooks }) (defeito original) faz o cenário [1] falhar nomeando 'permissions'"
T8="$(mktemp -d "$TMPROOT/forge-w238-8.XXXXXX")"; track "$T8"
nova_fixture "$T8"
LIB8="$T8/$LIB_REL"
BACKUP8="$(mktemp "$TMPROOT/forge-w238-8-backup.XXXXXX")"; track "$BACKUP8"
cp "$LIB8" "$BACKUP8"

perl -0777 -pi -e "s/const mergedSettings = mergeSettingsJson\(existingSettingsText, preToolUseWiring\(ROOT\), derivation\.ownedSet, frozenCategories\);\n    lock\.emit\(settingsPath, JSON\.stringify\(mergedSettings, null, 2\) \+ '\\\\n'\);/const hooks = preToolUseWiring(ROOT);\n    lock.emit(settingsPath, JSON.stringify({ hooks }, null, 2) + '\\\\n');/" "$LIB8"
if cmp -s "$LIB8" "$BACKUP8"; then
  echo "FAIL [8]: a mutação não alterou nenhum byte da lib — o perl não achou o trecho de emissão"
  overall_rc=1
else
  bash "$T8/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.permissions={allow:["Bash(*)"]};fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T8/.claude/settings.json"
  bash "$T8/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  KEYS8="$(json_keys "$T8/.claude/settings.json")"
  if grep -q '"permissions"' <<<"$KEYS8"; then
    echo "FAIL [8]: com o defeito original restaurado, 'permissions' AINDA sobreviveu — a mutação não acusa (chaves: $KEYS8)"
    overall_rc=1
  else
    echo "OK [8] — mutação acusa: com emit({hooks}) puro, 'permissions' desaparece de novo (chaves: $KEYS8)"
  fi
fi

cp "$BACKUP8" "$LIB8"
if ! cmp -s "$LIB8" "$BACKUP8"; then
  echo "FAIL [8]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  T8R="$(mktemp -d "$TMPROOT/forge-w238-8r.XXXXXX")"; track "$T8R"
  nova_fixture "$T8R"
  cp "$LIB8" "$T8R/$LIB_REL"
  bash "$T8R/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.permissions={allow:["Bash(*)"]};fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T8R/.claude/settings.json"
  bash "$T8R/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  KEYS8R="$(json_keys "$T8R/.claude/settings.json")"
  if ! grep -q '"permissions"' <<<"$KEYS8R"; then
    echo "FAIL [8]: recontrole — com a lib restaurada, 'permissions' ainda não sobrevive: $KEYS8R"
    overall_rc=1
  else
    echo "OK [8] recontrole — lib restaurada byte a byte, 'permissions' volta a sobreviver"
  fi
fi

# ── [9] mutação — posse por MENÇÃO a .forge/hooks/ faz [2] falhar nomeando dispatch-file-hook ───
echo "[9] mutação: trocar posse por igualdade pela menção a '.forge/hooks/' faz [2] falhar nomeando dispatch-file-hook"
T9="$(mktemp -d "$TMPROOT/forge-w238-9.XXXXXX")"; track "$T9"
nova_fixture "$T9"
LIB9="$T9/$LIB_REL"
BACKUP9="$(mktemp "$TMPROOT/forge-w238-9-backup.XXXXXX")"; track "$BACKUP9"
cp "$LIB9" "$BACKUP9"

perl -pi -e "s/!\(h && ownedSet\.has\(h\.command\)\)/!(h \&\& h.command \&\& h.command.includes('.forge\\/hooks\\/'))/" "$LIB9"
if cmp -s "$LIB9" "$BACKUP9"; then
  echo "FAIL [9]: a mutação não alterou nenhum byte da lib — o perl não achou o predicado de posse"
  overall_rc=1
else
  bash "$T9/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  perl -0777 -pi -e 's/(handoff:\n(?:.*\n){2}  auto: )false/${1}true/' "$T9/.forge/forge.yaml"
  cat > "$T9/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)$",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/check-language-policy.sh" }
        ]
      },
      {
        "matcher": "^Bash$",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-docs-on-publish.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" }
        ]
      }
    ]
  }
}
JSON
  bash "$T9/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  if grep -q 'dispatch-file-hook' "$T9/.claude/settings.json"; then
    echo "FAIL [9]: com posse por menção, dispatch-file-hook.sh AINDA sobreviveu — a mutação não acusa"
    overall_rc=1
  else
    echo "OK [9] — mutação acusa: com posse por menção a '.forge/hooks/', dispatch-file-hook.sh desaparece (nomeado)"
  fi
fi

cp "$BACKUP9" "$LIB9"
if ! cmp -s "$LIB9" "$BACKUP9"; then
  echo "FAIL [9]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  T9R="$(mktemp -d "$TMPROOT/forge-w238-9r.XXXXXX")"; track "$T9R"
  nova_fixture "$T9R"
  cp "$LIB9" "$T9R/$LIB_REL"
  bash "$T9R/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  cat > "$T9R/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^(Write|Edit|MultiEdit|NotebookEdit)$",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/check-language-policy.sh" }
        ]
      }
    ]
  }
}
JSON
  bash "$T9R/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  if ! grep -q 'dispatch-file-hook' "$T9R/.claude/settings.json"; then
    echo "FAIL [9]: recontrole — com a lib restaurada, dispatch-file-hook.sh ainda não sobrevive"
    overall_rc=1
  else
    echo "OK [9] recontrole — lib restaurada byte a byte, dispatch-file-hook.sh volta a sobreviver"
  fi
fi

# ── [10] mutação — remover o backup do JSON ilegível faz [4]/[11] falhar ─────────────────────────
echo "[10] mutação: remover a chamada de backup faz o cenário de JSON ilegível ([4]) falhar"
T10BASE="$(mktemp -d "$TMPROOT/forge-w238-10.XXXXXX")"; track "$T10BASE"
git init -q "$T10BASE/repo" -b main
LIB10="$T10BASE/repo/$LIB_REL"
(
  cd "$T10BASE/repo"
  git config user.email t@test; git config user.name t; git config commit.gpgsign false
  nova_fixture "."
  bash .forge/scripts/sync-adapters.sh --set claude >/dev/null 2>&1
  git add -A >/dev/null && git commit -qm init >/dev/null
)
BACKUP10="$(mktemp "$TMPROOT/forge-w238-10-backup.XXXXXX")"; track "$BACKUP10"
cp "$LIB10" "$BACKUP10"

perl -0777 -pi -e "s/} else \{\n        backupUnreadableSettings\(ROOT, settingsPath, rawBytes, reason\);\n        existingSettingsText = null;\n      \}/} else {\n        existingSettingsText = null;\n      }/" "$LIB10"
if cmp -s "$LIB10" "$BACKUP10"; then
  echo "FAIL [10]: a mutação não alterou nenhum byte da lib — o perl não achou o bloco de backup"
  overall_rc=1
else
  printf '{ ainda inválido' > "$T10BASE/repo/.claude/settings.json"
  bash "$T10BASE/repo/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  GITDIR10="$(cd "$T10BASE/repo" && git rev-parse --absolute-git-dir)"
  if [ -d "$GITDIR10/forge-backups" ] && [ -n "$(ls -A "$GITDIR10/forge-backups" 2>/dev/null)" ]; then
    echo "FAIL [10]: sem a chamada de backup, AINDA apareceu um backup — a mutação não acusa"
    overall_rc=1
  else
    echo "OK [10] — mutação acusa: sem a chamada de backup, o JSON ilegível não deixa nenhum rastro anterior"
  fi
fi

cp "$BACKUP10" "$LIB10"
if ! cmp -s "$LIB10" "$BACKUP10"; then
  echo "FAIL [10]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  printf '{ mais uma vez inválido' > "$T10BASE/repo/.claude/settings.json"
  bash "$T10BASE/repo/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  GITDIR10R="$(cd "$T10BASE/repo" && git rev-parse --absolute-git-dir)"
  if [ ! -f "$GITDIR10R/forge-backups/settings-1.json" ] && [ ! -f "$GITDIR10R/forge-backups/settings-2.json" ]; then
    echo "FAIL [10]: recontrole — com a lib restaurada, o backup ainda não aparece"
    overall_rc=1
  else
    echo "OK [10] recontrole — lib restaurada byte a byte, backup volta a aparecer"
  fi
fi

# ── [11] formas de ilegibilidade além de JSON sintaticamente inválido (achado de correção MEDIUM)
echo "[11] JSON válido com bytes não-UTF-8, array no topo, e 'hooks' como array — as três viram backup + WARN, nunca regeneradas em silêncio"
T11BASE="$(mktemp -d "$TMPROOT/forge-w238-11.XXXXXX")"; track "$T11BASE"
git init -q "$T11BASE/repo" -b main
(
  cd "$T11BASE/repo"
  git config user.email t@test; git config user.name t; git config commit.gpgsign false
  nova_fixture "."
  bash .forge/scripts/sync-adapters.sh --set claude >/dev/null 2>&1
  git add -A >/dev/null && git commit -qm init >/dev/null
)

# [11a] JSON sintaticamente válido, mas os bytes não são UTF-8 (Latin-1) — decodificar sem
# `fatal: true` produziria U+FFFD e reescreveria o arquivo corrompido em silêncio.
printf '{ "env": {"X":"caf\xe9"} }' > "$T11BASE/repo/.claude/settings.json"
cp "$T11BASE/repo/.claude/settings.json" "$T11BASE/before-11a.json"
OUT11A="$(cd "$T11BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
BAK11A="$(cd "$T11BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"
if ! grep -qi 'WARN.*settings.json' <<<"$OUT11A"; then
  echo "FAIL [11a]: JSON válido com bytes não-UTF-8 não gerou WARN: $OUT11A"
  overall_rc=1
elif [ ! -f "$BAK11A" ] || ! cmp -s "$T11BASE/before-11a.json" "$BAK11A"; then
  echo "FAIL [11a]: backup ausente ou não byte-idêntico ao conteúdo com bytes não-UTF-8"
  overall_rc=1
elif ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit('env' in j ? 1 : 0)" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11a]: settings.json regenerado ainda tem a chave 'env' — deveria ter sido tratado como ilegível (backup) e regenerado do zero, não preservado com o valor corrompido (U+FFFD)"
  overall_rc=1
else
  echo "OK [11a] — bytes não-UTF-8: backup byte-idêntico, WARN, arquivo regenerado do zero (sem 'env' corrompido)"
fi

# [11b] JSON válido cujo nível de topo é um array.
rm -rf "$T11BASE/repo/.git/forge-backups" 2>/dev/null || true
printf '[{"permissions":{}}]' > "$T11BASE/repo/.claude/settings.json"
cp "$T11BASE/repo/.claude/settings.json" "$T11BASE/before-11b.json"
OUT11B="$(cd "$T11BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
BAK11B="$(cd "$T11BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"
if ! grep -qi 'WARN.*settings.json' <<<"$OUT11B"; then
  echo "FAIL [11b]: JSON válido com array no topo não gerou WARN: $OUT11B"
  overall_rc=1
elif [ ! -f "$BAK11B" ] || ! cmp -s "$T11BASE/before-11b.json" "$BAK11B"; then
  echo "FAIL [11b]: backup ausente ou não byte-idêntico ao array original"
  overall_rc=1
elif ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit(Array.isArray(j)?1:0)" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11b]: settings.json regenerado ainda é um array"
  overall_rc=1
else
  echo "OK [11b] — array no topo: backup byte-idêntico, WARN, arquivo regenerado como objeto"
fi

# [11c] 'hooks' presente, mas como array em vez de objeto.
rm -rf "$T11BASE/repo/.git/forge-backups" 2>/dev/null || true
printf '{"permissions":{},"hooks":[{"x":1}]}' > "$T11BASE/repo/.claude/settings.json"
cp "$T11BASE/repo/.claude/settings.json" "$T11BASE/before-11c.json"
OUT11C="$(cd "$T11BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
BAK11C="$(cd "$T11BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"
if ! grep -qi 'WARN.*settings.json' <<<"$OUT11C"; then
  echo "FAIL [11c]: JSON válido com 'hooks' array não gerou WARN: $OUT11C"
  overall_rc=1
elif [ ! -f "$BAK11C" ] || ! cmp -s "$T11BASE/before-11c.json" "$BAK11C"; then
  echo "FAIL [11c]: backup ausente ou não byte-idêntico ao conteúdo com 'hooks' array"
  overall_rc=1
elif ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit(Array.isArray(j.hooks)?1:0)" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11c]: settings.json regenerado ainda tem 'hooks' como array"
  overall_rc=1
else
  echo "OK [11c] — 'hooks' como array: backup byte-idêntico, WARN, 'hooks' regenerado como objeto"
fi

# [11d] categoria de 'hooks' que não é array (achado de correção LOW, revisão adversarial da 2ª
# iteração) — antes desta correção, mergeHooksObject tratava a categoria como [] e a descartava em
# silêncio; agora o arquivo inteiro é ilegível (backup + WARN), a mesma política de [11a]-[11c].
rm -rf "$T11BASE/repo/.git/forge-backups" 2>/dev/null || true
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh"}]}],"Notification":{"weird":true}}}' > "$T11BASE/repo/.claude/settings.json"
cp "$T11BASE/repo/.claude/settings.json" "$T11BASE/before-11d.json"
OUT11D="$(cd "$T11BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
BAK11D="$(cd "$T11BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"
if ! grep -qi 'WARN.*settings.json' <<<"$OUT11D"; then
  echo "FAIL [11d]: categoria de hooks não-array ('Notification') não gerou WARN: $OUT11D"
  overall_rc=1
elif [ ! -f "$BAK11D" ] || ! cmp -s "$T11BASE/before-11d.json" "$BAK11D"; then
  echo "FAIL [11d]: backup ausente ou não byte-idêntico ao conteúdo com categoria não-array"
  overall_rc=1
elif ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit(j.hooks.Notification === undefined ? 0 : 1)" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11d]: settings.json regenerado ainda tem 'hooks.Notification' — deveria ter sido tratado como ilegível e regenerado do zero"
  overall_rc=1
else
  echo "OK [11d] — categoria 'hooks.Notification' não-array: backup byte-idêntico, WARN, arquivo regenerado do zero"
fi

# [11e] positivo — achado de correção LOW: um grupo de hooks já vazio (hooks:[]), que NÃO continha
# nenhum hook owned, sobrevive ao sync (é uma forma exótica que o Claude Code nunca emite, mas o
# defeito da revisão adversarial descartava QUALQUER grupo com keptHooks.length===0, mesmo quando
# nada tinha sido removido dele).
rm -rf "$T11BASE/repo/.git/forge-backups" 2>/dev/null || true
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh"}]}],"Stop":[{"matcher":"","hooks":[]}]}}' > "$T11BASE/repo/.claude/settings.json"
bash "$T11BASE/repo/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
if ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit((j.hooks.Stop && Array.isArray(j.hooks.Stop) && j.hooks.Stop.length===1 && Array.isArray(j.hooks.Stop[0].hooks) && j.hooks.Stop[0].hooks.length===0) ? 0 : 1)" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11e]: o grupo 'Stop' com hooks:[] (sem nenhum hook owned) não sobreviveu ao sync"
  overall_rc=1
else
  echo "OK [11e] — grupo de terceiro com hooks:[] (sem hook owned) sobrevive ao sync, não é descartado por engano"
fi

# [11f] a chave de topo '__proto__' (achado de correção LOW): tratada como ilegível — backup + WARN
# — nunca copiada por atribuição comum, que trocaria o protótipo do objeto de saída em vez de criar
# a chave. O arquivo escrito à mão precisa ser literal (JSON.parse cria '__proto__' como propriedade
# OWN; um objeto JS não consegue, por isso a fixture usa printf em vez de node -e).
rm -rf "$T11BASE/repo/.git/forge-backups" 2>/dev/null || true
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh"}]}]},"__proto__":{"polluted":true}}' > "$T11BASE/repo/.claude/settings.json"
cp "$T11BASE/repo/.claude/settings.json" "$T11BASE/before-11f.json"
OUT11F="$(cd "$T11BASE/repo" && bash .forge/scripts/sync-adapters.sh 2>&1)"
BAK11F="$(cd "$T11BASE/repo" && git rev-parse --absolute-git-dir)/forge-backups/settings-1.json"
if ! grep -qi "WARN.*settings.json ilegível (chave de topo '__proto__'" <<<"$OUT11F"; then
  echo "FAIL [11f]: a chave de topo '__proto__' não gerou o WARN nomeado esperado: $OUT11F"
  overall_rc=1
elif [ ! -f "$BAK11F" ] || ! cmp -s "$T11BASE/before-11f.json" "$BAK11F"; then
  echo "FAIL [11f]: backup ausente ou não byte-idêntico ao conteúdo com '__proto__'"
  overall_rc=1
elif ! node -e "
  const j = JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
  const protoIntact = Object.getPrototypeOf(j) === Object.prototype;
  const notPolluted = j.polluted === undefined;
  process.exit(protoIntact && notPolluted ? 0 : 1);
" "$T11BASE/repo/.claude/settings.json"; then
  echo "FAIL [11f]: settings.json regenerado tem o protótipo trocado ou herda 'polluted' — a chave '__proto__' vazou para o objeto de saída"
  overall_rc=1
else
  echo "OK [11f] — '__proto__': backup byte-idêntico, WARN, arquivo regenerado sem poluir o protótipo"
fi

# ── [12] MEDIUM (achado de correção da revisão adversarial): desativar o adapter claude não apaga
#     .claude/settings.json inteiro — poda só as entradas owned e preserva o resto ───────────────
echo "[12] desativar o adapter claude preserva .claude/settings.json quando sobra conteúdo não-owned (chave autoral ou hook de terceiro)"
T12="$(mktemp -d "$TMPROOT/forge-w238-12.XXXXXX")"; track "$T12"
nova_fixture "$T12"
fixture_vellus_settled "$T12"
PERM_BEFORE12="$(json_get "$T12/.claude/settings.json" permissions)"
OUT12="$(bash "$T12/.forge/scripts/sync-adapters.sh" --set codex 2>&1)"
if [ ! -f "$T12/.claude/settings.json" ]; then
  echo "FAIL [12]: .claude/settings.json foi apagado ao desativar o adapter claude, mesmo tendo chave autoral e hook de terceiro: $OUT12"
  overall_rc=1
else
  PERM_AFTER12="$(json_get "$T12/.claude/settings.json" permissions)"
  if [ "$PERM_AFTER12" != "$PERM_BEFORE12" ]; then
    echo "FAIL [12]: 'permissions' não ficou byte-idêntico depois de desativar o adapter — antes $PERM_BEFORE12, depois $PERM_AFTER12"
    overall_rc=1
  elif ! grep -q 'prevent-secrets-leak.sh' "$T12/.claude/settings.json"; then
    echo "FAIL [12]: o hook de terceiro não sobreviveu à desativação do adapter claude"
    overall_rc=1
  elif grep -q 'enforce-worktree-location.sh' "$T12/.claude/settings.json"; then
    echo "FAIL [12]: o hook OWNED (enforce-worktree-location.sh) sobreviveu à desativação — deveria ter sido podado, já que nenhum adapter ativo o deriva mais"
    overall_rc=1
  else
    echo "OK [12] — .claude/settings.json mantido com permissions/env/includeCoAuthoredBy intactos, hook de terceiro presente, hook owned podado"
  fi
fi

# [12b] positivo — quando NADA sobra (só hooks, e todos owned), o arquivo É removido.
echo "[12b] desativar o adapter claude remove .claude/settings.json quando só sobrava fiação owned (nada autoral, nenhum hook de terceiro)"
T12B="$(mktemp -d "$TMPROOT/forge-w238-12b.XXXXXX")"; track "$T12B"
nova_fixture "$T12B"
bash "$T12B/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
OUT12B="$(bash "$T12B/.forge/scripts/sync-adapters.sh" --set codex 2>&1)"
if [ -f "$T12B/.claude/settings.json" ]; then
  echo "FAIL [12b]: .claude/settings.json sobreviveu vazio (só tinha fiação owned) — deveria ter sido removido: $(cat "$T12B/.claude/settings.json")"
  overall_rc=1
else
  echo "OK [12b] — .claude/settings.json removido quando não sobra nenhum conteúdo não-owned"
fi

# ── [13] mutação — pruneSettingsJson voltando ao unlink incondicional faz [12] falhar ───────────
echo "[13] mutação: pruneSettingsJson reduzido a 'unlinkSync incondicional' faz o cenário [12] falhar (permissions some)"
T13="$(mktemp -d "$TMPROOT/forge-w238-13.XXXXXX")"; track "$T13"
nova_fixture "$T13"
LIB13="$T13/$LIB_REL"
BACKUP13="$(mktemp "$TMPROOT/forge-w238-13-backup.XXXXXX")"; track "$BACKUP13"
cp "$LIB13" "$BACKUP13"

perl -0777 -pi -e "s/function pruneSettingsJson\(abs\) \{\n  if \(!exists\(abs\)\) return false;/function pruneSettingsJson(abs) {\n  if (!exists(abs)) return false;\n  unlinkSync(abs); return true; \/\/ MUTACAO w238 [13]\n  \/* eslint-disable-next-line no-unreachable *\//" "$LIB13"
if cmp -s "$LIB13" "$BACKUP13"; then
  echo "FAIL [13]: a mutação não alterou nenhum byte da lib — o perl não achou o início de pruneSettingsJson"
  overall_rc=1
else
  T13C="$(mktemp -d "$TMPROOT/forge-w238-13c.XXXXXX")"; track "$T13C"
  nova_fixture "$T13C"
  cp "$LIB13" "$T13C/$LIB_REL"
  fixture_vellus_settled "$T13C"
  bash "$T13C/.forge/scripts/sync-adapters.sh" --set codex >/dev/null 2>&1
  if [ -f "$T13C/.claude/settings.json" ]; then
    echo "FAIL [13]: com o unlink incondicional restaurado, .claude/settings.json AINDA sobreviveu — a mutação não acusa"
    overall_rc=1
  else
    echo "OK [13] — mutação acusa: com pruneSettingsJson reduzido a unlink incondicional, .claude/settings.json (com permissions) some ao desativar o adapter"
  fi
fi

cp "$BACKUP13" "$LIB13"
if ! cmp -s "$LIB13" "$BACKUP13"; then
  echo "FAIL [13]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  T13R="$(mktemp -d "$TMPROOT/forge-w238-13r.XXXXXX")"; track "$T13R"
  nova_fixture "$T13R"
  cp "$LIB13" "$T13R/$LIB_REL"
  fixture_vellus_settled "$T13R"
  bash "$T13R/.forge/scripts/sync-adapters.sh" --set codex >/dev/null 2>&1
  if [ ! -f "$T13R/.claude/settings.json" ]; then
    echo "FAIL [13]: recontrole — com a lib restaurada, .claude/settings.json ainda não sobrevive à desativação"
    overall_rc=1
  else
    echo "OK [13] recontrole — lib restaurada byte a byte, .claude/settings.json volta a sobreviver com permissions"
  fi
fi

# ── [14] mutação — mergeHooksObject sem a condição 'group.hooks.length > 0' faz [11e] falhar ────
echo "[14] mutação: mergeHooksObject descartando por 'keptHooks.length===0' sozinho faz o grupo 'Stop' vazio de [11e] desaparecer"
T14="$(mktemp -d "$TMPROOT/forge-w238-14.XXXXXX")"; track "$T14"
nova_fixture "$T14"
LIB14="$T14/$LIB_REL"
BACKUP14="$(mktemp "$TMPROOT/forge-w238-14-backup.XXXXXX")"; track "$BACKUP14"
cp "$LIB14" "$BACKUP14"

perl -0777 -pi -e "s/if \(group\.hooks\.length > 0 && keptHooks\.length === 0\) continue; \/\/ grupo inteiro era do gerador — descarta/if (keptHooks.length === 0) continue; \/\/ MUTACAO w238 [14]/" "$LIB14"
if cmp -s "$LIB14" "$BACKUP14"; then
  echo "FAIL [14]: a mutação não alterou nenhum byte da lib — o perl não achou a condição de descarte"
  overall_rc=1
else
  bash "$T14/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.hooks.Stop=[{matcher:"",hooks:[]}];fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T14/.claude/settings.json"
  bash "$T14/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  if node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit(j.hooks.Stop ? 0 : 1)" "$T14/.claude/settings.json"; then
    echo "FAIL [14]: com a condição antiga restaurada, o grupo 'Stop' vazio AINDA sobreviveu — a mutação não acusa"
    overall_rc=1
  else
    echo "OK [14] — mutação acusa: sem checar 'group.hooks.length > 0', o grupo de terceiro com hooks:[] desaparece"
  fi
fi

cp "$BACKUP14" "$LIB14"
if ! cmp -s "$LIB14" "$BACKUP14"; then
  echo "FAIL [14]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  T14R="$(mktemp -d "$TMPROOT/forge-w238-14r.XXXXXX")"; track "$T14R"
  nova_fixture "$T14R"
  cp "$LIB14" "$T14R/$LIB_REL"
  bash "$T14R/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  node -e 'const fs=require("fs");const p=process.argv[1];const j=JSON.parse(fs.readFileSync(p,"utf8"));j.hooks.Stop=[{matcher:"",hooks:[]}];fs.writeFileSync(p,JSON.stringify(j,null,2)+"\n");' "$T14R/.claude/settings.json"
  bash "$T14R/.forge/scripts/sync-adapters.sh" >/dev/null 2>&1
  if ! node -e "const j=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.exit(j.hooks.Stop ? 0 : 1)" "$T14R/.claude/settings.json"; then
    echo "FAIL [14]: recontrole — com a lib restaurada, o grupo 'Stop' vazio ainda não sobrevive"
    overall_rc=1
  else
    echo "OK [14] recontrole — lib restaurada byte a byte, grupo 'Stop' vazio volta a sobreviver"
  fi
fi

if [ "$overall_rc" -eq 0 ]; then
  echo "OK"
else
  echo "FAIL"
fi
exit "$overall_rc"
