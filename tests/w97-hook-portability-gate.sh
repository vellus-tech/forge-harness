#!/usr/bin/env bash
# Gate W-hook-portability — os hooks git rodam na máquina do desenvolvedor (macOS/BSD e Linux/GNU),
# não num runner controlado. Um `mktemp` com template inválido para BSD bloqueia TODO `git push`
# local (incidente real: `mktemp /tmp/forge-prepush-XXXXXX.log` — no BSD o template precisa TERMINAR
# nos X; qualquer sufixo depois do X faz o mktemp falhar e o hook aborta o push).
#   [1] nenhum `mktemp` nos hooks tem caractere após a sequência de X (footgun BSD)
#   [2] o pre-push é sintaticamente válido (bash -n) — o gate de docs não pode ter regressão de shell
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks"

echo "[1] mktemp portável (template termina nos X) em todos os hooks"
# procura `mktemp ... XXXX<algo>` onde <algo> não é X nem fim-de-token (aspas/espaço/paren/fim de linha)
if grep -rn 'mktemp' "$HOOKS" 2>/dev/null | grep -E 'X{3,}[^X[:space:]"'"'"')]'; then
  echo "FAIL [1] (mktemp com sufixo após os X — quebra no BSD/macOS; mova a extensão ou remova-a)"
  exit 1
fi
echo "OK [1] (nenhum mktemp com sufixo após os X)"

echo "[2] pre-push é shell válido"
bash -n "$HOOKS/git/pre-push" || { echo "FAIL [2] (pre-push com erro de sintaxe)"; exit 1; }
echo "OK [2] (bash -n limpo)"

echo "[3] pre-push degrada gate JS sem node_modules (issue #20) e roda quando presente"
# Repo git mínimo com FORGE.md declarando um typecheck pnpm — sem node_modules o gate deve
# ser PULADO (avisa, exit 0), não bloquear o push; com node_modules presente, deve rodar.
TP="$(mktemp -d /tmp/forge-w97.XXXXXX)"
trap 'rm -rf "$TP"' EXIT
git -C "$TP" init -q -b main
mkdir -p "$TP/.forge/hooks/git"
cp "$HOOKS/git/pre-push" "$TP/.forge/hooks/git/pre-push"
cat > "$TP/.forge/FORGE.md" <<'EOF'
runtime:
  typecheck: pnpm typecheck
  test:
EOF
FEED='refs/heads/main 0000000000000000000000000000000000000000 refs/heads/main 0000000000000000000000000000000000000000'
# sem node_modules → skip com aviso, exit 0
set +e
out="$(cd "$TP" && printf '%s\n' "$FEED" | bash .forge/hooks/git/pre-push origin file://"$TP" 2>&1)"; rc=$?
set -e
[ "$rc" -eq 0 ] || { echo "FAIL [3] (pre-push bloqueou sem node_modules — rc=$rc)"; echo "$out"; exit 1; }
echo "$out" | grep -q 'typecheck PULADO' || { echo "FAIL [3] (esperava aviso de skip)"; echo "$out"; exit 1; }
# com node_modules presente → o gate roda de fato (pnpm ausente no PATH => falha do comando, rc!=0)
mkdir -p "$TP/node_modules"
set +e
out2="$(cd "$TP" && printf '%s\n' "$FEED" | bash .forge/hooks/git/pre-push origin file://"$TP" 2>&1)"; rc2=$?
set -e
echo "$out2" | grep -q 'typecheck PULADO' && { echo "FAIL [3] (não deveria pular com node_modules presente)"; echo "$out2"; exit 1; }
echo "OK [3] (skip sem deps; executa com deps)"

echo "PASS w97-hook-portability-gate"
