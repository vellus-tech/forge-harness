#!/usr/bin/env bash
# Monta a fixture em $1: consumidor do forge-harness com base em develop e o diff em feature/notificacoes-jwt (serviço fora do CDE).
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_BIN="${FORGE_REPO:-$(git -C "$HERE" rev-parse --show-toplevel)}/bin/forge.mjs"
GIT=(git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid)
mkdir -p "$TARGET"
node "$FORGE_BIN" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/overlay/base/." "$TARGET/"
git -C "$TARGET" init -q -b develop
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "chore: estado inicial do serviço notificacoes"
git -C "$TARGET" checkout -q -b feature/notificacoes-jwt
cp -R "$HERE/overlay/feature/." "$TARGET/"
# Bloco PEM fictício (não é chave válida) montado em runtime para não versionar o marcador no harness.
KEYFILE="$TARGET/services/notificacoes/tests/Notificacoes.Tests/Fixtures/TestSigningKey.cs"
KIND="RSA PRIVATE KEY"
{
  printf -- '-----BEGIN %s-----\n' "$KIND"
  printf 'MIIEowIBAAKCAQEAexemploFicticioNaoEChaveValidaParaEval0000000000\n'
  printf 'q9Xn3VbT0dEvalSecurityReviewerFixtureApenasTextoDeTeste1111111111\n'
  printf -- '-----END %s-----\n' "$KIND"
} > "$TARGET/.pem.tmp"
python3 - "$KEYFILE" "$TARGET/.pem.tmp" <<'PY'
import sys
path, pem = sys.argv[1], open(sys.argv[2]).read().rstrip("\n")
src = open(path).read().replace("__PEM_BLOCK__", pem)
open(path, "w").write(src)
PY
rm -f "$TARGET/.pem.tmp"
git -C "$TARGET" add -A
"${GIT[@]}" commit -q -m "feat(notificacoes): endpoint autenticado por JWT, testes de integração e ADR-0012"
# Remove skills e agentes do alvo para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
