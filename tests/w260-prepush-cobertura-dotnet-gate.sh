#!/usr/bin/env bash
# Gate W260 — issue #106: `run_check "test"` (pre-push) executa `runtime.test` como TEXTO LIVRE;
# nada confronta esse comando com as superfícies de build REAIS da árvore. Uma árvore com
# `.sln`/`.csproj` RASTREADO cujo `runtime.test` não menciona `dotnet` faz a suíte .NET nunca
# rodar, sem aviso nenhum — medido no axis-go-cloud (24 `.sln`, `test: pnpm test`,
# docs/plans/2026-09-15-plano-issues-abertas.md, seção "#106").
#
# Desenho: AVISO, nunca bloqueio, por padrão (DA-12) — bloquear reprovaria todo push de consumidor
# cujo `runtime.test` chama um SCRIPT que por sua vez chama `dotnet`; a heurística por comando não
# vê através de script. Reconhecimento restrito à stack .NET; outras stacks ficam para a Onda 8.
#
#   [1] positiva — `.sln` RASTREADO + `runtime.test: pnpm test` (sem "dotnet"): imprime o AVISO
#       nomeando a contagem e o comando, e o hook sai rc 0 (NUNCA bloqueia)
#   [2] contrafactual A — `.sln` RASTREADO + `runtime.test: dotnet test App.sln`: NÃO avisa
#   [3] contrafactual B — `.sln` presente na árvore mas NÃO RASTREADO (`.gitignore`): NÃO avisa,
#       mesmo com `runtime.test` sem "dotnet" — só a superfície que o consumidor VERSIONA conta
#   [4] mutação — remover a condição de "rastreado" (trocar `git ls-files` por uma contagem que
#       enxerga a árvore de trabalho inteira) faz o cenário [3] (não-rastreado) avisar
#       incorretamente; recontrole com a cópia pristina restaura o silêncio
#   [5] PBT (semente fixa, LCG próprio — Numerical Recipes, bits altos, nunca $RANDOM) — árvores
#       geradas (0 a 3 arquivos .sln/.csproj, rastreados ou não) × comandos gerados (com/sem
#       "dotnet" em posição aleatória): o AVISO aparece SE E SOMENTE SE há arquivo .NET RASTREADO
#       E o comando não contém "dotnet"
#   [6] SENTINELA — o gate examinou os cenários declarados (zero cenário executado reprova)
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo obedecerem
# ao repositório de quem invoca o gate, não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="$WS/template/.forge/hooks/git/pre-push"
DECLARADOS=6
EXAMINADOS=0
cen() { EXAMINADOS=$((EXAMINADOS + 1)); }

[ -f "$HOOK_SRC" ] || { echo "FAIL [0]: $HOOK_SRC não existe"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w260.XXXXXX")" || { echo "FAIL [0]: mktemp -d falhou"; exit 1; }
trap 'rm -rf "$T"' EXIT

# ── fixture ───────────────────────────────────────────────────────────────────────────────────
# Repositório mínimo, SEM `.forge/scripts/` nem `.forge/hooks/git/lib/`: cada sítio de delegação
# do pre-push degrada para no-op legítimo quando o diretório que o hospedaria não existe em
# nenhuma árvore (contrato de `resolve_delegated`, rc 2) — mesma técnica do w97/w252. Isso isola
# o que este gate mede: só o AVISO de cobertura .NET, sem simular a instalação inteira.
R="$T/repo"
mkdir -p "$R/.forge/hooks/git"
git -C "$R" init -q -b main
cp "$HOOK_SRC" "$R/.forge/hooks/git/pre-push"

FEED='refs/heads/main aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/main 0000000000000000000000000000000000000000'

write_test_cmd() {  # write_test_cmd <cmd> — grava runtime.test no FORGE.md da fixture
  cat > "$R/.forge/FORGE.md" <<EOF
runtime:
  typecheck:
  test: $1
EOF
}

track_sln() {  # track_sln <n> — cria e rastreia N arquivos .sln
  local i=1
  while [ "$i" -le "$1" ]; do
    echo "solution $i" > "$R/Fake$i.sln"
    git -C "$R" add "Fake$i.sln"
    i=$((i + 1))
  done
}

untrack_sln() {  # untrack_sln <n> — cria N arquivos .sln SEM rastrear (gitignore)
  local i=1
  while [ "$i" -le "$1" ]; do
    echo "solution $i" > "$R/Untracked$i.sln"
    i=$((i + 1))
  done
}

reset_fixture() {
  rm -f "$R"/*.sln "$R"/*.csproj
  # remove do índice qualquer .sln/.csproj rastreado de rodada anterior
  local tracked
  tracked="$(git -C "$R" ls-files -- '*.sln' '*.csproj' 2>/dev/null)"
  if [ -n "$tracked" ]; then
    (cd "$R" && echo "$tracked" | xargs -I{} git rm -q --cached {})
  fi
}

push_out() {  # push_out -> stdout+stderr combinados do hook
  (cd "$R" && printf '%s\n' "$FEED" | bash .forge/hooks/git/pre-push origin "file://$R" 2>&1)
}

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] positiva — .sln rastreado + runtime.test sem 'dotnet': AVISO nomeando contagem e comando, rc 0"
reset_fixture
track_sln 1
write_test_cmd "pnpm test"
out1="$(push_out)"; rc1=$?
[ "$rc1" -eq 0 ] || { echo "FAIL [1]: hook bloqueou (rc=$rc1) — o desenho é AVISO, nunca bloqueio. saída:"; echo "$out1"; exit 1; }
case "$out1" in
  *"pre-push: AVISO — 1 solution(s) .NET rastreada(s) e runtime.test ('pnpm test') não invoca dotnet; a suíte .NET não roda neste gate"*) : ;;
  *) echo "FAIL [1]: mensagem exata de AVISO ausente — saída:"; echo "$out1"; exit 1 ;;
esac
cen
echo "OK [1] — AVISO presente, rc=0"

# ── [2] ──────────────────────────────────────────────────────────────────────────────────────
echo "[2] contrafactual A — .sln rastreado + runtime.test com 'dotnet': NÃO avisa"
reset_fixture
track_sln 1
write_test_cmd "echo run-dotnet-suite"
out2="$(push_out)"; rc2=$?
[ "$rc2" -eq 0 ] || { echo "FAIL [2]: hook bloqueou (rc=$rc2) — saída:"; echo "$out2"; exit 1; }
case "$out2" in *"AVISO"*) echo "FAIL [2]: AVISO não deveria aparecer — saída:"; echo "$out2"; exit 1 ;; esac
cen
echo "OK [2] — sem AVISO"

# ── [3] ──────────────────────────────────────────────────────────────────────────────────────
echo "[3] contrafactual B — .sln presente mas NÃO rastreado: NÃO avisa, mesmo sem 'dotnet' no comando"
reset_fixture
untrack_sln 1
write_test_cmd "pnpm test"
out3="$(push_out)"; rc3=$?
[ "$rc3" -eq 0 ] || { echo "FAIL [3]: hook bloqueou (rc=$rc3) — saída:"; echo "$out3"; exit 1; }
case "$out3" in *"AVISO"*) echo "FAIL [3]: AVISO não deveria aparecer para .sln não-rastreado — saída:"; echo "$out3"; exit 1 ;; esac
cen
echo "OK [3] — sem AVISO (arquivo não rastreado)"

# ── [4] ──────────────────────────────────────────────────────────────────────────────────────
echo "[4] mutação — trocar 'git ls-files' por contagem da árvore de trabalho inteira faz [3] avisar; recontrole restaura o silêncio"
cp "$R/.forge/hooks/git/pre-push" "$T/hook.pristino"
# Muta a fonte da contagem: de 'git ls-files' (rastreado) para 'find' (árvore inteira, ignora
# a condição de rastreamento) — reproduz exatamente a classe de regressão que a mutação declarada
# no plano descreve ("remover a condição de rastreado").
perl -pi -e "s/git -C \"\\\$ROOT\" ls-files -- '\\*\\.sln' '\\*\\.csproj'/find \"\\\$ROOT\" -name '*.sln' -o -name '*.csproj'/" "$R/.forge/hooks/git/pre-push"
if cmp -s "$R/.forge/hooks/git/pre-push" "$T/hook.pristino"; then
  echo "FAIL [4]: mutação não alterou o hook — o padrão de busca não casou (drift entre este gate e o fonte)"; exit 1
fi
bash -n "$R/.forge/hooks/git/pre-push" || { echo "FAIL [4]: mutante não é bash sintaticamente válido"; cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"; exit 1; }

reset_fixture
untrack_sln 1
write_test_cmd "pnpm test"
outm="$(push_out)"; rcm=$?
if ! case "$outm" in *"AVISO"*) true ;; *) false ;; esac; then
  echo "FAIL [4]: mutante deveria avisar incorretamente para .sln não-rastreado, e não avisou — saída:"
  echo "$outm"
  cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"
  exit 1
fi

# recontrole: cópia pristina de volta, mesmo cenário — o silêncio tem de voltar
cp "$T/hook.pristino" "$R/.forge/hooks/git/pre-push"
reset_fixture
untrack_sln 1
write_test_cmd "pnpm test"
outr="$(push_out)"; rcr=$?
[ "$rcr" -eq 0 ] || { echo "FAIL [4]: recontrole bloqueou (rc=$rcr) — saída:"; echo "$outr"; exit 1; }
case "$outr" in *"AVISO"*) echo "FAIL [4]: recontrole não restaurou o silêncio — saída:"; echo "$outr"; exit 1 ;; esac
cen
echo "OK [4] — mutante avisa incorretamente; recontrole restaura o silêncio"

# ── [5] ──────────────────────────────────────────────────────────────────────────────────────
echo "[5] PBT — árvores × comandos gerados (semente fixa, LCG próprio): AVISO sse .NET rastreado E comando sem 'dotnet'"
# LCG PRÓPRIO (Numerical Recipes: a=1103515245, c=12345, m=2^31), nunca \$RANDOM — mesma nota do
# w224/w252: \$RANDOM muda de gerador entre versões do bash, o que torna a "semente fixa"
# reprodutível só na máquina que a mediu. Sorteio pelos BITS ALTOS (`>> 16`).
LCG_A=1103515245
LCG_C=12345
LCG_M=2147483648
_lcg_state=106106
lcg_next() { _lcg_state=$(( (LCG_A * _lcg_state + LCG_C) % LCG_M )); }
lcg_draw() { lcg_next; _lcg_draw=$(( (_lcg_state >> 16) % $1 )); }  # [0, k)

NCASOS=8
i=0
vistos_avisa=0
vistos_nao_avisa=0
while [ "$i" -lt "$NCASOS" ]; do
  lcg_draw 4; n_rastreado=$_lcg_draw          # 0..3 arquivos .sln/.csproj RASTREADOS
  lcg_draw 4; n_nao_rastreado=$_lcg_draw      # 0..3 arquivos .sln/.csproj NÃO rastreados
  lcg_draw 2; tem_dotnet=$_lcg_draw           # 0 ou 1

  reset_fixture
  track_sln "$n_rastreado"
  untrack_sln "$n_nao_rastreado"
  if [ "$tem_dotnet" -eq 1 ]; then
    # "dotnet" em posição aleatória DENTRO do comando, mas o comando em si nunca invoca o binário
    # dotnet de verdade — este gate mede a heurística de substring do hook, não o resultado real
    # de uma build .NET (que dependeria de toolchain instalada na máquina que roda o gate).
    lcg_draw 3
    case "$_lcg_draw" in
      0) cmd="echo dotnet-test-wrapper" ;;
      1) cmd="echo run-dotnet-suite" ;;
      *) cmd="echo build-then-dotnet" ;;
    esac
  else
    cmd="pnpm test"
  fi
  write_test_cmd "$cmd"
  outp="$(push_out)"; rcp=$?
  [ "$rcp" -eq 0 ] || { echo "FAIL [5]: caso $i bloqueou (rc=$rcp) — n_rastreado=$n_rastreado cmd='$cmd'. saída:"; echo "$outp"; exit 1; }

  esperado_avisa=0
  [ "$n_rastreado" -gt 0 ] && [ "$tem_dotnet" -eq 0 ] && esperado_avisa=1

  observado_avisa=0
  case "$outp" in *"AVISO"*) observado_avisa=1 ;; esac

  if [ "$esperado_avisa" -eq 1 ]; then vistos_avisa=$((vistos_avisa + 1)); else vistos_nao_avisa=$((vistos_nao_avisa + 1)); fi

  [ "$observado_avisa" -eq "$esperado_avisa" ] || {
    echo "FAIL [5]: caso $i — n_rastreado=$n_rastreado n_nao_rastreado=$n_nao_rastreado cmd='$cmd' esperado_avisa=$esperado_avisa observado_avisa=$observado_avisa"
    echo "$outp"
    exit 1
  }
  i=$((i + 1))
done
[ "$vistos_avisa" -ge 1 ] && [ "$vistos_nao_avisa" -ge 1 ] \
  || { echo "FAIL [5]: PBT não cobriu as duas direções (avisa: $vistos_avisa, não-avisa: $vistos_nao_avisa)"; exit 1; }
cen
echo "OK [5] — $NCASOS casos (avisa: $vistos_avisa, não-avisa: $vistos_nao_avisa)"

# ── [6] ──────────────────────────────────────────────────────────────────────────────────────
cen
echo "[6] SENTINELA — $EXAMINADOS/$DECLARADOS cenários examinados"
[ "$EXAMINADOS" -eq "$DECLARADOS" ] || { echo "FAIL [6]: $EXAMINADOS/$DECLARADOS cenários examinados — universo vazio não é ausência de defeito"; exit 1; }
echo "OK [6]"

echo "PASS w260-prepush-cobertura-dotnet-gate"
