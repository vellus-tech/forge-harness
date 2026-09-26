#!/usr/bin/env bash
# Gate W215 — a fiação de PreToolUse passa a derivar de .forge/hooks/pre-tool-use/ +
# hooks.manifest.default (produtor) + hooks.manifest (consumidor, leitor canônico w208), e
# prevent-secrets-leak.sh passa a ler o payload por STDIN — issue #125.
#
# POR QUE ESTE GATE EXISTE. `preToolUseWiring(root)` (produtor) montava o array `PreToolUse` com
# UM gancho literal (`enforce-worktree-location.sh`), então nenhum outro hook do diretório era
# fiado por padrão, e um consumidor que tivesse armado `prevent-secrets-leak.sh` à mão perdia essa
# fiação no primeiro `sync`/`update` que reconciliasse `.claude/settings.json` do zero.
# `prevent-secrets-leak.sh` (gancho), à parte, só lia `$1`/`$2` (argv) e saía 0 com argv vazio —
# mas o Claude Code sempre entrega o payload por stdin, então mesmo registrado o gancho aprovava
# qualquer coisa. As duas causas juntas: nenhum consumidor tinha o detector de segredos realmente
# ativo, e quem tentava consertar via `settings.json` perdia o conserto no próximo update.
#
#   [1] positivo (controle) — prevent-secrets-leak.sh via stdin, payload SEM segredo: rc 0.
#   [2] positivo — prevent-secrets-leak.sh via stdin, payload COM segredo (montado em tempo de
#       execução, nunca literal): rc 2 (bloqueia — não rc 1, que o Claude Code não trata como
#       bloqueio de PreToolUse).
#   [3] positivo — prevent-secrets-leak.sh sem argv E sem stdin (payload vazio): fail-closed, rc 2.
#   [4] positivo — uso legado por argv (dispatch-file-hook.sh de um consumidor, ou chamada direta)
#       continua bloqueando payload com segredo: rc 2.
#   [5] positivo — consumidor NOVO (sem .claude/settings.json ainda): primeiro sync arma
#       enforce-worktree-location.sh e prevent-secrets-leak.sh; check-language-policy.sh e
#       validate-naming-conventions.sh (específicos de .NET) nascem retidos por padrão.
#   [6] positivo — semeador: consumidor SEM hooks.manifest cujo settings.json ANTERIOR já tinha
#       prevent-secrets-leak.sh fiado (o estado de quem armou à mão antes desta correção): depois
#       do sync o gancho continua fiado.
#   [6b] contrafactual — mesmo consumidor, mas o settings.json anterior NUNCA fiou
#        prevent-secrets-leak.sh: depois do sync o gancho continua INATIVO, e o sync nomeia o
#        gancho em WARN (nenhum consumidor ganha bloqueio novo sem saber).
#   [7] positivo — fixture real do Axis.PadSimulator (hooks.manifest sem marcador, projeção):
#       prevent-secrets-leak.sh e enforce-worktree-location.sh ativos; check-language-policy.sh e
#       validate-naming-conventions.sh inativos (retidos no manifesto real).
#   [8] positivo — fixture real do axis-fare-validator (hooks.manifest sem marcador + settings.json
#       real com wrappers `dispatch-file-hook.sh`): os grupos de terceiro sobrevivem como objetos
#       IDÊNTICOS (sem duplicar entrada para um gancho que o wrapper já alcança), e
#       `dispatch-file-hook.sh` (presente no diretório, ausente dos dois manifestos) gera AVISO
#       nomeado, nunca reprovação.
#   [9] positivo — fixture real do axis-device-platform (hooks.manifest em dialeto de 4 colunas
#       diferente do PadSimulator — campo 4 é `universo`, não `estado` — mas SEM marcador, então os
#       dois dialetos passam pelo MESMO leitor em modo de projeção): os quatro ganchos, todos já
#       fiados no settings.json real, continuam fiados depois do sync (idempotente).
#   [10] positivo — esquema do consumidor MARCADO e MAL FORMADO (token de estado desconhecido):
#        `.claude/settings.json` anterior fica byte-idêntico, e o sync nomeia LDG-0178 em WARN.
#   [11] positivo — versão mista: `hooks.manifest.default` ausente do diretório (cenário de
#        exceção de maquinaria que preservou hooks/ sem o novo arquivo do produtor) não derruba o
#        gerador; um hook declarado só no hooks.manifest do CONSUMIDOR continua sendo fiado.
#   [12] mutação — reverter a derivação para o literal antigo (só enforce-worktree-location.sh)
#        faz [5] falhar nomeando 'prevent-secrets-leak.sh'. Controle/recontrole por `cmp -s`.
#   [13] mutação — remover a leitura de stdin do gancho de segredos faz [2] sair rc 0 em vez de
#        rc 2. Controle/recontrole por `cmp -s`.
#   [14] PBT — 60 casos, semente fixa (`template/.forge/scripts/lib/pbt.mjs`, `makeRandom`):
#        (a) para diretórios pre-tool-use/ gerados (subconjunto aleatório de ganchos declarados,
#        ativos/inativos, mais um arquivo NÃO declarado), o conjunto de comandos emitidos em
#        PreToolUse é exatamente o dos ganchos declarados ativos, e o arquivo não declarado nunca
#        entra no conjunto emitido; (b) para payloads gerados (Write/Edit/MultiEdit/NotebookEdit)
#        com um padrão de segredo em posição aleatória do conteúdo, o gancho via stdin sai 2.
#
# Achados de correção (revisão adversarial, 2ª iteração) — novos cenários abaixo:
#   [15] positivo — gancho AUTORAL do consumidor (`guard-machinery-drift.sh`, sem estar declarado em
#        nenhum manifesto) fiado direto sob o diretório canônico, sem hooks.manifest: sobrevive ao
#        sync byte-idêntico, e os ganchos do template ao lado dele continuam sendo semeados
#        normalmente. Mutação [15m]: devolver `ownedHookCommandsFor` para "todo `.sh` do diretório"
#        faz o gancho autoral desaparecer da fiação.
#   [16] positivo — homônimo de TERCEIRO fiado noutro caminho (`.claude/hooks/pre-tool-use/
#        prevent-secrets-leak.sh`, medido no vellus-enterprise-ai-platform): o NOSSO detector não é
#        armado por engano — nasce inativo e nomeado — e o homônimo de terceiro sobrevive intacto.
#        Mutação [16m]: devolver a decisão de "já fiado" para `derivarFiacao` (por basename) faz o
#        nosso detector ser armado por engano a partir do homônimo.
#   [17] positivo — NotebookEdit limpo via stdin: rc 0. [17b] positivo — NotebookEdit com segredo em
#        `new_source` via stdin: rc 2 (antes desta correção, TODO NotebookEdit saía rc 2 por não
#        conseguir extrair o payload, limpo ou não — [17] é o cenário que prova que não é mais
#        fail-closed cego).
#   [18] positivo — Edit que REMOVE um segredo de um arquivo que ainda o contém em disco: rc 0 (o
#        PreToolUse roda ANTES da escrita; somar o disco ao conteúdo que entra impedia consertar).
#        [18b] positivo (pareado) — Edit que INTRODUZ um segredo num arquivo limpo em disco: rc 2.
#        Mutação [18m]: voltar a somar `TARGET_CONTENT` incondicionalmente faz [18] sair rc 2.
#   [19] positivo — versão mista: `prevent-secrets-leak.sh` fiado através de `lib/argv-bridge.sh`
#        (cenário de exceção que preserva um wrapper antigo) com payload COM segredo: rc 2 (antes
#        desta correção a ponte só repassava `$1`, o gancho caía no fallback de disco e aprovava
#        `rc 0` com o arquivo ainda inexistente). Mutação [19m]: voltar a ponte a repassar só `$1`
#        faz [19] sair rc 0.
#   [20] positivo — semeador preserva o MATCHER que o consumidor já tinha (`Edit|Write`, sem
#        `NotebookEdit`, não ancorado) em vez de alargar para o matcher ancorado do produtor.
#
# Fixtures: nenhum segredo literal (LDG-0175/w213 e a auto-varredura do w139 [15], que reprova o
# repositório inteiro por qualquer achado) — todo payload de exemplo é montado em tempo de
# execução por concatenação. Os três `hooks.manifest` reais (tests/fixtures/w215/*) são cópias
# literais e não precisaram de sanitização (nenhum contém caminho absoluto de máquina, host,
# e-mail ou token). Toda mutação muta uma CÓPIA da lib/gancho num diretório temporário, nunca o
# arquivo rastreado em `template/.forge/`, e é restaurada e reconferida por `cmp -s` antes de
# seguir.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_REL=".forge/scripts/lib/sync-adapters.mjs"
HOOK_REL=".forge/hooks/pre-tool-use/prevent-secrets-leak.sh"
FIXTURES="$WS/tests/fixtures/w215"
TMPROOT="${TMPDIR:-/tmp}"
overall_rc=0
CLEANUP_DIRS=()
trap 'rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true' EXIT
track() { CLEANUP_DIRS+=("$1"); }

# secret_payload — monta, em tempo de execução, um JSON de payload de Write cujo content carrega
# uma chave AWS de EXEMPLO da documentação pública da AWS, montada por concatenação de prefixo e
# sufixo em variáveis separadas — nenhum padrão de segredo entra como literal no fonte deste gate
# (protocolo item 3; w139 [15] reprova o repositório inteiro por qualquer achado).
secret_payload() { # secret_payload <file_path>
  local prefix="AKIA" suffix="IOSFODNN7EXAMPLE"
  local key="${prefix}${suffix}"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"aws_key = %s"}}' "$1" "$key"
}
clean_payload() { # clean_payload <file_path>
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"hello world"}}' "$1"
}

nova_fixture() { # nova_fixture <dir>
  local dir="$1"
  cp -R "$WS/template/.forge" "$dir/.forge"
  perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture do w215/g' \
    "$dir/.forge/FORGE.md" "$dir/.forge/constitution.md" "$dir/.forge/context.md"
}

hooks_of() { # hooks_of <settings.json> — lista ordenada dos basenames .sh alcançáveis em PreToolUse
  node -e '
    const fs = require("fs");
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const groups = (j.hooks && j.hooks.PreToolUse) || [];
    const out = new Set();
    for (const g of groups) for (const h of (g.hooks || [])) {
      const parts = String(h.command).trim().split(/\s+/);
      const last = parts[parts.length - 1];
      out.add(last.split("/").pop());
    }
    console.log(JSON.stringify([...out].sort()));
  ' "$1"
}

# ── [1]/[2]/[3] prevent-secrets-leak.sh via stdin ────────────────────────────────────────────────
echo "[1] controle: payload SEM segredo via stdin — rc 0"
OUT1="$(clean_payload "/tmp/x.env" | bash "$WS/template/$HOOK_REL" 2>&1)"; RC1=$?
if [ "$RC1" -ne 0 ]; then
  echo "FAIL [1]: payload limpo via stdin saiu rc=$RC1 — esperado 0: $OUT1"
  overall_rc=1
else
  echo "OK [1] — rc 0"
fi

echo "[2] payload COM segredo via stdin — rc 2 (bloqueia)"
OUT2="$(secret_payload "/tmp/x.env" | bash "$WS/template/$HOOK_REL" 2>&1)"; RC2=$?
if [ "$RC2" -ne 2 ]; then
  echo "FAIL [2]: payload com segredo via stdin saiu rc=$RC2 — esperado 2: $OUT2"
  overall_rc=1
else
  echo "OK [2] — rc 2"
fi

echo "[3] payload VAZIO (nem argv, nem stdin) — fail-closed, rc 2"
OUT3="$(printf '' | bash "$WS/template/$HOOK_REL" 2>&1)"; RC3=$?
if [ "$RC3" -ne 2 ]; then
  echo "FAIL [3]: payload vazio saiu rc=$RC3 — esperado 2 (fail-closed): $OUT3"
  overall_rc=1
else
  echo "OK [3] — rc 2"
fi

echo "[4] uso legado por argv continua bloqueando payload com segredo — rc 2"
prefix="AKIA"; suffix="IOSFODNN7EXAMPLE"; key="${prefix}${suffix}"
OUT4="$(bash "$WS/template/$HOOK_REL" "/tmp/x.env" "aws_key = ${key}" 2>&1)"; RC4=$?
if [ "$RC4" -ne 2 ]; then
  echo "FAIL [4]: uso legado por argv saiu rc=$RC4 — esperado 2: $OUT4"
  overall_rc=1
else
  echo "OK [4] — rc 2"
fi

# ── [5] consumidor novo: primeiro sync ───────────────────────────────────────────────────────────
echo "[5] consumidor novo — enforce-worktree-location.sh e prevent-secrets-leak.sh armados; check-language-policy.sh e validate-naming-conventions.sh retidos"
T5="$(mktemp -d "$TMPROOT/forge-w215-5.XXXXXX")"; track "$T5"
nova_fixture "$T5"
bash "$T5/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
GOT5="$(hooks_of "$T5/.claude/settings.json")"
EXPECTED5='["enforce-worktree-location.sh","prevent-secrets-leak.sh"]'
if [ "$GOT5" != "$EXPECTED5" ]; then
  echo "FAIL [5]: conjunto de ganchos ativos = $GOT5 — esperado $EXPECTED5"
  overall_rc=1
else
  echo "OK [5] — $GOT5"
fi

# ── [6]/[6b] semeador ────────────────────────────────────────────────────────────────────────────
echo "[6] semeador: gancho JÁ fiado antes desta correção continua fiado depois do sync"
T6="$(mktemp -d "$TMPROOT/forge-w215-6.XXXXXX")"; track "$T6"
nova_fixture "$T6"
mkdir -p "$T6/.claude"
cat > "$T6/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] },
      { "matcher": "Edit|Write|MultiEdit", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] }
    ]
  }
}
JSON
OUT6="$(bash "$T6/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
GOT6="$(hooks_of "$T6/.claude/settings.json")"
if ! echo "$GOT6" | grep -q 'prevent-secrets-leak.sh'; then
  echo "FAIL [6]: prevent-secrets-leak.sh já estava fiado e desapareceu depois do sync (conjunto: $GOT6). Saída: $OUT6"
  overall_rc=1
else
  echo "OK [6] — $GOT6"
fi

echo "[6b] contrafactual: gancho NUNCA fiado nasce inativo e é nomeado em WARN"
T6B="$(mktemp -d "$TMPROOT/forge-w215-6b.XXXXXX")"; track "$T6B"
nova_fixture "$T6B"
mkdir -p "$T6B/.claude"
cat > "$T6B/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" } ] }
    ]
  }
}
JSON
OUT6B="$(bash "$T6B/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
GOT6B="$(hooks_of "$T6B/.claude/settings.json")"
if echo "$GOT6B" | grep -q 'prevent-secrets-leak.sh'; then
  echo "FAIL [6b]: prevent-secrets-leak.sh nasceu ativo sem nunca ter sido fiado — deveria nascer inativo (desarme silencioso). Conjunto: $GOT6B"
  overall_rc=1
elif ! printf '%s' "$OUT6B" | grep -q "prevent-secrets-leak.sh"; then
  echo "FAIL [6b]: nenhum WARN nomeou 'prevent-secrets-leak.sh' como inativo. Saída: $OUT6B"
  overall_rc=1
else
  echo "OK [6b] — inativo e nomeado: $(printf '%s' "$OUT6B" | grep 'prevent-secrets-leak.sh')"
fi

# ── [7] fixture real: Axis.PadSimulator ──────────────────────────────────────────────────────────
echo "[7] fixture real do Axis.PadSimulator (hooks.manifest sem marcador, projeção)"
T7="$(mktemp -d "$TMPROOT/forge-w215-7.XXXXXX")"; track "$T7"
nova_fixture "$T7"
cp "$FIXTURES/axis-pad-simulator/hooks.manifest" "$T7/.forge/hooks/pre-tool-use/hooks.manifest"
mkdir -p "$T7/.claude"
cp "$FIXTURES/axis-pad-simulator/settings.json" "$T7/.claude/settings.json"
OUT7="$(bash "$T7/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
GOT7="$(hooks_of "$T7/.claude/settings.json")"
EXPECTED7='["enforce-worktree-location.sh","prevent-secrets-leak.sh"]'
if [ "$GOT7" != "$EXPECTED7" ]; then
  echo "FAIL [7]: conjunto ativo = $GOT7 — esperado $EXPECTED7 (check-language-policy.sh e validate-naming-conventions.sh estão 'retido:' no manifesto real). Saída: $OUT7"
  overall_rc=1
else
  echo "OK [7] — $GOT7"
fi

# ── [8] fixture real: axis-fare-validator ────────────────────────────────────────────────────────
echo "[8] fixture real do axis-fare-validator: wrappers dispatch-file-hook.sh preservados, sem duplicata, dispatch-file-hook.sh nomeado em WARN"
T8="$(mktemp -d "$TMPROOT/forge-w215-8.XXXXXX")"; track "$T8"
nova_fixture "$T8"
cp "$FIXTURES/axis-fare-validator/hooks.manifest" "$T8/.forge/hooks/pre-tool-use/hooks.manifest"
# os dois ganchos autorais do axis-fare-validator (fora do universo dos 4 hooks do template) e o
# wrapper dispatch-file-hook.sh precisam existir no diretório para reproduzir a árvore real.
for f in enforce-docs-on-publish.sh guard-machinery-drift.sh dispatch-file-hook.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T8/.forge/hooks/pre-tool-use/$f"
  chmod +x "$T8/.forge/hooks/pre-tool-use/$f"
done
mkdir -p "$T8/.claude"
cp "$FIXTURES/axis-fare-validator/settings.json" "$T8/.claude/settings.json"
cp "$T8/.claude/settings.json" "$T8/.claude/settings.json.before"
OUT8="$(bash "$T8/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
DISPATCH_COUNT8="$(grep -c 'dispatch-file-hook.sh' "$T8/.claude/settings.json")"
FOREIGN_DIFF8="$(node -e '
  const fs = require("fs");
  const before = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const after = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  if (JSON.stringify(before.hooks.PreToolUse) !== JSON.stringify(after.hooks.PreToolUse)) {
    console.log(`PreToolUse mudou: antes=${JSON.stringify(before.hooks.PreToolUse)} depois=${JSON.stringify(after.hooks.PreToolUse)}`);
  } else {
    console.log("");
  }
' "$T8/.claude/settings.json.before" "$T8/.claude/settings.json")"
if [ "$DISPATCH_COUNT8" -ne 3 ]; then
  echo "FAIL [8]: os três wrappers dispatch-file-hook.sh não sobreviveram (achei $DISPATCH_COUNT8). Saída: $OUT8"
  overall_rc=1
elif [ -n "$FOREIGN_DIFF8" ]; then
  echo "FAIL [8]: PreToolUse mudou byte a byte quando deveria ficar intacto — $FOREIGN_DIFF8"
  overall_rc=1
elif ! printf '%s' "$OUT8" | grep -q "dispatch-file-hook.sh"; then
  echo "FAIL [8]: nenhum WARN nomeou 'dispatch-file-hook.sh' (presente no diretório, ausente dos dois manifestos). Saída: $OUT8"
  overall_rc=1
else
  echo "OK [8] — wrappers intactos, PreToolUse byte-idêntico, dispatch-file-hook.sh nomeado: $(printf '%s' "$OUT8" | grep 'dispatch-file-hook.sh')"
fi

# ── [9] fixture real: axis-device-platform ───────────────────────────────────────────────────────
echo "[9] fixture real do axis-device-platform (dialeto de 4 colunas com 'universo', sem marcador): idempotente"
T9="$(mktemp -d "$TMPROOT/forge-w215-9.XXXXXX")"; track "$T9"
nova_fixture "$T9"
cp "$FIXTURES/axis-device-platform/hooks.manifest" "$T9/.forge/hooks/pre-tool-use/hooks.manifest"
mkdir -p "$T9/.claude"
cp "$FIXTURES/axis-device-platform/settings.json" "$T9/.claude/settings.json"
cp "$T9/.claude/settings.json" "$T9/.claude/settings.json.before"
OUT9="$(bash "$T9/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
GOT9="$(hooks_of "$T9/.claude/settings.json")"
EXPECTED9='["check-language-policy.sh","enforce-worktree-location.sh","prevent-secrets-leak.sh","validate-naming-conventions.sh"]'
if [ "$GOT9" != "$EXPECTED9" ]; then
  echo "FAIL [9]: conjunto ativo = $GOT9 — esperado $EXPECTED9. Saída: $OUT9"
  overall_rc=1
else
  echo "OK [9] — $GOT9"
fi

# ── [10] esquema marcado e mal formado: settings.json anterior fica byte-idêntico, WARN LDG-0178 ──
echo "[10] hooks.manifest do consumidor MARCADO e mal formado — settings.json anterior byte-idêntico, WARN nomeia LDG-0178"
T10="$(mktemp -d "$TMPROOT/forge-w215-10.XXXXXX")"; track "$T10"
nova_fixture "$T10"
bash "$T10/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
printf '# forge-manifest-format: 1\n#hook\tmatcher\tcontrato\testado\nprevent-secrets-leak.sh\t^(Write|Edit)$\tstdin-json\tnem-armado-nem-retido\n' \
  > "$T10/.forge/hooks/pre-tool-use/hooks.manifest"
cp "$T10/.claude/settings.json" "$T10/.claude/settings.json.before"
OUT10="$(bash "$T10/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
if ! cmp -s "$T10/.claude/settings.json.before" "$T10/.claude/settings.json"; then
  echo "FAIL [10]: settings.json mudou byte a byte com manifesto marcado mal formado — deveria ficar exatamente como estava"
  overall_rc=1
elif ! printf '%s' "$OUT10" | grep -q "LDG-0178"; then
  echo "FAIL [10]: nenhum WARN nomeou LDG-0178. Saída: $OUT10"
  overall_rc=1
else
  echo "OK [10] — byte-idêntico, LDG-0178 nomeado: $(printf '%s' "$OUT10" | grep 'LDG-0178')"
fi

# ── [11] versão mista: hooks.manifest.default ausente do diretório ──────────────────────────────
echo "[11] versão mista: hooks.manifest.default ausente — hook declarado só no manifesto do consumidor ainda é fiado"
T11="$(mktemp -d "$TMPROOT/forge-w215-11.XXXXXX")"; track "$T11"
nova_fixture "$T11"
rm -f "$T11/.forge/hooks/pre-tool-use/hooks.manifest.default"
# manifesto do consumidor MARCADO (canônico): não depende de fiação observada para resolver a
# ativação, então continua resolvendo mesmo com hooks.manifest.default ausente (o cenário
# unmarked/projeção, sem settings.json anterior, é genuinamente NAO_VERIFICADO — third estado
# correto do leitor, não um defeito desta issue).
printf '# forge-manifest-format: 1\n#hook\tmatcher\tcontrato\testado\nprevent-secrets-leak.sh\t^(Write|Edit)$\tstdin-json\tarmado\n' \
  > "$T11/.forge/hooks/pre-tool-use/hooks.manifest"
OUT11="$(bash "$T11/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
RC11=$?
GOT11="$(hooks_of "$T11/.claude/settings.json" 2>/dev/null || echo '[]')"
if [ "$RC11" -ne 0 ]; then
  echo "FAIL [11]: sync saiu rc=$RC11 com hooks.manifest.default ausente — não deveria derrubar o gerador. Saída: $OUT11"
  overall_rc=1
elif ! echo "$GOT11" | grep -q 'prevent-secrets-leak.sh'; then
  echo "FAIL [11]: prevent-secrets-leak.sh, declarado só no manifesto do consumidor, não foi fiado sem hooks.manifest.default. Conjunto: $GOT11"
  overall_rc=1
else
  echo "OK [11] — $GOT11"
fi

# ── [12] mutação — reverter a derivação para o literal antigo ───────────────────────────────────
echo "[12] mutação: reverter preToolUseWiring para o literal antigo (só enforce-worktree-location.sh) faz [5] falhar nomeando prevent-secrets-leak.sh"
T12="$(mktemp -d "$TMPROOT/forge-w215-12.XXXXXX")"; track "$T12"
nova_fixture "$T12"
LIB12="$T12/$LIB_REL"
cp "$LIB12" "$T12/lib.orig.mjs"
# a mutação real: substitui o corpo de preToolUseWiring por uma versão que só emite o hook
# literal antigo, ignorando o diretório/manifesto — o defeito original desta issue.
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  let src = fs.readFileSync(p, "utf8");
  const marker = "export function preToolUseWiring(root) {";
  const i = src.indexOf(marker);
  if (i < 0) { console.error("MUTATION-SETUP-FAILED: marcador de preToolUseWiring não encontrado"); process.exit(1); }
  const mutated = "export function preToolUseWiring(root) {\n" +
    "  const hooks = { PreToolUse: [{ matcher: \"Bash\", hooks: [{ type: \"command\", command: \"$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh\" }] }] };\n" +
    "  return hooks;\n" +
    "}\n" +
    "function _unusedOriginal_" + Date.now() + "(root) {\n";
  src = src.slice(0, i) + mutated + src.slice(i + marker.length);
  fs.writeFileSync(p, src);
' "$LIB12"
if cmp -s "$T12/lib.orig.mjs" "$LIB12"; then
  echo "FAIL [12]: setup da mutação não alterou o arquivo — nada foi provado"
  overall_rc=1
else
  bash "$T12/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  GOT12="$(hooks_of "$T12/.claude/settings.json")"
  if echo "$GOT12" | grep -q 'prevent-secrets-leak.sh'; then
    echo "FAIL [12]: a mutação (literal antigo) não derrubou o cenário — prevent-secrets-leak.sh continuou no conjunto ($GOT12)"
    overall_rc=1
  else
    echo "OK [12] — mutante reprovado (conjunto sem prevent-secrets-leak.sh: $GOT12)"
  fi
  cp "$T12/lib.orig.mjs" "$LIB12"
  if ! cmp -s "$T12/lib.orig.mjs" "$LIB12"; then
    echo "FAIL [12]: recontrole — restauração da lib mutada não ficou byte-idêntica ao original"
    overall_rc=1
  else
    rm -f "$T12/.claude/settings.json"
    bash "$T12/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
    GOT12R="$(hooks_of "$T12/.claude/settings.json")"
    if ! echo "$GOT12R" | grep -q 'prevent-secrets-leak.sh'; then
      echo "FAIL [12]: recontrole — depois de restaurar a lib original, prevent-secrets-leak.sh continua fora do conjunto ($GOT12R)"
      overall_rc=1
    else
      echo "OK [12] recontrole — lib original restaurada, prevent-secrets-leak.sh volta ($GOT12R)"
    fi
  fi
fi

# ── [13] mutação — remover a leitura de stdin do gancho de segredos ─────────────────────────────
echo "[13] mutação: remover a leitura de stdin de prevent-secrets-leak.sh faz [2] sair rc 0 em vez de rc 2"
T13="$(mktemp -d "$TMPROOT/forge-w215-13.XXXXXX")"; track "$T13"
mkdir -p "$T13"
HOOK13="$T13/prevent-secrets-leak.sh"
cp "$WS/template/$HOOK_REL" "$HOOK13"
cp "$HOOK13" "$T13/hook.orig.sh"
# mutação: força FILE a permanecer vazio mesmo com FROM_STDIN, pulando a extração — o hook então
# cai direto no "exit 0" de FILE vazio, reproduzindo o defeito original (argv vazio ⇒ aprova).
# mutação: insere um "exit 0" logo na abertura do bloco "sem argv, lê stdin" — reproduz o defeito
# original (o gancho aprova quando argv vem vazio, sem sequer tentar ler o stdin).
perl -0777 -pi -e 's/(if \[\[ -z "\$FILE" \]\]; then\n)(\s*input=)/${1}  exit 0 # MUTATED\n${2}/' "$HOOK13"
if cmp -s "$T13/hook.orig.sh" "$HOOK13"; then
  echo "FAIL [13]: setup da mutação não alterou o gancho — nada foi provado"
  overall_rc=1
else
  OUT13M="$(secret_payload "/tmp/x.env" | bash "$HOOK13" 2>&1)"; RC13M=$?
  if [ "$RC13M" -eq 2 ]; then
    echo "FAIL [13]: a mutação (sem leitura de stdin) não derrubou o cenário — ainda saiu rc 2"
    overall_rc=1
  else
    echo "OK [13] — mutante reprovado (rc=$RC13M em vez de 2)"
  fi
  cp "$T13/hook.orig.sh" "$HOOK13"
  if ! cmp -s "$T13/hook.orig.sh" "$HOOK13"; then
    echo "FAIL [13]: recontrole — restauração do gancho mutado não ficou byte-idêntica ao original"
    overall_rc=1
  else
    OUT13R="$(secret_payload "/tmp/x.env" | bash "$HOOK13" 2>&1)"; RC13R=$?
    if [ "$RC13R" -ne 2 ]; then
      echo "FAIL [13]: recontrole — gancho original restaurado não voltou a sair rc 2 (rc=$RC13R)"
      overall_rc=1
    else
      echo "OK [13] recontrole — gancho original restaurado, rc 2"
    fi
  fi
fi

# ── [14] PBT — 60 casos, semente fixa ────────────────────────────────────────────────────────────
echo "[14] PBT: 60 casos (semente 48213) — conjunto emitido == ganchos declarados ativos; arquivo não declarado nomeado e fora do conjunto; payload com segredo em posição aleatória sai rc 2"
T14="$(mktemp -d "$TMPROOT/forge-w215-14.XXXXXX")"; track "$T14"
nova_fixture "$T14"
PBT_LIB="$WS/template/.forge/scripts/lib/pbt.mjs"
PBT_DRIVER="$T14/pbt-driver.mjs"
cat > "$PBT_DRIVER" <<'NODE'
import { pathToFileURL } from 'node:url';
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const [, , PBT_LIB, FIXTURE, SEED, RUNS] = process.argv;
const { makeRandom, shuffle } = await import(pathToFileURL(PBT_LIB).href);

const HOOKS_DIR = `${FIXTURE}/.forge/hooks/pre-tool-use`;
const HOOK_FILES = ['enforce-worktree-location.sh', 'prevent-secrets-leak.sh', 'check-language-policy.sh', 'validate-naming-conventions.sh'];
const HOOK_SCRIPT = `${HOOKS_DIR}/prevent-secrets-leak.sh`;

const SECRET_PATTERNS = [
  () => `AKIA${'IOSFODNN7EXAMPLE'}`,
  () => `eyJ${'hbGciOiJIUzI1NiJ9'}.eyJ${'zdWIiOiIxMjM0NTY3ODkwIn0'}.${'dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'}`,
  () => `-----BEGIN ${'RSA PRIVATE KEY'}-----`,
];

let failures = 0;
for (let i = 0; i < Number(RUNS); i++) {
  const rnd = makeRandom(Number(SEED) + i * 7919);

  // (a) manifesto gerado: subconjunto aleatório de HOOK_FILES como declarado+ativo/inativo, mais
  // um arquivo NÃO declarado no diretório.
  const declared = shuffle(HOOK_FILES, rnd).slice(0, rnd.int(1, HOOK_FILES.length));
  const activeSet = new Set(declared.filter(() => rnd.next() < 0.5));
  if (activeSet.size === 0 && declared.length) activeSet.add(declared[0]); // evita vacuidade sempre-vazia
  const lines = ['# forge-manifest-format: 1', '#hook\tmatcher\tcontrato\testado'];
  for (const h of declared) {
    const matcher = h === 'enforce-worktree-location.sh' ? '^Bash$' : '^(Write|Edit|MultiEdit)$';
    const contrato = (h === 'enforce-worktree-location.sh' || h === 'prevent-secrets-leak.sh') ? 'stdin-json' : 'argv';
    const estado = activeSet.has(h) ? 'armado' : 'retido:pbt';
    lines.push(`${h}\t${matcher}\t${contrato}\t${estado}`);
  }
  writeFileSync(`${HOOKS_DIR}/hooks.manifest`, lines.join('\n') + '\n');
  const undeclaredName = `pbt-undeclared-${i}.sh`;
  writeFileSync(`${HOOKS_DIR}/${undeclaredName}`, '#!/usr/bin/env bash\nexit 0\n', { mode: 0o755 });

  if (existsSync(`${FIXTURE}/.claude/settings.json`)) rmSync(`${FIXTURE}/.claude/settings.json`);
  execFileSync('bash', [`${FIXTURE}/.forge/scripts/sync-adapters.sh`, '--set', 'claude'], { stdio: 'ignore' });

  const settings = JSON.parse(readFileSync(`${FIXTURE}/.claude/settings.json`, 'utf8'));
  const groups = (settings.hooks && settings.hooks.PreToolUse) || [];
  const emitted = new Set();
  for (const g of groups) for (const h of (g.hooks || [])) emitted.add(String(h.command).trim().split(/\s+/).pop().split('/').pop());

  const expected = new Set([...activeSet]);
  const gotSorted = [...emitted].sort();
  const expectedSorted = [...expected].sort();
  if (JSON.stringify(gotSorted) !== JSON.stringify(expectedSorted)) {
    console.log(`FAIL-PBT-A: caso ${i} (seed ${SEED}) — emitido=${JSON.stringify(gotSorted)} esperado=${JSON.stringify(expectedSorted)} (declared=${JSON.stringify(declared)}, active=${JSON.stringify([...activeSet])})`);
    failures++;
  } else if (emitted.has(undeclaredName)) {
    console.log(`FAIL-PBT-A: caso ${i} — arquivo não declarado '${undeclaredName}' entrou no conjunto emitido`);
    failures++;
  }
  rmSync(`${HOOKS_DIR}/${undeclaredName}`);

  // (b) payload com segredo em posição aleatória do content — o gancho via stdin sai 2. Achado de
  // correção HIGH (revisão adversarial, 2ª iteração): a geração agora sorteia também NotebookEdit
  // (campo `new_source`, sem `file_path` — só `notebook_path`), que antes desta correção caía
  // sempre no fail-closed de "não consegui extrair o payload" independente do conteúdo.
  const pattern = SECRET_PATTERNS[rnd.int(0, SECRET_PATTERNS.length - 1)]();
  const noiseBefore = 'x'.repeat(rnd.int(0, 40));
  const noiseAfter = 'y'.repeat(rnd.int(0, 40));
  const content = `${noiseBefore}${pattern}${noiseAfter}`.replace(/"/g, '');
  const isNotebook = rnd.next() < 0.3;
  const payload = isNotebook
    ? JSON.stringify({ tool_name: 'NotebookEdit', tool_input: { notebook_path: '/tmp/pbt.ipynb', new_source: content } })
    : JSON.stringify({ tool_name: 'Write', tool_input: { file_path: '/tmp/pbt.env', content } });
  let rc;
  try {
    execFileSync('bash', [HOOK_SCRIPT], { input: payload, stdio: ['pipe', 'ignore', 'ignore'] });
    rc = 0;
  } catch (e) {
    rc = e.status ?? -1;
  }
  if (rc !== 2) {
    console.log(`FAIL-PBT-B: caso ${i} (seed ${SEED}, tool=${isNotebook ? 'NotebookEdit' : 'Write'}) — payload com segredo saiu rc=${rc}, esperado 2 (content=${JSON.stringify(content)})`);
    failures++;
  }
}
console.log(failures === 0 ? `OK-PBT: ${RUNS} caso(s), 0 falha(s)` : `FALHAS-PBT: ${failures}`);
process.exit(failures === 0 ? 0 : 1);
NODE
OUT14="$(node "$PBT_DRIVER" "$PBT_LIB" "$T14" 48213 60 2>&1)"; RC14=$?
if [ "$RC14" -ne 0 ]; then
  echo "FAIL [14]: PBT encontrou contraexemplo(s):"
  echo "$OUT14"
  overall_rc=1
else
  echo "OK [14] — $OUT14"
fi

# matcher_of <settings.json> <hook-basename> — o matcher do grupo que contém o gancho, ou "" se ausente.
matcher_of() {
  node -e '
    const fs = require("fs");
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const groups = (j.hooks && j.hooks.PreToolUse) || [];
    for (const g of groups) for (const h of (g.hooks || [])) {
      const parts = String(h.command).trim().split(/\s+/);
      const last = parts[parts.length - 1].split("/").pop();
      if (last === process.argv[2]) { console.log(g.matcher); process.exit(0); }
    }
    console.log("");
  ' "$1" "$2"
}

# ── [15] gancho AUTORAL do consumidor, sem manifesto: sobrevive byte a byte ─────────────────────────
echo "[15] gancho autoral do consumidor (guard-machinery-drift.sh, não declarado em nenhum manifesto), fiado direto sob o diretório canônico, sem hooks.manifest — sobrevive ao sync, e os ganchos do template ao lado continuam sendo semeados"
T15="$(mktemp -d "$TMPROOT/forge-w215-15.XXXXXX")"; track "$T15"
nova_fixture "$T15"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T15/.forge/hooks/pre-tool-use/guard-machinery-drift.sh"
chmod +x "$T15/.forge/hooks/pre-tool-use/guard-machinery-drift.sh"
mkdir -p "$T15/.claude"
cat > "$T15/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/guard-machinery-drift.sh" }
      ] }
    ]
  }
}
JSON
OUT15="$(bash "$T15/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
GOT15="$(hooks_of "$T15/.claude/settings.json")"
EXPECTED15='["enforce-worktree-location.sh","guard-machinery-drift.sh"]'
if [ "$GOT15" != "$EXPECTED15" ]; then
  echo "FAIL [15]: conjunto ativo = $GOT15 — esperado $EXPECTED15 (guard-machinery-drift.sh sobrevive como terceiro; enforce-worktree-location.sh, único gancho do template já fiado, continua semeado; prevent-secrets-leak.sh, nunca fiado e sem manifesto, nasce inativo). Saída: $OUT15"
  overall_rc=1
elif ! printf '%s' "$OUT15" | grep -q "prevent-secrets-leak.sh"; then
  echo "FAIL [15]: prevent-secrets-leak.sh deveria nascer inativo e NOMEADO em WARN (semeador, declarado em hooks.manifest.default, nunca fiado) — nenhum WARN o nomeou. Saída: $OUT15"
  overall_rc=1
else
  echo "OK [15] — gancho autoral preservado, ganchos do template seguem sendo processados normalmente: $GOT15"
fi

echo "[15m] mutação: devolver ownedHookCommandsFor para 'todo .sh do diretório' faz o gancho autoral desaparecer"
T15M="$(mktemp -d "$TMPROOT/forge-w215-15m.XXXXXX")"; track "$T15M"
nova_fixture "$T15M"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T15M/.forge/hooks/pre-tool-use/guard-machinery-drift.sh"
chmod +x "$T15M/.forge/hooks/pre-tool-use/guard-machinery-drift.sh"
mkdir -p "$T15M/.claude"
cat > "$T15M/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/guard-machinery-drift.sh" }
      ] }
    ]
  }
}
JSON
LIB15M="$T15M/$LIB_REL"
cp "$LIB15M" "$T15M/lib.orig.mjs"
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  let src = fs.readFileSync(p, "utf8");
  const marker = "function declaredHookNames(hooksDir) {\n  const names = new Set();";
  const i = src.indexOf(marker);
  if (i < 0) { console.error("MUTATION-SETUP-FAILED: marcador de declaredHookNames não encontrado"); process.exit(1); }
  const mutated = "function declaredHookNames(hooksDir) {\n  return new Set(listHookFiles(hooksDir)); // MUTATED-15\n  const names = new Set();";
  src = src.slice(0, i) + mutated + src.slice(i + marker.length);
  fs.writeFileSync(p, src);
' "$LIB15M"
if cmp -s "$T15M/lib.orig.mjs" "$LIB15M"; then
  echo "FAIL [15m]: setup da mutação não alterou o arquivo — nada foi provado"
  overall_rc=1
else
  bash "$T15M/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  GOT15M="$(hooks_of "$T15M/.claude/settings.json")"
  if echo "$GOT15M" | grep -q 'guard-machinery-drift.sh'; then
    echo "FAIL [15m]: a mutação (ownedSet largo) não derrubou o cenário — guard-machinery-drift.sh continuou no conjunto ($GOT15M)"
    overall_rc=1
  else
    echo "OK [15m] — mutante reprovado (conjunto sem guard-machinery-drift.sh: $GOT15M)"
  fi
  cp "$T15M/lib.orig.mjs" "$LIB15M"
  if ! cmp -s "$T15M/lib.orig.mjs" "$LIB15M"; then
    echo "FAIL [15m]: recontrole — restauração da lib mutada não ficou byte-idêntica ao original"
    overall_rc=1
  else
    rm -f "$T15M/.claude/settings.json"
    cat > "$T15M/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "^Bash$", "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/guard-machinery-drift.sh" }
      ] }
    ]
  }
}
JSON
    bash "$T15M/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
    GOT15R="$(hooks_of "$T15M/.claude/settings.json")"
    if ! echo "$GOT15R" | grep -q 'guard-machinery-drift.sh'; then
      echo "FAIL [15m]: recontrole — depois de restaurar a lib original, guard-machinery-drift.sh continua fora do conjunto ($GOT15R)"
      overall_rc=1
    else
      echo "OK [15m] recontrole — lib original restaurada, guard-machinery-drift.sh volta ($GOT15R)"
    fi
  fi
fi

# ── [16] homônimo de TERCEIRO não arma o nosso detector por engano ──────────────────────────────────
echo "[16] homônimo de terceiro (.claude/hooks/pre-tool-use/prevent-secrets-leak.sh) não arma o nosso detector; nasce inativo e nomeado"
T16="$(mktemp -d "$TMPROOT/forge-w215-16.XXXXXX")"; track "$T16"
nova_fixture "$T16"
mkdir -p "$T16/.claude"
cat > "$T16/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] }
    ]
  }
}
JSON
OUT16="$(bash "$T16/.forge/scripts/sync-adapters.sh" --set claude 2>&1)"
if node -e '
  const fs = require("fs");
  const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const groups = (j.hooks && j.hooks.PreToolUse) || [];
  let found = false;
  for (const g of groups) for (const h of (g.hooks || [])) {
    if (String(h.command).includes(".forge/hooks/pre-tool-use/prevent-secrets-leak.sh")) found = true;
  }
  process.exit(found ? 1 : 0);
' "$T16/.claude/settings.json"; then
  if ! printf '%s' "$OUT16" | grep -q "prevent-secrets-leak.sh"; then
    echo "FAIL [16]: nosso detector não foi armado (correto), mas nenhum WARN o nomeou como inativo. Saída: $OUT16"
    overall_rc=1
  elif ! grep -q '.claude/hooks/pre-tool-use/prevent-secrets-leak.sh' "$T16/.claude/settings.json"; then
    echo "FAIL [16]: o homônimo de terceiro não sobreviveu ao sync"
    overall_rc=1
  else
    echo "OK [16] — homônimo preservado, nosso detector inativo e nomeado"
  fi
else
  echo "FAIL [16]: nosso detector (.forge/hooks/pre-tool-use/prevent-secrets-leak.sh) foi armado por engano a partir de um homônimo de terceiro noutro caminho"
  overall_rc=1
fi

echo "[16m] mutação: devolver a decisão de 'já fiado' para basename (estilo derivarFiacao) arma o nosso detector a partir do homônimo"
T16M="$(mktemp -d "$TMPROOT/forge-w215-16m.XXXXXX")"; track "$T16M"
nova_fixture "$T16M"
mkdir -p "$T16M/.claude"
cat > "$T16M/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] }
    ]
  }
}
JSON
LIB16M="$T16M/$LIB_REL"
cp "$LIB16M" "$T16M/lib.orig.mjs"
node -e '
  const fs = require("fs");
  const p = process.argv[1];
  let src = fs.readFileSync(p, "utf8");
  const marker = "const wired = findWiredForm(existingGroups, hook);";
  const i = src.indexOf(marker);
  if (i < 0) { console.error("MUTATION-SETUP-FAILED: marcador de findWiredForm não encontrado"); process.exit(1); }
  const mutated = "const wired = (function(){ for (const g of existingGroups || []) { for (const h of (g && g.hooks) || []) { if (!h || typeof h.command !== \"string\") continue; const parts = h.command.trim().split(/\\s+/); const last = parts[parts.length-1].split(\"/\").pop(); if (last === hook) return { matcher: g.matcher, contrato: fromDefault.contrato }; } } return null; })(); // MUTATED-16 basename";
  src = src.slice(0, i) + mutated + src.slice(i + marker.length);
  fs.writeFileSync(p, src);
' "$LIB16M"
if cmp -s "$T16M/lib.orig.mjs" "$LIB16M"; then
  echo "FAIL [16m]: setup da mutação não alterou o arquivo — nada foi provado"
  overall_rc=1
else
  bash "$T16M/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
  ARMED16M="$(node -e '
    const fs = require("fs");
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const groups = (j.hooks && j.hooks.PreToolUse) || [];
    let found = false;
    for (const g of groups) for (const h of (g.hooks || [])) {
      if (String(h.command) === "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh") found = true;
    }
    console.log(found ? "1" : "0");
  ' "$T16M/.claude/settings.json")"
  if [ "$ARMED16M" != "1" ]; then
    echo "FAIL [16m]: a mutação (basename) não derrubou o cenário — nosso detector continuou inativo"
    overall_rc=1
  else
    echo "OK [16m] — mutante reprovado (detector armado por engano a partir do homônimo)"
  fi
  cp "$T16M/lib.orig.mjs" "$LIB16M"
  if ! cmp -s "$T16M/lib.orig.mjs" "$LIB16M"; then
    echo "FAIL [16m]: recontrole — restauração da lib mutada não ficou byte-idêntica ao original"
    overall_rc=1
  else
    rm -f "$T16M/.claude/settings.json"
    cat > "$T16M/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] }
    ]
  }
}
JSON
    bash "$T16M/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
    ARMED16R="$(node -e '
      const fs = require("fs");
      const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const groups = (j.hooks && j.hooks.PreToolUse) || [];
      let found = false;
      for (const g of groups) for (const h of (g.hooks || [])) {
        if (String(h.command) === "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh") found = true;
      }
      console.log(found ? "1" : "0");
    ' "$T16M/.claude/settings.json")"
    if [ "$ARMED16R" != "0" ]; then
      echo "FAIL [16m]: recontrole — depois de restaurar a lib original, o detector continua armado por engano"
      overall_rc=1
    else
      echo "OK [16m] recontrole — lib original restaurada, detector volta a nascer inativo"
    fi
  fi
fi

# ── [17] NotebookEdit ────────────────────────────────────────────────────────────────────────────
echo "[17] NotebookEdit limpo via stdin — rc 0"
OUT17="$(printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/tmp/nb.ipynb","new_source":"print(1)"}}' | bash "$WS/template/$HOOK_REL" 2>&1)"; RC17=$?
if [ "$RC17" -ne 0 ]; then
  echo "FAIL [17]: NotebookEdit limpo saiu rc=$RC17 — esperado 0: $OUT17"
  overall_rc=1
else
  echo "OK [17] — rc 0"
fi

echo "[17b] NotebookEdit com segredo em new_source via stdin — rc 2"
prefix="AKIA"; suffix="IOSFODNN7EXAMPLE"; key="${prefix}${suffix}"
OUT17B="$(printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"/tmp/nb.ipynb","new_source":"aws_key = %s"}}' "$key" | bash "$WS/template/$HOOK_REL" 2>&1)"; RC17B=$?
if [ "$RC17B" -ne 2 ]; then
  echo "FAIL [17b]: NotebookEdit com segredo saiu rc=$RC17B — esperado 2: $OUT17B"
  overall_rc=1
else
  echo "OK [17b] — rc 2"
fi

# ── [18] conteúdo que ENTRA, nunca somado ao disco quando o payload já traz bytes ──────────────────
echo "[18] Edit que REMOVE um segredo de um arquivo que ainda o contém em disco — rc 0"
T18="$(mktemp -d "$TMPROOT/forge-w215-18.XXXXXX")"; track "$T18"
F18="$T18/secret.env"
printf 'aws_key = %s\n' "${prefix}${suffix}" > "$F18"
PAYLOAD18="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"aws_key = %s","new_string":"aws_key = os.environ[chave]"}}' "$F18" "${prefix}${suffix}")"
OUT18="$(printf '%s' "$PAYLOAD18" | bash "$WS/template/$HOOK_REL" 2>&1)"; RC18=$?
if [ "$RC18" -ne 0 ]; then
  echo "FAIL [18]: Edit removendo o segredo (disco ainda o contém) saiu rc=$RC18 — esperado 0: $OUT18"
  overall_rc=1
else
  echo "OK [18] — rc 0"
fi

echo "[18b] pareado: Edit que INTRODUZ um segredo num arquivo limpo em disco — rc 2"
F18B="$T18/clean.env"
printf 'hello\n' > "$F18B"
PAYLOAD18B="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"hello","new_string":"aws_key = %s"}}' "$F18B" "${prefix}${suffix}")"
OUT18B="$(printf '%s' "$PAYLOAD18B" | bash "$WS/template/$HOOK_REL" 2>&1)"; RC18B=$?
if [ "$RC18B" -ne 2 ]; then
  echo "FAIL [18b]: Edit introduzindo o segredo saiu rc=$RC18B — esperado 2: $OUT18B"
  overall_rc=1
else
  echo "OK [18b] — rc 2"
fi

echo "[18m] mutação: voltar a somar o disco ao conteúdo que entra faz [18] sair rc 2"
HOOK18M="$T18/prevent-secrets-leak.sh"
cp "$WS/template/$HOOK_REL" "$HOOK18M"
cp "$HOOK18M" "$T18/hook.orig.sh"
perl -0777 -pi -e 's/CHECK_CONTENT="\$CONTENT"\nif \[\[ "\$HAVE_CONTENT" -eq 0 \]\] && \[\[ -f "\$FILE" \]\]; then\n  CHECK_CONTENT=\$\(cat "\$FILE" 2>\/dev\/null \|\| true\)\nfi/TARGET_CONTENT=""\nif [[ -f "\$FILE" ]]; then TARGET_CONTENT=\$(cat "\$FILE" 2>\/dev\/null || true); fi\nCHECK_CONTENT="\${CONTENT}\${TARGET_CONTENT}" # MUTATED-18/' "$HOOK18M"
if cmp -s "$T18/hook.orig.sh" "$HOOK18M"; then
  echo "FAIL [18m]: setup da mutação não alterou o gancho — nada foi provado"
  overall_rc=1
else
  OUT18M="$(printf '%s' "$PAYLOAD18" | bash "$HOOK18M" 2>&1)"; RC18M=$?
  if [ "$RC18M" -ne 2 ]; then
    echo "FAIL [18m]: a mutação (soma incondicional do disco) não derrubou o cenário — saiu rc=$RC18M"
    overall_rc=1
  else
    echo "OK [18m] — mutante reprovado (rc=2 em vez de 0)"
  fi
  cp "$T18/hook.orig.sh" "$HOOK18M"
  if ! cmp -s "$T18/hook.orig.sh" "$HOOK18M"; then
    echo "FAIL [18m]: recontrole — restauração do gancho mutado não ficou byte-idêntica ao original"
    overall_rc=1
  else
    OUT18R="$(printf '%s' "$PAYLOAD18" | bash "$HOOK18M" 2>&1)"; RC18R=$?
    if [ "$RC18R" -ne 0 ]; then
      echo "FAIL [18m]: recontrole — gancho original restaurado não voltou a sair rc 0 (rc=$RC18R)"
      overall_rc=1
    else
      echo "OK [18m] recontrole — gancho original restaurado, rc 0"
    fi
  fi
fi

# ── [19] versão mista: prevent-secrets-leak.sh preservado via argv-bridge ──────────────────────────
echo "[19] versão mista: prevent-secrets-leak.sh fiado através de lib/argv-bridge.sh, payload COM segredo — rc 2"
BRIDGE_REL=".forge/hooks/pre-tool-use/lib/argv-bridge.sh"
PAYLOAD19="$(printf '{"tool_name":"Write","tool_input":{"file_path":"/tmp/mixedver.env","content":"aws_key = %s"}}' "${prefix}${suffix}")"
OUT19="$(printf '%s' "$PAYLOAD19" | bash "$WS/template/$BRIDGE_REL" "$WS/template/$HOOK_REL" 2>&1)"; RC19=$?
if [ "$RC19" -ne 2 ]; then
  echo "FAIL [19]: prevent-secrets-leak.sh através da ponte, com segredo, saiu rc=$RC19 — esperado 2: $OUT19"
  overall_rc=1
else
  echo "OK [19] — rc 2"
fi

echo "[19m] mutação: voltar a ponte a repassar só \$1 (sem conteúdo) faz [19] sair rc 0"
T19M="$(mktemp -d "$TMPROOT/forge-w215-19m.XXXXXX")"; track "$T19M"
BRIDGE19M="$T19M/argv-bridge.sh"
cp "$WS/template/$BRIDGE_REL" "$BRIDGE19M"
cp "$BRIDGE19M" "$T19M/bridge.orig.sh"
perl -pi -e 's/exec "\$TARGET" "\$FILE" "\$CONTENT" "\$@"/exec "\$TARGET" "\$FILE" "\$@" # MUTATED-19/' "$BRIDGE19M"
if cmp -s "$T19M/bridge.orig.sh" "$BRIDGE19M"; then
  echo "FAIL [19m]: setup da mutação não alterou a ponte — nada foi provado"
  overall_rc=1
else
  OUT19M="$(printf '%s' "$PAYLOAD19" | bash "$BRIDGE19M" "$WS/template/$HOOK_REL" 2>&1)"; RC19M=$?
  if [ "$RC19M" -eq 2 ]; then
    echo "FAIL [19m]: a mutação (ponte sem conteúdo) não derrubou o cenário — ainda saiu rc 2"
    overall_rc=1
  else
    echo "OK [19m] — mutante reprovado (rc=$RC19M em vez de 2)"
  fi
  cp "$T19M/bridge.orig.sh" "$BRIDGE19M"
  if ! cmp -s "$T19M/bridge.orig.sh" "$BRIDGE19M"; then
    echo "FAIL [19m]: recontrole — restauração da ponte mutada não ficou byte-idêntica ao original"
    overall_rc=1
  else
    OUT19R="$(printf '%s' "$PAYLOAD19" | bash "$BRIDGE19M" "$WS/template/$HOOK_REL" 2>&1)"; RC19R=$?
    if [ "$RC19R" -ne 2 ]; then
      echo "FAIL [19m]: recontrole — ponte original restaurada não voltou a sair rc 2 (rc=$RC19R)"
      overall_rc=1
    else
      echo "OK [19m] recontrole — ponte original restaurada, rc 2"
    fi
  fi
fi

# ── [20] semeador preserva o MATCHER que o consumidor já tinha ─────────────────────────────────────
echo "[20] semeador preserva o matcher legado (Edit|Write, sem NotebookEdit, não ancorado) em vez de alargar para o do produtor"
T20="$(mktemp -d "$TMPROOT/forge-w215-20.XXXXXX")"; track "$T20"
nova_fixture "$T20"
mkdir -p "$T20/.claude"
cat > "$T20/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh" } ] }
    ]
  }
}
JSON
bash "$T20/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
GOT20="$(matcher_of "$T20/.claude/settings.json" prevent-secrets-leak.sh)"
if [ "$GOT20" != "Edit|Write" ]; then
  echo "FAIL [20]: matcher depois do sync = '$GOT20' — esperado 'Edit|Write' preservado (não alargado para o matcher ancorado do produtor)"
  overall_rc=1
else
  echo "OK [20] — matcher preservado: '$GOT20'"
fi

echo "-- resumo funcional: overall_rc=$overall_rc"
exit "$overall_rc"
