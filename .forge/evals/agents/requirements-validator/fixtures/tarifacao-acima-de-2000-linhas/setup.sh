#!/usr/bin/env bash
# Monta a fixture do eval em "$1": consumidor do forge-harness + base "Rota Única" + módulo Tarifação com requirements.md acima de 2.000 linhas (gerado).
set -euo pipefail
TARGET="${1:?uso: setup.sh <diretório-alvo>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${FORGE_REPO:-$(cd "$HERE/../../../../../.." && pwd)}"
mkdir -p "$TARGET"
node "$REPO/bin/forge.mjs" init --target "$TARGET" -y --no-plugin >/dev/null
cp -R "$HERE/../_base-rota-unica/overlay/." "$TARGET/"
cp -R "$HERE/overlay/." "$TARGET/"
# O requirements.md gigante é gerado (cabeçalho + 170 requisitos de tarifa por linha + cauda) para manter a fixture pequena no repositório.
OUT="$TARGET/docs/product/modules/tarifacao/requirements.md"
{
  cat "$HERE/parts/head.md"
  for i in $(seq 1 170); do
    n=$(printf '%03d' "$i")
    case $((i % 3)) in 0) op="Expresso Sul";; 1) op="Viação Leste";; *) op="TransNorte";; esac
    cat <<REQ
### Req $i — Tarifa da linha $n (Terminal Leste ↔ Bairro $n)

**Como** Passageiro **quero** pagar a tarifa vigente da linha $n **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária $op 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- $i.1 A tarifa base da linha $n ($op) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- $i.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha $n não é cobrado.

REQ
  done
  cat "$HERE/parts/tail.md"
} > "$OUT"
git -C "$TARGET" init -q
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name=eval -c user.email=eval@example.invalid commit -q -m "fixture: estado inicial"
# Remove o artefato sob avaliação e seus adapters para não contaminar o baseline.
rm -rf "$TARGET/.forge/skills" "$TARGET/.forge/agents" "$TARGET/.claude/skills" "$TARGET/.claude/agents" "$TARGET/plugin"
