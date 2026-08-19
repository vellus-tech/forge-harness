#!/usr/bin/env bash
# Gate W137 — maquinaria versionada dentro da árvore não se propaga sozinha para worktrees.
#
# Um gate, um script ou uma rule corrigidos no tronco continuam sendo a versão antiga em todo
# worktree ativo, e quem trabalha ali recebe verde de um gate que não está rodando. Medido em
# axis-go-cloud: cinco dos oito worktrees ativos com 86 a 103 arquivos divergentes de develop em
# .forge/{scripts,rules,schemas,templates}. Três instâncias do mesmo defeito, todas no template:
#
#   [1] ledger-ops.sh resolve ROOT por --show-toplevel: dentro de um worktree isso devolve o
#       PRÓPRIO worktree, e o registro nasce no ledger.json da branch em vez do tronco — cada
#       branch que toca o ledger colide por construção no merge.
#   [2] core.hooksPath gravado RELATIVO: ele vive no .git/config comum, compartilhado por todos
#       os worktrees, e um valor relativo é resolvido por cada worktree na própria árvore — que
#       carrega a cópia antiga dos hooks. Hook novo, mergeado, não bloqueia nada ali.
#   [3] paridade: installer/install.sh grava o mesmo valor que bin/forge.mjs.
#   [4] o doctor precisa ACUSAR um hooksPath que aponta para fora do tronco — config local não é
#       versionada, então reaparece a cada clone e a cada máquina.
#   [5] `forge update` rodado de dentro de um worktree escreve a maquinaria nova NAQUELA branch e
#       deixa o resto do repositório sem nada: tem de recusar, não de obedecer.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$WS/bin/forge.mjs"
T="$(mktemp -d /tmp/forge-w137.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# Repositório instalado + um worktree linkado, o cenário que todos os casos compartilham.
# pwd -P: no macOS /tmp é symlink para /private/tmp, e o git devolve o caminho REAL em
# --path-format=absolute. Comparar contra o caminho lógico faria a asserção falhar por um motivo
# que nada tem a ver com o defeito sob teste.
MAIN="$T/main"
mkdir -p "$MAIN"
MAIN="$(cd "$MAIN" && pwd -P)"
git -C "$MAIN" init -q -b main
node "$BIN" init --target "$MAIN" --slug w137 --name W137 --desc t --yes --no-plugin >/dev/null 2>&1 \
  || { echo "FAIL [0]: forge init falhou no fixture"; exit 1; }
git -C "$MAIN" -c user.email=w137@t -c user.name=w137 add -A >/dev/null 2>&1
git -C "$MAIN" -c user.email=w137@t -c user.name=w137 commit -q -m "harness instalado"
WT="$MAIN/.forge/worktrees/wt1"
git -C "$MAIN" worktree add -q -b feature/x "$WT" 2>/dev/null \
  || { echo "FAIL [0]: não consegui criar o worktree do fixture"; exit 1; }
[ -d "$WT/.forge" ] || { echo "FAIL [0]: worktree sem .forge — fixture inválido"; exit 1; }

echo "[1] ledger-ops.sh rodado de dentro do worktree escreve no ledger do TRONCO"
# Sem FORGE_ROOT: é justamente a resolução automática que está sob teste.
(cd "$WT" && bash "$WT/.forge/scripts/ledger-ops.sh" add --type known-bug --title "item-do-worktree" \
   --detail "registrado de dentro de um worktree" --priority P3) >/dev/null 2>&1 \
  || { echo "FAIL [1]: ledger-ops.sh add falhou dentro do worktree"; exit 1; }
if ! grep -q "item-do-worktree" "$MAIN/.forge/ledger/ledger.json" 2>/dev/null; then
  echo "FAIL [1]: o item nasceu no ledger da branch, não no do tronco — cada branch colide no merge"
  echo "  tronco:   $(grep -c 'item-do-worktree' "$MAIN/.forge/ledger/ledger.json" 2>/dev/null || echo 0) ocorrência(s)"
  echo "  worktree: $(grep -c 'item-do-worktree' "$WT/.forge/ledger/ledger.json" 2>/dev/null || echo 0) ocorrência(s)"
  exit 1
fi
# E o mesmo `status` tem de ler igual dos dois lugares.
s_main="$( (cd "$MAIN" && bash "$MAIN/.forge/scripts/ledger-ops.sh" status) 2>/dev/null)"
s_wt="$(   (cd "$WT"   && bash "$WT/.forge/scripts/ledger-ops.sh"   status) 2>/dev/null)"
[ -n "$s_main" ] || { echo "FAIL [1]: ledger status vazio no tronco — asserção seria vácua"; exit 1; }
if [ "$s_main" != "$s_wt" ]; then
  echo "FAIL [1]: ledger status difere entre tronco e worktree"
  echo "  tronco:   $s_main"
  echo "  worktree: $s_wt"
  exit 1
fi
echo "OK [1]"

echo "[2] core.hooksPath é absoluto e aponta para os hooks do tronco"
hp="$(git -C "$MAIN" config --get core.hooksPath || true)"
[ -n "$hp" ] || { echo "FAIL [2]: core.hooksPath não foi gravado"; exit 1; }
case "$hp" in
  /*) : ;;
  *)  echo "FAIL [2]: core.hooksPath relativo ('$hp') — cada worktree resolve na PRÓPRIA árvore, que tem a cópia antiga dos hooks"; exit 1 ;;
esac
[ "$hp" = "$MAIN/.forge/hooks/git" ] || { echo "FAIL [2]: hooksPath '$hp' não aponta para os hooks do tronco ($MAIN/.forge/hooks/git)"; exit 1; }
# A prova que importa: um hook corrigido SÓ no tronco tem de valer dentro do worktree.
marker="MARCA-DO-TRONCO-$$"
printf '#!/usr/bin/env bash\necho "%s"\nexit 1\n' "$marker" > "$MAIN/.forge/hooks/git/pre-commit"
chmod +x "$MAIN/.forge/hooks/git/pre-commit"
echo "x" > "$WT/arquivo.txt"
git -C "$WT" add arquivo.txt >/dev/null 2>&1
out2="$(git -C "$WT" -c user.email=w137@t -c user.name=w137 commit -m "tenta" 2>&1)"; rc2=$?
if [ "$rc2" -eq 0 ]; then
  echo "FAIL [2]: o commit no worktree passou — o hook do tronco não foi executado ali"
  echo "$out2"; exit 1
fi
case "$out2" in
  *"$marker"*) : ;;
  *) echo "FAIL [2]: o worktree rodou OUTRO hook, não o do tronco"; echo "$out2"; exit 1 ;;
esac
git -C "$WT" reset -q HEAD arquivo.txt 2>/dev/null; rm -f "$WT/arquivo.txt"
echo "OK [2]"

echo "[3] paridade: installer/install.sh grava o mesmo hooksPath absoluto"
D3="$T/sh"; mkdir -p "$D3"; git -C "$D3" init -q -b main
bash "$WS/installer/install.sh" --target "$D3" --slug w137b --name W137B --desc t >/dev/null 2>&1 \
  || { echo "FAIL [3]: install.sh falhou no fixture"; exit 1; }
hp3="$(git -C "$D3" config --get core.hooksPath || true)"
[ -n "$hp3" ] || { echo "FAIL [3]: install.sh não gravou core.hooksPath"; exit 1; }
case "$hp3" in
  /*) : ;;
  *)  echo "FAIL [3]: install.sh gravou hooksPath relativo ('$hp3') — divergiu de bin/forge.mjs"; exit 1 ;;
esac
echo "OK [3]"

echo "[4] doctor acusa hooksPath que aponta para fora do tronco"
git -C "$MAIN" config core.hooksPath "$T/hooks-que-nao-existem"
out4="$( (cd "$MAIN" && FORGE_ROOT="$MAIN" bash "$MAIN/.forge/scripts/doctor.sh") 2>&1 )"
case "$out4" in
  *hooksPath*|*hooks*) : ;;
  *) echo "FAIL [4]: o doctor não mencionou hooksPath com o valor apontando para lugar nenhum"; echo "$out4"; exit 1 ;;
esac
if ! printf '%s' "$out4" | grep -q '✗.*[Hh]ook'; then
  echo "FAIL [4]: o doctor não REPROVOU o hooksPath quebrado — diagnóstico que não acusa não é diagnóstico"
  echo "$out4"; exit 1
fi
git -C "$MAIN" config core.hooksPath "$MAIN/.forge/hooks/git"
echo "OK [4]"

echo "[5] forge update recusa rodar de dentro de um worktree linkado"
out5="$(node "$BIN" update --target "$WT" --no-plugin 2>&1)"; rc5=$?
if [ "$rc5" -eq 0 ]; then
  echo "FAIL [5]: update aceitou rodar no worktree — a maquinaria nova nasce só naquela branch e o resto do repositório fica sem nada"
  echo "$out5"; exit 1
fi
case "$out5" in
  *worktree*) : ;;
  *) echo "FAIL [5]: update recusou, mas a mensagem não diz que o problema é o worktree"; echo "$out5"; exit 1 ;;
esac
echo "OK [5]"

echo "PASS w137-worktree-machinery-gate"
