#!/usr/bin/env bash
# doctor.sh — verifica a tooling de diagnóstico (e LSP, informativo) por stack
# presente no repositório. Por padrão apenas REPORTA o que falta; com --install
# tenta instalar os faltantes via o gerenciador de cada stack (opt-in explícito).
#
# Por que existe: as rules de "análise de impacto / LSP" dependem de que o
# DIAGNÓSTICO da stack (compilador / typechecker / linter) esteja instalado —
# esse é o passo que de fato valida uma edição. O LSP server é desejável para
# navegação semântica, mas é secundário. Este script não instala nada sem a
# flag --install e nunca roda automaticamente no init-project.
#
# Uso:
#   bash .forge/scripts/doctor.sh            # só reporta (default)
#   bash .forge/scripts/doctor.sh --install  # reporta e instala faltantes (opt-in)
#
# Saída: código 0 se todos os diagnósticos das stacks detectadas estão OK
#        (no modo report); código 1 se houver diagnóstico faltando.

set -u

INSTALL=0
case "${1:-}" in
  --install) INSTALL=1 ;;
  ""|--report) INSTALL=0 ;;
  -h|--help)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  *) echo "Argumento desconhecido: $1 (use --install ou --report)"; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# ── helpers ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
else GREEN=""; RED=""; YEL=""; DIM=""; RST=""; fi

MISSING_DIAG=0
have() { command -v "$1" >/dev/null 2>&1; }

ok()    { printf "  %s✓%s %s\n" "$GREEN" "$RST" "$1"; }
miss()  { printf "  %s✗%s %s\n" "$RED" "$RST" "$1"; }
info()  { printf "  %s·%s %s\n" "$YEL" "$RST" "$1"; }
hint()  { printf "      %s↳ %s%s\n" "$DIM" "$1" "$RST"; }

# Detecta stacks por marcadores no repo (ignora node_modules/bin/obj/.git).
find_marker() {
  find . \( -path ./node_modules -o -path ./.git -o -name bin -o -name obj -o -path ./dist \) -prune \
       -o -name "$1" -print 2>/dev/null | head -1
}

# ── Forge harness (§19.1) — roda mesmo sem stack detectada ──────────────────
check_harness() {
  [ -d "$ROOT/.forge" ] || return 0
  echo "Forge harness"

  for f in FORGE.md forge.yaml; do
    if [ -f "$ROOT/.forge/$f" ]; then ok "harness: .forge/$f"
    else miss "harness: .forge/$f ausente"; MISSING_DIAG=1; fi
  done

  if [ -f "$ROOT/AGENTS.md" ]; then
    if head -1 "$ROOT/AGENTS.md" | grep -q 'Generated from .forge/FORGE.md'; then
      ok "harness: AGENTS.md é projeção gerada do FORGE.md"
    else
      info "harness: AGENTS.md sem header de arquivo gerado (rode .forge/scripts/sync-adapters.sh)"
    fi
  else
    miss "harness: AGENTS.md ausente (rode .forge/scripts/sync-adapters.sh)"; MISSING_DIAG=1
  fi

  for link in CLAUDE.md QWEN.md GEMINI.md; do
    if [ -L "$ROOT/$link" ] && [ "$(readlink "$ROOT/$link")" = "AGENTS.md" ]; then
      ok "harness: $link -> AGENTS.md (symlink)"
    elif [ -f "$ROOT/$link" ] && head -1 "$ROOT/$link" | grep -q 'Generated from .forge/FORGE.md'; then
      ok "harness: $link (cópia materializada gerada)"
    else
      miss "harness: $link não resolve para AGENTS.md"; MISSING_DIAG=1
    fi
  done

  # infra that generates/validates the adapter legitimately mentions the target dir;
  # the leak check guards CONTENT (agents/rules/commands/skills), not the machinery
  leaks="$(grep -rl '\.claude/' "$ROOT/.forge" 2>/dev/null | grep -vE '/(adapters|scripts/lib)/|/scripts/doctor\.sh$' | wc -l | tr -d ' ')"
  if [ "$leaks" -eq 0 ]; then ok "harness: fonte canônica sem refs .claude/"
  else miss "harness: $leaks arquivo(s) da fonte canônica com refs .claude/"; MISSING_DIAG=1; fi

  orphans="$(grep -rl '<PROJECT_[A-Z_]*>' "$ROOT/.forge" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$orphans" -eq 0 ]; then ok "harness: sem placeholders <PROJECT_*> órfãos"
  else miss "harness: $orphans arquivo(s) com placeholders <PROJECT_*> não preenchidos"; MISSING_DIAG=1; fi

  locks_found=0
  for lock in "$ROOT"/.forge/adapters/*.lock.yaml; do
    [ -f "$lock" ] || continue
    locks_found=$((locks_found + 1))
    aname="$(basename "$lock" .lock.yaml)"
    drift=0
    while read -r dest hash; do
      [ -n "$dest" ] || continue
      if [ "$hash" = "symlink" ]; then
        { [ -L "$ROOT/$dest" ] || { [ -f "$ROOT/$dest" ] && head -1 "$ROOT/$dest" | grep -q 'Generated from'; }; } || drift=$((drift + 1))
      elif [ -f "$ROOT/$dest" ]; then
        actual="sha256:$(shasum -a 256 "$ROOT/$dest" | cut -d' ' -f1)"
        [ "$actual" = "$hash" ] || drift=$((drift + 1))
      else
        drift=$((drift + 1))
      fi
    done <<EOF_LOCK
$(awk '/^  - dest: /{d=$3} /^    sha256: /{print d" "$2}' "$lock")
EOF_LOCK
    if [ "$drift" -eq 0 ]; then ok "harness: adapter $aname sem drift (lockfile íntegro)"
    else miss "harness: $drift alvo(s) do adapter $aname com drift (rode .forge/scripts/sync-adapters.sh)"; MISSING_DIAG=1; fi
  done
  if [ "$locks_found" -eq 0 ]; then
    info "harness: nenhum lockfile de adapter (rode .forge/scripts/sync-adapters.sh)"
  fi
  echo
}
check_harness

DETECTED=""

[ -n "$(find_marker '*.sln')$(find_marker '*.csproj')" ] && DETECTED="$DETECTED dotnet"
{ [ -f package.json ] || [ -f tsconfig.json ] || [ -n "$(find_marker tsconfig.json)" ]; } && DETECTED="$DETECTED node"
{ [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && DETECTED="$DETECTED python"
[ -n "$(find_marker 'build.gradle')$(find_marker 'build.gradle.kts')" ] && DETECTED="$DETECTED kotlin"

if [ -z "$DETECTED" ]; then
  echo "Nenhuma stack reconhecida no repositório (.NET / Node-TS / Python / Kotlin)."
  if [ "$MISSING_DIAG" -eq 1 ]; then
    echo "${RED}Problemas no harness Forge detectados (ver acima).${RST}"
    exit 1
  fi
  echo "Nada a verificar."
  exit 0
fi

echo "Stacks detectadas:${DETECTED}"
echo "Modo: $( [ "$INSTALL" -eq 1 ] && echo 'reportar + instalar (--install)' || echo 'somente reportar' )"
echo

# try_install <descrição> <comando-de-instalação...>
try_install() {
  local desc="$1"; shift
  if [ "$INSTALL" -eq 0 ]; then
    hint "instalar: $*"
    return 1
  fi
  echo "      ${DIM}instalando ($desc): $*${RST}"
  if "$@"; then ok "instalado: $desc"; return 0; else miss "falha ao instalar: $desc"; return 1; fi
}

# ── .NET ─────────────────────────────────────────────────────────────────────
check_dotnet() {
  echo ".NET"
  if have dotnet; then
    ok "diagnóstico: dotnet build / dotnet format ($(dotnet --version 2>/dev/null))"
  else
    miss "diagnóstico: dotnet SDK ausente (load-bearing — compilação/format)"
    MISSING_DIAG=1
    hint "instale o .NET SDK: https://dotnet.microsoft.com/download (ou: brew install --cask dotnet-sdk)"
  fi
  # LSP (opcional, informativo)
  if have csharp-ls || have omnisharp; then ok "lsp: csharp-ls/omnisharp presente"
  else info "lsp: csharp-ls/OmniSharp ausente (opcional — VS Code C# Dev Kit já provê)"
       try_install "csharp-ls" dotnet tool install -g csharp-ls || true
  fi
}

# ── Node / TypeScript ─────────────────────────────────────────────────────────
check_node() {
  echo "Node / TypeScript"
  # tsc: preferir o local do projeto; aceitar global
  if npx --no-install tsc --version >/dev/null 2>&1 || have tsc; then
    ok "diagnóstico: tsc (typescript) disponível"
  else
    miss "diagnóstico: tsc (typescript) ausente (load-bearing — typecheck)"
    MISSING_DIAG=1
    try_install "typescript" npm install -g typescript || true
  fi
  if npx --no-install eslint --version >/dev/null 2>&1 || have eslint; then
    ok "diagnóstico: eslint disponível"
  else
    info "diagnóstico: eslint ausente (recomendado)"
    try_install "eslint" npm install -g eslint || true
  fi
  if have typescript-language-server; then ok "lsp: typescript-language-server presente"
  else info "lsp: typescript-language-server ausente (opcional)"
       try_install "typescript-language-server" npm install -g typescript-language-server || true
  fi
}

# ── Python ────────────────────────────────────────────────────────────────────
check_python() {
  echo "Python"
  if have pyright || have mypy; then
    ok "diagnóstico: $(have pyright && echo pyright || echo mypy) disponível"
  else
    miss "diagnóstico: pyright/mypy ausente (load-bearing — typecheck)"
    MISSING_DIAG=1
    if have pipx; then try_install "pyright" pipx install pyright || true
    else hint "instale pipx e: pipx install pyright (ou npm install -g pyright)"; fi
  fi
  if have ruff; then ok "diagnóstico: ruff disponível"
  else info "diagnóstico: ruff ausente (recomendado)"
       if have pipx; then try_install "ruff" pipx install ruff || true; else hint "pipx install ruff"; fi
  fi
  # pyright já serve como LSP; python-lsp-server é alternativa
  if have pyright || have pylsp; then ok "lsp: pyright/pylsp presente"
  else info "lsp: pyright/python-lsp-server ausente (opcional)"; fi
}

# ── Kotlin / JVM ───────────────────────────────────────────────────────────────
check_kotlin() {
  echo "Kotlin / JVM"
  if [ -x ./gradlew ] || have gradle; then
    ok "diagnóstico: gradle ($( [ -x ./gradlew ] && echo './gradlew' || echo 'gradle' ) compileKotlin)"
  else
    miss "diagnóstico: gradle/gradlew ausente (load-bearing — compileKotlin)"
    MISSING_DIAG=1
    hint "use o wrapper ./gradlew do projeto, ou: brew install gradle"
  fi
  if have ktlint || have detekt; then ok "diagnóstico: ktlint/detekt presente"
  else info "diagnóstico: ktlint/detekt ausente (recomendado)"
       if command -v brew >/dev/null 2>&1; then try_install "ktlint" brew install ktlint || true
       else hint "brew install ktlint (ou via gradle plugin)"; fi
  fi
  if have kotlin-language-server; then ok "lsp: kotlin-language-server presente"
  else info "lsp: kotlin-language-server ausente (opcional)"
       if command -v brew >/dev/null 2>&1; then try_install "kotlin-language-server" brew install kotlin-language-server || true
       else hint "brew install kotlin-language-server"; fi
  fi
}

for stack in $DETECTED; do
  case "$stack" in
    dotnet) check_dotnet ;;
    node)   check_node ;;
    python) check_python ;;
    kotlin) check_kotlin ;;
  esac
  echo
done

if [ "$MISSING_DIAG" -eq 1 ] && [ "$INSTALL" -eq 0 ]; then
  echo "${RED}Diagnóstico(s) load-bearing ausente(s).${RST} Rode com --install ou instale manualmente (ver dicas acima)."
  exit 1
fi

echo "${GREEN}OK${RST} — diagnósticos das stacks detectadas disponíveis."
exit 0
