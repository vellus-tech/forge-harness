#!/usr/bin/env bash
# Gate W227 — a isenção .NET de validate-naming-conventions.sh alcança caminho relativo (#129).
#
# POR QUE ESTE GATE EXISTE. `hooks/pre-tool-use/validate-naming-conventions.sh` reprovava TODO
# arquivo `.cs` sob `src/`/`tests/`/`services/`/`deploy/` quando o caminho chegava RELATIVO —
# exatamente a forma que `git diff --cached --name-only` entrega, e a forma que um invocador de
# pre-commit de consumidor (por exemplo `pre-commit.d/04-language-and-naming.sh` do axis-go-cloud)
# usa. A regra 2 do hook testava `$DIR =~ /(src|tests|services|deploy)(/|$)` — a alternativa exige
# uma barra ANTES do segmento, então nunca casa um caminho que COMEÇA pelo segmento isento; o
# `elif` seguinte reprova o diretório como fora de kebab-case. Medido contra a base (60 arquivos
# `.cs` rastreados sob `src/`/`tests/`, mesmo conjunto nas duas formas): 60/60 reprovados na forma
# relativa, 0/60 na forma absoluta — a assinatura de um predicado quebrado, não de uma propriedade
# medida. O gate nasceu como `PreToolUse`, onde o Claude Code entrega `tool_input.file_path`
# absoluto (a ponte `lib/argv-bridge.sh` da #125 extrai esse campo do payload) e a isenção
# funcionava; ao ser reusado por invocação direta com caminho relativo, a isenção calava.
#
# DESENHO DA CORREÇÃO: ancorar nas duas pontas, `(^|/)(src|tests|services|deploy)(/|$)` — `(^|/)`
# cobre o caminho relativo que COMEÇA no segmento e preserva o caso absoluto e o aninhado
# (`services/token-vault/src/...`), sem alargar a isenção para um nome que apenas CONTÉM o
# segmento (`mysrc/`, `srcx/` continuam reprovando, porque não há `/` nem início-de-string
# imediatamente antes/depois de `src` nesses nomes).
#
#   [1] positivo — caminho relativo com o segmento isento na RAIZ do caminho (o caso exato da
#       reprodução da issue, `src/Axis.T.Infrastructure/Communications/X.cs`) sai rc 0.
#   [2] controle — o MESMO caminho, em forma absoluta, continua rc 0 (nunca regride o caso que já
#       funcionava).
#   [3] contrafactual — prefixo COLADO (`mysrc/Communications/X.cs`, sem `/` nem início-de-string
#       antes de `src`) continua reprovando, rc 1 — a isenção não pode alargar para um nome que só
#       CONTÉM o segmento.
#   [4] contrafactual — sufixo COLADO (`srcx/Communications/X.cs`) continua reprovando, rc 1, pela
#       mesma razão do [3] do lado oposto.
#   [5] positivo — `tests/` relativo (a outra metade da isenção .NET) também sai rc 0.
#   [6] controle — segmento isento ANINHADO em profundidade (`services/token-vault/src/...`, o
#       caso que já passava mesmo antes da correção, porque tem `/` interno) continua rc 0.
#   [7] PBT — 60 casos gerados (semente 20260926, LCG determinístico, sem depender de `RANDOM` do
#       bash) cobrindo: segmento isento em profundidade aleatória (0-2 diretórios PascalCase
#       antes, 0-2 depois), com e sem prefixo absoluto sintético. Propriedade dupla: (a) prefixo
#       absoluto sem segmento isento não muda o veredito; (b) uma
#       variante com o segmento COLADO (prefixo `my` ou sufixo `x`) e ao menos um diretório
#       PascalCase real na árvore NUNCA isenta (rc 1) — a isenção nunca alarga para alcançar um
#       nome que apenas contém o segmento.
#   [8] mutação — reverter a âncora para a forma antiga (`/(src|tests|services|deploy)(/|$)`, sem
#       `(^|/)`) faz [1] voltar a reprovar (rc 1) — o defeito original. Mutação sobre uma CÓPIA
#       isolada em `$T`, nunca o arquivo rastreado em `template/.forge/` (LDG-0175/w213);
#       controle e recontrole por `cmp -s` contra a cópia salva antes da mutação, restaurada byte
#       a byte ao final.
#   [9] integração — invocado através da ponte real da #125 (`lib/argv-bridge.sh`, o MESMO
#       caminho que `hookCommandBridge`/`hookCommandBridgeLegacy` de `sync-adapters.mjs` emitem
#       para um gancho de contrato `argv` como este — as duas formas só diferem em aspas ao redor
#       de `$CLAUDE_PROJECT_DIR` no comando textual de `settings.json`, e as duas invocam o MESMO
#       `argv-bridge.sh`) com um payload `PreToolUse` sintético carregando `tool_input.file_path`
#       RELATIVO: a ponte extrai o campo do stdin e invoca o gancho com `$1=<caminho>`, sem
#       absolutizar nada — sai rc 0 para o segmento isento, provando que a correção também vale
#       quando o caminho chega pela ponte, não só por chamada direta.
#   [10] contrafactual pela ponte — o mesmo payload com `mysrc/...` continua reprovando (rc 1)
#        através da ponte, fechando o par positivo/contrafactual nos dois caminhos de invocação
#        que este gancho recebe hoje (direto e via ponte).
#
# Propriedade PBT: coberta em [7]. Não há propriedade adicional fora desse espaço (a entrada do
# hook é só o caminho do arquivo; conteúdo e extensão não participam da regra 2).
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$WS/template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh"
BRIDGE="$WS/template/.forge/hooks/pre-tool-use/lib/argv-bridge.sh"
[ -f "$HOOK" ] || { echo "FAIL: gancho ausente em $HOOK"; exit 2; }
[ -f "$BRIDGE" ] || { echo "FAIL: ponte ausente em $BRIDGE"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/w227.XXXXXX")"
trap 'rm -rf "$T"' EXIT

overall_rc=0

# ── [1] positivo — relativo, caso exato da issue ────────────────────────────────────────────
echo "[1] relativo — src/Axis.T.Infrastructure/Communications/X.cs (reprodução exata da issue)"
out1="$(bash "$HOOK" "src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs" 2>&1)"; rc1=$?
if [ "$rc1" -ne 0 ]; then
  echo "FAIL [1]: caminho relativo sob src/ reprovado (rc=$rc1) — a isenção .NET não alcançou. Saída: $out1"
  overall_rc=1
else
  echo "OK [1] — rc 0"
fi

# ── [2] controle — o mesmo caminho, absoluto ────────────────────────────────────────────────
echo "[2] controle — o MESMO arquivo em forma absoluta continua rc 0"
out2="$(bash "$HOOK" "/Users/x/repo/src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs" 2>&1)"; rc2=$?
if [ "$rc2" -ne 0 ]; then
  echo "FAIL [2]: caminho absoluto regrediu (rc=$rc2). Saída: $out2"
  overall_rc=1
else
  echo "OK [2] — rc 0"
fi

# ── [3] contrafactual — prefixo colado ───────────────────────────────────────────────────────
echo "[3] contrafactual — mysrc/Communications/X.cs continua reprovando"
out3="$(bash "$HOOK" "mysrc/Communications/BanklyCommunication.cs" 2>&1)"; rc3=$?
if [ "$rc3" -eq 0 ]; then
  echo "FAIL [3]: 'mysrc/...' foi isento (rc=0) — a âncora alargou demais. Saída: $out3"
  overall_rc=1
else
  echo "OK [3] — rc $rc3 (reprovado, como esperado)"
fi

# ── [4] contrafactual — sufixo colado ────────────────────────────────────────────────────────
echo "[4] contrafactual — srcx/Communications/X.cs continua reprovando"
out4="$(bash "$HOOK" "srcx/Communications/BanklyCommunication.cs" 2>&1)"; rc4=$?
if [ "$rc4" -eq 0 ]; then
  echo "FAIL [4]: 'srcx/...' foi isento (rc=0) — a âncora alargou demais. Saída: $out4"
  overall_rc=1
else
  echo "OK [4] — rc $rc4 (reprovado, como esperado)"
fi

# ── [5] positivo — tests/ relativo ───────────────────────────────────────────────────────────
echo "[5] relativo — tests/Axis.Transaction.Tests.Unit/Adapters/A.cs"
out5="$(bash "$HOOK" "tests/Axis.Transaction.Tests.Unit/Adapters/A.cs" 2>&1)"; rc5=$?
if [ "$rc5" -ne 0 ]; then
  echo "FAIL [5]: 'tests/...' relativo reprovado (rc=$rc5). Saída: $out5"
  overall_rc=1
else
  echo "OK [5] — rc 0"
fi

# ── [6] controle — segmento aninhado (já funcionava) ─────────────────────────────────────────
echo "[6] controle — services/token-vault/src/TokenVault.Api/Endpoints/A.cs (aninhado)"
out6="$(bash "$HOOK" "services/token-vault/src/TokenVault.Api/Endpoints/A.cs" 2>&1)"; rc6=$?
if [ "$rc6" -ne 0 ]; then
  echo "FAIL [6]: segmento aninhado regrediu (rc=$rc6). Saída: $out6"
  overall_rc=1
else
  echo "OK [6] — rc 0"
fi

# ── [7] PBT — 60 casos gerados (semente 20260926) ───────────────────────────────────────────
echo "[7] PBT — 60 casos gerados (semente 20260926): prefixo absoluto não muda veredito; segmento colado nunca isenta"
SEED=20260926
N_TRIALS=60
CASES="$(node -e '
let s = Number(process.argv[1]);
const n = Number(process.argv[2]);
function next() { s = (s * 1103515245 + 12345) & 0x7fffffff; return s; }
const SEGMENTS = ["src", "tests", "services", "deploy"];
const WORDS = ["Communications", "Adapters", "Endpoints", "Infrastructure", "Models", "Handlers", "Services", "Repositories"];
const lines = [];
for (let t = 0; t < n; t++) {
  const seg = SEGMENTS[next() % SEGMENTS.length];
  const gluedKind = next() % 3; // 0=limpo, 1=prefixo colado (my<seg>), 2=sufixo colado (<seg>x)
  const depthBefore = gluedKind === 0 ? (next() % 3) : 0; // colado só faz sentido como 1o segmento
  const depthAfter = gluedKind === 0 ? (next() % 3) : (1 + (next() % 2)); // colado exige basename PascalCase
  const before = [];
  for (let i = 0; i < depthBefore; i++) before.push(WORDS[next() % WORDS.length]);
  const after = [];
  for (let i = 0; i < depthAfter; i++) after.push(WORDS[next() % WORDS.length]);
  const segToken = gluedKind === 1 ? ("my" + seg) : gluedKind === 2 ? (seg + "x") : seg;
  const fname = "File" + next() + ".cs";
  const parts = [...before, segToken, ...after, fname];
  lines.push([gluedKind, parts.join("/")].join("\t"));
}
process.stdout.write(lines.join("\n"));
' "$SEED" "$N_TRIALS")"

trial_no=0
fail7=0
while IFS=$'\t' read -r glued_kind relsuffix; do
  [ -n "${relsuffix:-}" ] || continue
  trial_no=$((trial_no + 1))
  relpath="$relsuffix"
  abspath="/Users/tester/repo/$relsuffix"
  out_rel="$(bash "$HOOK" "$relpath" 2>&1)"; rc_rel=$?
  out_abs="$(bash "$HOOK" "$abspath" 2>&1)"; rc_abs=$?
  if [ "$glued_kind" -eq 0 ]; then
    # segmento limpo: isento nos dois, e os dois vereditos batem
    if [ "$rc_rel" -ne "$rc_abs" ]; then
      echo "FAIL [7]: trial $trial_no ($relpath) — veredito diverge entre relativo (rc=$rc_rel) e absoluto (rc=$rc_abs)"
      fail7=1; break
    fi
    if [ "$rc_rel" -ne 0 ]; then
      echo "FAIL [7]: trial $trial_no ($relpath) — segmento isento reprovado (rc=$rc_rel). Saída: $out_rel"
      fail7=1; break
    fi
  else
    # segmento colado: nunca isenta, nos dois lados
    if [ "$rc_rel" -eq 0 ]; then
      echo "FAIL [7]: trial $trial_no ($relpath) — segmento colado (kind=$glued_kind) isento por engano (relativo)"
      fail7=1; break
    fi
    if [ "$rc_abs" -eq 0 ]; then
      echo "FAIL [7]: trial $trial_no ($abspath) — segmento colado (kind=$glued_kind) isento por engano (absoluto)"
      fail7=1; break
    fi
  fi
done <<<"$CASES"

if [ "$fail7" -ne 0 ]; then
  overall_rc=1
else
  n_trials="$(printf '%s\n' "$CASES" | grep -c .)"
  if [ "${n_trials:-0}" -lt 50 ]; then
    echo "FAIL [7]: só ${n_trials:-0} trial(s) executado(s) — a PBT exige ao menos 50 casos"
    overall_rc=1
  else
    echo "OK [7] ($n_trials trials, semente $SEED)"
  fi
fi

# ── [8] mutação — reverter a âncora restaura o defeito original ─────────────────────────────
echo "[8] mutação — reverter (^|/) para / restaura o defeito; controle e recontrole por cmp -s"
MUT="$T/validate-naming-conventions.sh"
cp "$HOOK" "$MUT"
cp "$HOOK" "$T/orig.sh"
# pré-condição: a cópia intocada continua rc 0 no caso [1]
out8pre="$(bash "$MUT" "src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs" 2>&1)"; rc8pre=$?
if [ "$rc8pre" -ne 0 ]; then
  echo "FAIL [8]: pré-condição — a cópia intocada já reprova antes da mutação (rc=$rc8pre)"
  overall_rc=1
else
  # mutação: aspas simples do lado direito, nunca $ interpolado
  perl -pi -e 's{\(\^\|/\)\(src\|tests\|services\|deploy\)\(/\|\$\)}{/(src|tests|services|deploy)(/|\$)}' "$MUT"
  if cmp -s "$MUT" "$T/orig.sh"; then
    echo "FAIL [8]: a mutação não alterou o arquivo — o ponto de mutação mudou de nome/forma"
    overall_rc=1
  else
    out8mut="$(bash "$MUT" "src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs" 2>&1)"; rc8mut=$?
    if [ "$rc8mut" -eq 0 ]; then
      echo "FAIL [8]: com a âncora revertida, o caso [1] continuou rc 0 — a mutação não reintroduziu o defeito (mutante sobrevivente)"
      overall_rc=1
    else
      echo "OK [8a] — mutante morto: rc=$rc8mut com a âncora revertida"
    fi
    # restauração byte a byte
    cp "$T/orig.sh" "$MUT"
    if ! cmp -s "$MUT" "$T/orig.sh"; then
      echo "FAIL [8]: restauração não bateu byte a byte (cmp)"
      overall_rc=1
    else
      out8rec="$(bash "$MUT" "src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs" 2>&1)"; rc8rec=$?
      if [ "$rc8rec" -ne 0 ]; then
        echo "FAIL [8]: recontrole — depois de restaurada, a cópia voltou a reprovar (rc=$rc8rec)"
        overall_rc=1
      else
        echo "OK [8b] — recontrole: rc 0 depois da restauração byte a byte"
      fi
    fi
  fi
fi

# ── [9] integração — através da ponte da #125 (lib/argv-bridge.sh), relativo ────────────────
echo "[9] integração — via argv-bridge.sh (mesma ponte que hookCommandBridge/hookCommandBridgeLegacy emitem), tool_input.file_path relativo"
json9="$(printf '{"tool_input": {"file_path": "src/Axis.Transaction.Infrastructure/Communications/BanklyCommunication.cs"}}')"
out9="$(printf '%s' "$json9" | "$BRIDGE" "$HOOK" 2>&1)"; rc9=$?
if [ "$rc9" -ne 0 ]; then
  echo "FAIL [9]: via ponte, caminho relativo sob src/ reprovado (rc=$rc9). Saída: $out9"
  overall_rc=1
else
  echo "OK [9] — rc 0 pela ponte"
fi

# ── [10] contrafactual pela ponte ────────────────────────────────────────────────────────────
echo "[10] contrafactual pela ponte — mysrc/... continua reprovando"
json10="$(printf '{"tool_input": {"file_path": "mysrc/Communications/BanklyCommunication.cs"}}')"
out10="$(printf '%s' "$json10" | "$BRIDGE" "$HOOK" 2>&1)"; rc10=$?
if [ "$rc10" -eq 0 ]; then
  echo "FAIL [10]: via ponte, 'mysrc/...' foi isento (rc=0). Saída: $out10"
  overall_rc=1
else
  echo "OK [10] — rc $rc10 pela ponte (reprovado, como esperado)"
fi

exit "$overall_rc"
