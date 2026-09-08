#!/usr/bin/env bash
# restaura-seis-perdas-do-detail.sh — devolve a um ledger os SEIS blocos de `detail` que
# `update --detail` destruiu antes da guarda de preservação existir (onda w211).
#
# QUEM RODA: o ORQUESTRADOR, UMA vez, depois de a suíte estar verde. Nunca um gate, nunca um
# subagente — escrever em `.forge/ledger/` é operação de dono.
#
# COMO: pela maquinaria que a onda criou (`ledger-ops.sh note --kind correction`), o que preserva o
# `detail` atual, acrescenta o antigo com marcador datado e serve de prova de ponta a ponta do
# verbo novo sobre o dado real.
#
# ALVO EXPLÍCITO, SEMPRE (`--root`). A versão anterior deste script derivava o ledger de onde ELE
# mora e invocava `ledger-ops.sh` SEM exportar `FORGE_ROOT` — e `ledger-ops.sh` resolve o destino da
# escrita por `forge_resolve_root`, que ignora onde o script mora e cai em `forge_main_root`, isto é,
# o TRONCO, a partir do `cwd`. Rodado de dentro de um worktree, as três coisas divergiam: a guarda
# de idempotência lia o ledger da árvore de trabalho, a escrita ia para o ledger do tronco, e as
# duas linhas de sha imprimiam o arquivo que nunca foi escrito. Medido em bancada: sha do arquivo
# observado IDÊNTICO antes e depois, enquanto o ledger do tronco mudava de 934d397c… para
# b10ab056… e recebia os blocos. Três danos, e o terceiro é o que este script existe para evitar:
# ~22 KB entram num ledger que o operador não estava olhando; ele lê "sha antes == sha depois" e
# conclui que nada foi gravado; e a segunda execução torna a gravar, porque a guarda continua
# consultando o arquivo intocado. A correção é uma só: o alvo é declarado, e o MESMO caminho é
# exportado como `FORGE_ROOT` para a escrita, lido para a idempotência e medido no sha.
#
# IDEMPOTÊNCIA: `note` é acumulativo por desenho, então uma segunda execução duplicaria os blocos.
# Este script confere, item a item, se o texto recuperado JÁ está no `detail` de hoje e pula os que
# estiverem — a conferência é a proteção, não a memória de quem executa. Ela só vale porque lê o
# mesmo arquivo em que grava.
#
# TRONCO PROTEGIDO: gravar no ledger do checkout principal deste repositório exige, além do
# `--root`, a confirmação `--confirmo-tronco`. O ledger real carrega 109 itens e é estado durável de
# projeto; nenhuma rodada de revisão, gate ou bancada pode escrever nele por acidente.
#
# Uso:
#   bash docs/plans/spikes/restaura-seis-perdas-do-detail.sh --root <dir>                    # dry-run
#   bash docs/plans/spikes/restaura-seis-perdas-do-detail.sh --root <dir> --apply             # grava
#   bash docs/plans/spikes/restaura-seis-perdas-do-detail.sh --root <tronco> --apply --confirmo-tronco
set -euo pipefail

# SRC_REPO é o repositório de onde a HISTÓRIA é lida (`git show <commit>^:…`) — sempre este
# repositório, porque é nele que os commits da perda existem. Ele é independente do alvo da
# escrita, que é `--root` e nada mais.
SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export SRC_REPO   # o heredoc node abaixo lê SRC_REPO do ambiente
LG="$SRC_REPO/template/.forge/scripts/ledger-ops.sh"

TARGET=""; APPLY=0; CONFIRMA_TRONCO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { echo "FAIL: '--root' exige um caminho" >&2; exit 2; }
      case "${2:-}" in --*) echo "FAIL: '--root' recebeu '$2', que é nome de flag, não caminho" >&2; exit 2 ;; esac
      TARGET="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --confirmo-tronco) CONFIRMA_TRONCO=1; shift ;;
    *) echo "FAIL: flag desconhecida '$1'. Aceitas: --root <dir> --apply --confirmo-tronco" >&2; exit 2 ;;
  esac
done

[ -n "$TARGET" ] || {
  echo "FAIL: '--root <dir>' é obrigatório — o alvo da escrita nunca é inferido." >&2
  echo "      Sem ele, 'ledger-ops.sh' resolveria o destino por conta própria e cairia no TRONCO," >&2
  echo "      enquanto a guarda de idempotência deste script leria outro arquivo." >&2
  exit 2
}
[ -d "$TARGET" ] || { echo "FAIL: '--root $TARGET' não é diretório" >&2; exit 2; }
ROOT="$(cd "$TARGET" && pwd -P)"
LF="$ROOT/.forge/ledger/ledger.json"
[ -f "$LF" ] || { echo "FAIL: '$LF' ausente — '--root' precisa apontar para uma raiz com .forge/ledger/ instalado" >&2; exit 2; }

# O tronco deste repositório, para a recusa. `--path-format=absolute` porque no próprio checkout
# principal `--git-common-dir` devolveria `.git` relativo.
TRONCO=""
if common="$(git -C "$SRC_REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && [ -n "$common" ]; then
  TRONCO="$(cd "$(dirname "$common")" && pwd -P)"
fi
if [ -n "$TRONCO" ] && [ "$ROOT" = "$TRONCO" ] && [ "$APPLY" -eq 1 ] && [ "$CONFIRMA_TRONCO" -eq 0 ]; then
  echo "FAIL: '--root' aponta para o TRONCO deste repositório ($TRONCO) e '--apply' foi pedido sem confirmação." >&2
  echo "      Esse ledger é estado durável de projeto. Para gravar nele de propósito, acrescente '--confirmo-tronco'." >&2
  exit 2
fi

# commit em que a perda ocorreu; o texto vivo está no PAI dele.
CASOS="d7d4ad46 LDG-0021
26ee11b6 LDG-0010
26ee11b6 LDG-0029
d7d4ad46 LDG-0003
d7d4ad46 LDG-0008
d7d4ad46 LDG-0029"
CASOS_DECLARADOS=6   # universo declarado: a divergência com o executado é o achado

TMP="$(mktemp -d "${TMPDIR:-/tmp}/restaura-detail.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "alvo da escrita (FORGE_ROOT): $ROOT"
echo "história lida de:             $SRC_REPO"
[ "$APPLY" -eq 1 ] || echo "modo: DRY-RUN (nada será gravado)"
SHA_ANTES="$(shasum -a 256 "$LF" | awk '{print $1}')"
echo "SHA do ledger antes: $SHA_ANTES"

# `while read` alimentado por here-string, NUNCA por pipe: `echo "$CASOS" | while read` roda o
# corpo num SUBSHELL e os contadores morrem com ele — o laço terminava sem dizer quantos casos
# examinou, que é a disciplina de universo declarado do plano invertida.
n=0; pulados=0; aplicados=0
while read -r commit id; do
  [ -n "${commit:-}" ] || continue
  n=$((n + 1))
  node -e '
    const { execSync } = require("child_process");
    const [rev, id] = process.argv.slice(1);
    const d = JSON.parse(execSync("git -C " + JSON.stringify(process.env.SRC_REPO) + " show " + rev + ":.forge/ledger/ledger.json", { maxBuffer: 200 * 1024 * 1024 }).toString("utf8"));
    const e = (d.entries || []).find((x) => x.id === id);
    if (!e) { console.error("entrada " + id + " ausente em " + rev); process.exit(1); }
    process.stdout.write(String(e.detail || ""));
  ' "$commit^" "$id" > "$TMP/$id-$commit.txt"
  # O `printf X` e o `%X` preservam quebras de linha finais: `$(cat …)` as descarta, e um texto
  # truncado no fim dessincronizaria a guarda `ja`, que compara com o arquivo íntegro.
  texto="$(cat "$TMP/$id-$commit.txt"; printf X)"; texto="${texto%X}"
  bytes="$(wc -c < "$TMP/$id-$commit.txt" | tr -d ' ')"
  ja="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);const t=require("fs").readFileSync(process.argv[3],"utf8");console.log(e&&String(e.detail||"").indexOf(t)!==-1?"sim":"nao")' "$LF" "$id" "$TMP/$id-$commit.txt")"
  if [ "$ja" = "sim" ]; then
    pulados=$((pulados + 1))
    echo "PULA   $id ($commit^, $bytes B) — o texto já está no detail de hoje"
    continue
  fi
  if [ "$APPLY" -eq 0 ]; then
    echo "DRY    $id ($commit^, $bytes B) — restauraria com: ledger-ops.sh note $id --kind correction --text \"<$bytes bytes de $commit^>\""
    continue
  fi
  # FORGE_ROOT explícito: a escrita vai exatamente para o arquivo que `ja` leu e que o sha mede.
  env FORGE_ROOT="$ROOT" bash "$LG" note "$id" --kind correction \
    --text "TEXTO RECUPERADO DE $commit^, destruído por um 'update --detail' anterior à guarda de preservação: $texto"
  aplicados=$((aplicados + 1))
  echo "APLICA $id ($commit^, $bytes B)"
done <<CASOS_EOF
$CASOS
CASOS_EOF

SHA_DEPOIS="$(shasum -a 256 "$LF" | awk '{print $1}')"
echo "SHA do ledger depois: $SHA_DEPOIS"
echo "universo: $n caso(s) examinado(s) de $CASOS_DECLARADOS declarado(s) — $aplicados aplicado(s), $pulados pulado(s)"
[ "$n" -eq "$CASOS_DECLARADOS" ] || { echo "FAIL: a lista declara $CASOS_DECLARADOS casos e o laço examinou $n — a divergência é o achado" >&2; exit 1; }
if [ "$APPLY" -eq 1 ] && [ "$aplicados" -gt 0 ] && [ "$SHA_ANTES" = "$SHA_DEPOIS" ]; then
  echo "FAIL: $aplicados caso(s) foram gravados e o sha do ledger observado NÃO mudou — a escrita foi para outro arquivo" >&2
  exit 1
fi
[ "$APPLY" -eq 1 ] || echo "(dry-run — nada foi gravado; rode com --apply para valer)"
