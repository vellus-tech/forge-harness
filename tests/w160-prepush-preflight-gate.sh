#!/usr/bin/env bash
# Gate W160 — pre-push revela TODAS as pré-condições de worktree ausentes numa passada, e não uma
# por ciclo de push (issue #81).
#
# Medido em campanha real (axis-go-cloud, PR #272): 9 tentativas de push, ZERO bloqueadas por
# defeito de código — a cadeia tinha 4 degraus e cada um só ficava visível depois que o anterior
# saía. Este gate planta DUAS pendências SIMULTÂNEAS de categorias diferentes (deps ausentes +
# build declarado e não produzido) e prova que a MESMA execução do `pre-push` nomeia as duas — um
# teste que planta uma pendência só não prova nada sobre o defeito (a instrução do plano).
#
# Canal real (rule testing/gate-delivery-channel.md): dirigido pelo `git`/stdin, nunca invocando o
# script do gate isolado — mesmo padrão de w147/w135.
#
#   [1] duas pendências plantadas (deps + build) → AMBAS na mesma execução; property 5 (diretório
#       sem package.json não é workspace pnpm) não gera ruído
#   [2] controle: resolver só a de deps ainda reprova, e só a de build sobra na saída
#   [3] recontrole: resolver a segunda também faz passar — restauração verificada com cmp
#   [4] delegação (issue #49 instância 4): .forge/scripts/ presente e o script ausente → ERRO, não silêncio
#   [5] repositório sem pnpm-workspace.yaml/package.json: preflight é NO-OP — sem falso positivo
#   [6] custo do caminho feliz: o preflight sozinho roda em milissegundos (stat, não suíte)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks/git"
PREREQS_LIB="$WS/template/.forge/scripts/lib/check-worktree-prereqs.mjs"

T="$(mktemp -d /tmp/forge-w160.XXXXXX)"
trap 'rm -rf "$T"' EXIT
ZERO=0000000000000000000000000000000000000000

# mkrepo <dir> — harness completo instalado, e um fixture de workspace pnpm com DUAS pendências
# simultâneas, tudo no MESMO commit raiz. Empurrar exatamente o commit raiz de uma branch nova faz
# `check-docs-reviewed` resolver base==local_sha (range vazio) e pular — mesmo truque de w147, para
# isolar o teste do gate de docs (que não é o assunto deste gate).
mkrepo() {
  mkdir -p "$1"
  cp -R "$WS/template/.forge" "$1/.forge"

  mkdir -p "$1/apps/admin-portal" "$1/apps/dev-portal" "$1/packages/dotnet"
  cat > "$1/pnpm-workspace.yaml" <<'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
EOF
  printf '{"name":"root","private":true}\n' > "$1/package.json"
  : > "$1/pnpm-lock.yaml"

  # apps/admin-portal: dependencies declaradas, node_modules AUSENTE — categoria "deps"
  printf '{"name":"@fx/admin-portal","dependencies":{"react":"1.0.0"}}\n' > "$1/apps/admin-portal/package.json"

  # apps/dev-portal: node_modules presente, "main" aponta para build-public/index.js AUSENTE, com
  # script "build" declarado — categoria "build"
  printf '{"name":"@fx/dev-portal","dependencies":{"react":"1.0.0"},"main":"build-public/index.js","scripts":{"build":"echo build"}}\n' > "$1/apps/dev-portal/package.json"
  mkdir -p "$1/apps/dev-portal/node_modules"

  # packages/dotnet: casado pelo glob "packages/*" mas SEM package.json — não é workspace pnpm
  # (property 5, achada contra a árvore real do axis-go-cloud). Não pode gerar pendência.
  echo "not a node package" > "$1/packages/dotnet/readme.txt"

  git -C "$1" init -q -b main
  git -C "$1" config user.email t@t
  git -C "$1" config user.name t
  git -C "$1" config commit.gpgsign false
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" commit -qm "chore: fixture pnpm workspace com pendencias simultaneas" >/dev/null 2>&1
}

push_out() {  # push_out <dir> <sha> — invoca o pre-push pelo canal real (stdin de refs, via git)
  (cd "$1" && printf 'refs/heads/main %s refs/heads/main %s\n' "$2" "$ZERO" \
    | bash "$1/.forge/hooks/git/pre-push" origin "file://$1" 2>&1)
}

R="$T/r1"; mkrepo "$R"
SHA="$(git -C "$R" rev-parse HEAD)"

# ── [1] ──────────────────────────────────────────────────────────────────────────────────────
echo "[1] duas pendências simultâneas (deps + build) → AMBAS na mesma execução"
out1="$(push_out "$R" "$SHA")"; rc1=$?
if [ "$rc1" -eq 0 ]; then
  echo "FAIL [1]: pre-push passou com duas pendências plantadas (saída: '$out1')"
  exit 1
fi
case "$out1" in *admin-portal*) : ;; *) echo "FAIL [1]: não nomeou a pendência de deps (admin-portal) — saída: '$out1'"; exit 1 ;; esac
case "$out1" in *dev-portal*) : ;; *) echo "FAIL [1]: não nomeou a pendência de build (dev-portal) — saída: '$out1'"; exit 1 ;; esac
case "$out1" in *"pnpm install"*) : ;; *) echo "FAIL [1]: pendência de deps sem o comando que a produz — saída: '$out1'"; exit 1 ;; esac
case "$out1" in *"pnpm --filter"*"build"*) : ;; *) echo "FAIL [1]: pendência de build sem o comando que a produz — saída: '$out1'"; exit 1 ;; esac
case "$out1" in *dotnet*) echo "FAIL [1]: reportou packages/dotnet (sem package.json) — property 5 violada — saída: '$out1'"; exit 1 ;; esac
echo "OK [1] — ambas na mesma execução"

# ── [2] controle: resolver só uma ainda reprova, nomeando só a que sobra ──────────────────────
echo "[2] controle: resolvendo só a pendência de deps, a de build ainda reprova sozinha"
mkdir -p "$R/apps/admin-portal/node_modules"
out2="$(push_out "$R" "$SHA")"; rc2=$?
if [ "$rc2" -eq 0 ]; then
  echo "FAIL [2]: pre-push passou com a pendência de build ainda ausente (saída: '$out2')"
  exit 1
fi
case "$out2" in *dev-portal*) : ;; *) echo "FAIL [2]: pendência de build sumiu sem ser resolvida — saída: '$out2'"; exit 1 ;; esac
case "$out2" in *admin-portal*) echo "FAIL [2]: pendência de deps já resolvida ainda aparece na saída — saída: '$out2'"; exit 1 ;; esac
echo "OK [2]"

# ── [3] recontrole: resolver a segunda faz passar — restauração verificada com cmp ────────────
echo "[3] recontrole: resolvendo a pendência de build também, o hook passa (restauração via cmp)"
mkdir -p "$R/apps/dev-portal/build-public"
printf 'export default 1;\n' > "$T/golden-index.js"
cp "$T/golden-index.js" "$R/apps/dev-portal/build-public/index.js"
out3="$(push_out "$R" "$SHA")"; rc3=$?
if [ "$rc3" -ne 0 ]; then
  echo "FAIL [3]: pre-push ainda bloqueia com as duas pendências resolvidas (saída: '$out3')"
  exit 1
fi
cmp -s "$R/apps/dev-portal/build-public/index.js" "$T/golden-index.js" \
  || { echo "FAIL [3]: build-public/index.js restaurado não bate byte-a-byte com o golden (cmp)"; exit 1; }
case "$out3" in *"pre-push OK"*) : ;; *) echo "FAIL [3]: passou sem a linha final 'pre-push OK' — saída: '$out3'"; exit 1 ;; esac
echo "OK [3] — restauração verificada com cmp"

# ── [4] delegação (issue #49 instância 4): script ausente com .forge/scripts/ presente → ERRO ─
echo "[4] .forge/scripts/ presente e check-worktree-prereqs.sh ausente → ERRO visível, não silêncio"
mv "$R/.forge/scripts/check-worktree-prereqs.sh" "$T/check-worktree-prereqs.sh.bak"
out4="$(push_out "$R" "$SHA")"; rc4=$?
mv "$T/check-worktree-prereqs.sh.bak" "$R/.forge/scripts/check-worktree-prereqs.sh"
if [ "$rc4" -eq 0 ]; then
  echo "FAIL [4]: pre-push passou com o script de prereqs removido (saída: '$out4')"
  exit 1
fi
case "$out4" in *check-worktree-prereqs.sh*) : ;; *) echo "FAIL [4]: não nomeou o alvo de delegação ausente — saída: '$out4'"; exit 1 ;; esac
echo "OK [4]"

# ── [5] sem pnpm-workspace.yaml/package.json: preflight é NO-OP — sem falso positivo ──────────
echo "[5] repositório sem pnpm workspace: preflight não bloqueia (sem ruído)"
R5="$T/r5"
mkdir -p "$R5"
cp -R "$WS/template/.forge" "$R5/.forge"
git -C "$R5" init -q -b main
git -C "$R5" config user.email t@t; git -C "$R5" config user.name t; git -C "$R5" config commit.gpgsign false
printf 'x\n' > "$R5/a.txt"
git -C "$R5" add -A >/dev/null 2>&1
git -C "$R5" commit -qm "chore: init" >/dev/null 2>&1
SHA5="$(git -C "$R5" rev-parse HEAD)"
out5="$(push_out "$R5" "$SHA5")"; rc5=$?
if [ "$rc5" -ne 0 ]; then
  echo "FAIL [5]: preflight bloqueou repositório sem pnpm workspace — falso positivo (saída: '$out5')"
  exit 1
fi
echo "OK [5]"

# ── [6] custo do caminho feliz: existence-check puro, não suíte ───────────────────────────────
echo "[6] custo do caminho feliz do preflight isolado (deve ser milissegundos, não segundos)"
t0=$(date +%s%N)
node "$PREREQS_LIB" --path "$R" >/dev/null 2>&1
rc6=$?
t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 ))
[ "$rc6" -eq 0 ] || { echo "FAIL [6]: preflight isolado reprovou com todas as pendências resolvidas (rc=$rc6)"; exit 1; }
echo "OK [6] — preflight isolado: ${ms}ms (existsSync/readFileSync, sem install/build)"
if [ "$ms" -gt 3000 ]; then
  echo "FAIL [6]: ${ms}ms é caro demais para um preflight que só faz stat — verifique se algo executa suíte"
  exit 1
fi

echo "PASS w160-prepush-preflight"
