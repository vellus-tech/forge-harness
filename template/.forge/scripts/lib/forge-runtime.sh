#!/usr/bin/env bash
# lib/forge-runtime.sh — leitura e execução dos checks declarados no bloco `runtime:` do FORGE.md.
# Sourceável (não executável por si). Fonte ÚNICA de duas coisas que existiam em cópia única e
# inacessível dentro do spec-verify.sh:
#
#   forge_get_runtime <key>          → valor escalar de "  <key>:" dentro do bloco runtime:
#   forge_run_gate <name> <cmd> <log>→ executa um check com teto de tempo; rc do check
#   forge_runtime_gates              → lista (uma por linha) os nomes declarados em runtime.gates
#
# POR QUE EXTRAIR: `commands/waves/wave.md` manda rodar `bash .forge/scripts/run-gates.sh` e
# passar o resultado ao `wave-ops.sh close --gate`. Esse script NUNCA EXISTIU — a doc invocava um
# arquivo ausente, então na prática o veredito da wave vinha do chamador, e a skill wave-advance
# chegava a passar `--gate OK` literal. Um executor que só existe dentro de um script que a wave
# não chama é um executor que a wave não tem; daí a extração, em vez de uma segunda cópia.
#
# `runtime.gates` é CSV escalar de NOMES DE SCRIPT (`check-authz,check-observability`), nunca
# comando shell livre nem block-sequence — forge_get_runtime só lê "key: value" de uma linha.
# Cada nome resolve para `.forge/scripts/<nome>.sh`, invocado com o change-id.

FORGE_GATE_TIMEOUT_S="${FORGE_GATE_TIMEOUT_S:-300}"

forge_get_runtime() { # forge_get_runtime <key> [root]
  local key="$1" root="${2:-${FORGE_ROOT:-.}}"
  [ -f "$root/.forge/FORGE.md" ] || return 0
  awk -v key="$key" '
    /^runtime:/ { inb=1; next }
    inb && /^[^ ]/ { inb=0 }
    inb { sub(/^  /, ""); if (index($0, key ":") == 1) { sub(key ":", ""); gsub(/^ +| +$/, ""); print; exit } }
  ' "$root/.forge/FORGE.md"
}

# Nomes declarados em runtime.gates, um por linha. Ausência ⇒ saída vazia (no-op retrocompatível).
forge_runtime_gates() { # forge_runtime_gates [root]
  local csv; csv="$(forge_get_runtime gates "${1:-${FORGE_ROOT:-.}}" || true)"
  [ -n "$csv" ] || return 0
  local g
  IFS=',' read -ra _fg <<< "$csv"
  for g in "${_fg[@]}"; do
    g="$(printf '%s' "$g" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$g" ] && printf '%s\n' "$g"
  done
  return 0
}

# Teto de tempo explícito por check — um gate que pendura é um gate que ninguém espera, e o
# watchdog do executor mata a sessão inteira em vez de reprovar o check.
forge_run_gate() { # forge_run_gate <name> <command> <logfile> [root]
  local name="$1" cmd="$2" log="$3" root="${4:-${FORGE_ROOT:-.}}"
  perl -e "alarm $FORGE_GATE_TIMEOUT_S; exec @ARGV" -- bash -c "cd '$root' && $cmd" >"$log" 2>&1
}
