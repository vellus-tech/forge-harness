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

DETECTED=""

[ -n "$(find_marker '*.sln')$(find_marker '*.csproj')" ] && DETECTED="$DETECTED dotnet"
{ [ -f package.json ] || [ -f tsconfig.json ] || [ -n "$(find_marker tsconfig.json)" ]; } && DETECTED="$DETECTED node"
{ [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && DETECTED="$DETECTED python"
[ -n "$(find_marker 'build.gradle')$(find_marker 'build.gradle.kts')" ] && DETECTED="$DETECTED kotlin"

if [ -z "$DETECTED" ]; then
  echo "Nenhuma stack reconhecida no repositório (.NET / Node-TS / Python / Kotlin)."
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
