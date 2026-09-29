#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + base "Embarque Fácil" + módulo Validação com tasks.md acima de 3.000 linhas (uma TASK por linha de ônibus).
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-embarque-facil/overlay/." "$TARGET/"
cp -R "$HERE/overlay/." "$TARGET/"
# O tasks.md gigante é gerado (cabeçalho + 280 TASKs, uma por linha de ônibus + cauda) para manter a fixture pequena no repositório.
# Defeitos de conteúdo plantados de propósito (subtask de implementação antes do teste, PBT-01 e RNF 1 sem TASK, sem Status Geral, coverage gates "não aplicável"): o validador NÃO deve chegar a listá-los, porque a Regra Especial de Tamanho bloqueia a revisão detalhada.
OUT="$TARGET/docs/product/modules/validacao/tasks.md"
{
  cat "$HERE/parts/head.md"
  for i in $(seq 1 280); do
    n=$(printf '%03d' "$i")
    cat <<TASK
### TASK-$n - Parametrizar tarifa da linha $n (Terminal Leste ↔ Bairro $n)

| Campo | Valor |
|-------|-------|
| **Onda** | Onda 1 - Parametrização por linha |
| **Branch** | \`feat/validacao/$n-linha-$n\` |
| **Status** | [ ] |
| **Depende de** | Não aplicável |
| **Entregável** | Tarifa base 440 centavos e noturna 490 centavos da linha $n carregadas no SQLite do validador |
| **Mapeia** | Req 2 |

- [ ] $i.1 Inserir a linha $n na tabela \`tarifa_linha\` do SQLite embarcado
- [ ] $i.2 Escrever teste que confere a tarifa da linha $n

TASK
  done
  cat "$HERE/parts/tail.md"
} > "$OUT"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
