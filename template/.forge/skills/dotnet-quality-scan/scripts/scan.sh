#!/usr/bin/env bash
# scan.sh — detecção determinística do que o compilador .NET NÃO reprova.
#
# Roslyn e os analisadores cobrem nulidade, uso de API, performance e estilo. Não cobrem
# intenção: nenhum analisador dirá que `PedidoHelper` não nomeia nada, que um parâmetro `bool`
# esconde duas funções numa só, ou que `#region` está escondendo uma classe grande demais.
# Essa camada era revisão por memória de modelo — e revisão por memória omite em silêncio.
#
# Duas propriedades tornam isto auditável, e as duas são exigidas pelo gate w155:
#   1. TODA regra emite uma linha, inclusive quando não acha nada. Omissão fica visível.
#   2. Todo achado sai com arquivo:linha. Quem revisa confere, não acredita.
#
# Usa ripgrep quando disponível e grep quando não — o mesmo padrão nos dois motores. Um scanner
# que emudece porque falta ferramenta é pior do que nenhum: reporta verde por ausência de motor.
#
# Uso: scan.sh [--root <dir>] [--json <arquivo>] [--max <n>]
# Exit: 0 sem achados; 1 com achados; 2 em erro de uso.
set -uo pipefail

ROOT="."
JSON=""
MAX=10

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --json) JSON="$2"; shift 2 ;;
    --max)  MAX="$2"; shift 2 ;;
    -h|--help) sed -n '1,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "FAIL uso: argumento desconhecido '$1'" >&2; exit 2 ;;
  esac
done

[ -d "$ROOT" ] || { echo "FAIL root inexistente: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

ENGINE="grep"
command -v rg >/dev/null 2>&1 && ENGINE="rg"

# Um motor, um padrão. `rg` e `grep -E` concordam sobre classes POSIX e sobre `$` dentro de
# alternativa; `\b` NÃO é portátil (BSD grep do macOS não o reconhece) e por isso não aparece
# em nenhum padrão abaixo.
search() {
  local pattern="$1" exclude="${2:-}"
  local raw
  if [ "$ENGINE" = "rg" ]; then
    raw="$(rg --no-heading --line-number --no-messages --glob '*.cs' -e "$pattern" "$ROOT" 2>/dev/null)"
  else
    raw="$(grep -rnE --include='*.cs' -e "$pattern" "$ROOT" 2>/dev/null)"
  fi
  # Lookahead não existe em ERE nem no regex do rg: o que a regra precisa NEGAR sai por filtro.
  if [ -n "$exclude" ]; then
    raw="$(printf '%s\n' "$raw" | grep -vE "$exclude")"
  fi
  printf '%s\n' "$raw" | grep -vE '/(obj|bin)/' | grep -v '^$' | sed "s|^$ROOT/||"
}

FINDINGS=0
JSON_ITEMS=""

# rule <id> <severidade> <padrão> <explicação>
rule() {
  local id="$1" sev="$2" pattern="$3" why="$4" exclude="${5:-}"
  local hits count
  hits="$(search "$pattern" "$exclude")"
  count="$(printf '%s' "$hits" | grep -c . )"
  if [ "$count" = "0" ]; then
    echo "OK $id [$sev] nenhuma ocorrência"
    return 0
  fi
  echo "FOUND $id [$sev] $count ocorrência(s) — $why"
  printf '%s\n' "$hits" | head -n "$MAX" | sed 's|^|     |'
  [ "$count" -gt "$MAX" ] && echo "     … e mais $((count - MAX)) (use --max)"
  FINDINGS=$((FINDINGS + count))
  JSON_ITEMS="$JSON_ITEMS
{\"rule\":\"$id\",\"severity\":\"$sev\",\"count\":$count,\"why\":\"$why\"},"
  return 0
}

echo "INFO dotnet-quality-scan root=$ROOT engine=$ENGINE"

rule async-void HIGH \
  'async[[:space:]]+void[[:space:]]' \
  'exceção lançada em async void não é capturável pelo chamador e derruba o processo; só event handler justifica'

rule blocking-wait BLOCKER \
  '([.]Result([^A-Za-z0-9_]|$)|[.]Wait\(\)|GetAwaiter\(\)[.]GetResult\(\))' \
  'bloquear em código async é deadlock em contexto com SynchronizationContext e esgota o pool no resto'

rule new-httpclient HIGH \
  'new[[:space:]]+HttpClient[[:space:]]*\(' \
  'HttpClient instanciado direto esgota sockets (TIME_WAIT) e ignora rotação de DNS; use IHttpClientFactory'

rule region MEDIUM \
  '^[[:space:]]*#region' \
  'region esconde tamanho: a classe que precisa de dobra é a classe que precisa de divisão'

rule generic-name MEDIUM \
  '(class|record|struct|interface)[[:space:]]+[A-Za-z0-9_]*(Manager|Helper|Utils|Utility)([^A-Za-z0-9_]|$)' \
  'Manager/Helper/Utils não nomeiam responsabilidade — descrevem que ninguém decidiu qual é'

rule bool-param MEDIUM \
  '(public|internal|protected)[^;]*\([^)]*bool[[:space:]]+[A-Za-z_]' \
  'parâmetro booleano de modo indica duas funções numa só, e no call site vira um true ilegível'

rule empty-catch HIGH \
  'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}' \
  'erro engolido some do log e reaparece como corrupção de dado'

rule datetime-now MEDIUM \
  'DateTime[.]Now([^A-Za-z0-9_]|$)' \
  'DateTime.Now amarra o domínio ao fuso da máquina e ao relógio real; use UtcNow ou abstração de tempo'

rule sql-interpolation BLOCKER \
  '(FromSqlRaw|ExecuteSqlRaw|CommandText[[:space:]]*=|new[[:space:]]+SqlCommand)[^"]*\$"' \
  'interpolação em SQL é injeção; use parâmetro ou a variante Interpolated do EF Core'

rule mutable-static HIGH \
  '(public|internal)[[:space:]]+static[[:space:]]' \
  'estado estático mutável é dependência global não testável e corrida em servidor concorrente' \
  '(readonly|const|\(|class|record|struct|interface|enum)'

# ── interface com implementação única ───────────────────────────────────────────────────────
# Heurística conservadora: conta declarações `interface IX` e quantos tipos declaram `: IX`.
# Uma implementação só costuma ser abstração especulativa — mas às vezes é fronteira de teste
# legítima, por isso a saída é MEDIUM e o julgamento fica com quem revisa.
single_impl=""
for iface in $(search '(public|internal)[[:space:]]+(partial[[:space:]]+)?interface[[:space:]]+I[A-Z]' \
                | sed -E 's/.*interface[[:space:]]+(I[A-Za-z0-9_]+).*/\1/' | sort -u); do
  impls="$(search "(:|,)[[:space:]]*${iface}([^A-Za-z0-9_]|$)" | grep -c . )"
  [ "$impls" = "1" ] && single_impl="$single_impl $iface"
done
if [ -z "$single_impl" ]; then
  echo "OK single-impl-interface [MEDIUM] nenhuma ocorrência"
else
  echo "FOUND single-impl-interface [MEDIUM] $(echo "$single_impl" | wc -w | tr -d ' ') ocorrência(s) — interface com uma única implementação costuma ser abstração especulativa"
  echo "    $(echo "$single_impl" | sed 's/^ //')"
  FINDINGS=$((FINDINGS + 1))
  JSON_ITEMS="$JSON_ITEMS
{\"rule\":\"single-impl-interface\",\"severity\":\"MEDIUM\",\"count\":1,\"why\":\"interface com implementação única\"},"
fi

if [ -n "$JSON" ]; then
  {
    echo '{"skill":"dotnet-quality-scan","root":"'"$ROOT"'","engine":"'"$ENGINE"'","findings":['
    printf '%s' "$JSON_ITEMS" | sed '$ s/,$//' | grep -v '^$'
    echo '],"total":'"$FINDINGS"'}'
  } > "$JSON"
  echo "INFO json=$JSON"
fi

if [ "$FINDINGS" = "0" ]; then
  echo "PASS dotnet-quality-scan (0 achados)"
  exit 0
fi
echo "FAIL dotnet-quality-scan ($FINDINGS achado(s) — julgue caso a caso; nem todo achado é defeito)"
exit 1
