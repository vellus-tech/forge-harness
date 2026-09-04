#!/usr/bin/env bash
# Gate W158 — escopo da varredura de placeholders <PROJECT_*> do doctor (LDG-0040).
#
# O guard de `doctor.sh` (linha ~105, orphans) varre "$ROOT/.forge" procurando
# `<PROJECT_[A-Z_]*>` órfão — o sinal de que alguém instalou o harness (/forge:init) e não
# preencheu FORGE.md/context.md/constitution.md. Dois problemas de escopo:
#
# (a) specs ARQUIVADAS e o BASELINE (product/current) legitimamente citam `<PROJECT_ID>` como
#     TEXTO descrevendo o próprio mecanismo do guard (ex.: um critério de aceite arquivado do tipo
#     "projeto com <PROJECT_ID> em worktrees/** -> doctor não reporta"), não como configuração por
#     preencher. Já excluído da varredura (USER_DATA em doctor.sh) — este gate fixa a prova.
#
# (b) `ROOT` era calculado só a partir de `$0` (`dirname "$0")/../..`), nunca honrava
#     `FORGE_ROOT`. No próprio forge-harness, cuja raiz do dogfood é parcial (sem scripts/ — ver
#     memória do mecanismo de dogfood), a ÚNICA cópia executável de doctor.sh vive em
#     `template/.forge/scripts/doctor.sh` — o diretório-FONTE do pacote, que embute
#     FORGE.md/context.md/constitution.md com `<PROJECT_*>` NÃO preenchido POR DESENHO (são o
#     scaffold que /forge:init copia; o motivo pelo qual .forge/templates/ já é excluído). Sem
#     honrar FORGE_ROOT, `bash template/.forge/scripts/doctor.sh --report` sempre resolve ROOT
#     para `template/` e se autoflagra: 3 arquivo(s) — LDG-0040.
#
#   [1] projeto normal (ROOT via $0, sem FORGE_ROOT): specs/archived + product/current com
#       `<PROJECT_ID>` em prosa NÃO reprovam.
#   [2] cópia "empacotada" de doctor.sh + scaffold não preenchido num `template/.forge/` aninhado
#       (a forma exata do dogfood deste repositório): SEM FORGE_ROOT, o guard se autoflagra —
#       comportamento estável e documentado (não é o que se quer checar; é o motivo de precisar
#       do FORGE_ROOT).
#   [3] a MESMA cópia, agora com FORGE_ROOT apontando pro projeto real: reprova zero — resolve
#       para o projeto, não para o pacote-fonte.
#   [4] controle: um placeholder REAL no FORGE.md do projeto (fora de specs/product) continua
#       reprovando sob FORGE_ROOT — exatamente 1 arquivo, nomeando o certo.
#   [5] recontrole: placeholder real removido -> volta a "sem placeholders", byte-idêntico ao
#       FORGE.md original (cmp).
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w158.XXXXXX)"
trap 'rm -rf "$T"' EXIT

echo "[0] instala projeto real via forge.mjs init"
node "$WS/bin/forge.mjs" init --target "$T" --slug demo --name Demo --desc t --yes --no-plugin \
  >"$T.init.log" 2>&1 || { echo "FAIL [0]: init falhou"; cat "$T.init.log"; exit 1; }
[ -f "$T/.forge/scripts/doctor.sh" ] || { echo "FAIL [0]: .forge/scripts/doctor.sh ausente pós-init"; exit 1; }
out0="$(bash "$T/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "sem placeholders" <<<"$out0" || { echo "FAIL [0]: projeto recém-instalado já reprova (deveria estar limpo): $out0"; exit 1; }
echo "OK [0]"

echo "[1] specs arquivadas + baseline citando <PROJECT_ID> em prosa não reprovam (ROOT normal)"
mkdir -p "$T/.forge/specs/archived/2026-08-03-hist-change"
cat > "$T/.forge/specs/archived/2026-08-03-hist-change/design.md" <<'EOF'
# Design (histórico, arquivado)

Cenário de teste: projeto com `<PROJECT_ID>` em `worktrees/**` -> doctor não reporta placeholder órfão.
EOF
mkdir -p "$T/.forge/product/current/capabilities/demo-cap"
cat > "$T/.forge/product/current/capabilities/demo-cap/spec.yaml" <<'EOF'
scenarios:
  - id: sc-1
    given: "um projeto com um placeholder <PROJECT_ID> dentro de worktrees/**"
    when: "doctor roda"
    then: "não reporta placeholder órfão"
EOF
out1="$(bash "$T/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "sem placeholders" <<<"$out1" || { echo "FAIL [1]: histórico arquivado/baseline gerou falso-positivo: $out1"; exit 1; }
echo "OK [1]"

echo "[2] cópia empacotada (template/.forge aninhado) SEM FORGE_ROOT: se autoflagra (comportamento estável)"
mkdir -p "$T/template/.forge/scripts"
cp "$WS/template/.forge/scripts/doctor.sh" "$T/template/.forge/scripts/doctor.sh"
cp "$WS/template/.forge/FORGE.md" "$T/template/.forge/FORGE.md"
cp "$WS/template/.forge/context.md" "$T/template/.forge/context.md"
cp "$WS/template/.forge/constitution.md" "$T/template/.forge/constitution.md"
out2="$(bash "$T/template/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "arquivo(s) com placeholders" <<<"$out2" || { echo "FAIL [2]: cópia empacotada deveria se autoflagrar sem FORGE_ROOT (documenta por que FORGE_ROOT é necessário): $out2"; exit 1; }
echo "OK [2]"

echo "[3] a MESMA cópia, com FORGE_ROOT apontando pro projeto real: reprova zero (LDG-0040)"
out3="$(FORGE_ROOT="$T" bash "$T/template/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "sem placeholders" <<<"$out3" || { echo "FAIL [3]: FORGE_ROOT não resolveu pro projeto real — ainda se autoflagra: $out3"; exit 1; }
echo "OK [3]"

echo "[4] controle: placeholder real no FORGE.md do projeto continua reprovando sob FORGE_ROOT"
cp "$T/.forge/FORGE.md" "$T/FORGE.md.pristine"
sed -i '' 's/name: demo/name: <PROJECT_SLUG>/' "$T/.forge/FORGE.md"
out4="$(FORGE_ROOT="$T" bash "$T/template/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "1 arquivo(s) com placeholders" <<<"$out4" || { echo "FAIL [4]: placeholder real injetado não reprovou (ou contou errado — deveria ser exatamente 1, não os 3 do template/ nem os do histórico/baseline): $out4"; exit 1; }
echo "OK [4]"

echo "[5] recontrole: restaura o FORGE.md real -> volta a sem placeholders, byte-idêntico ao original"
cp "$T/FORGE.md.pristine" "$T/.forge/FORGE.md"
cmp "$T/FORGE.md.pristine" "$T/.forge/FORGE.md" || { echo "FAIL [5]: restauração não ficou byte-idêntica ao original"; exit 1; }
out5="$(FORGE_ROOT="$T" bash "$T/template/.forge/scripts/doctor.sh" --report 2>&1)" || true
grep -q "sem placeholders" <<<"$out5" || { echo "FAIL [5]: restauração não voltou a 'sem placeholders': $out5"; exit 1; }
echo "OK [5]"

echo "PASS w158-doctor-placeholder-scope-gate"
