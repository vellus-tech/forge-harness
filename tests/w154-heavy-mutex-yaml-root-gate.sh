#!/usr/bin/env bash
# Gate W154 — proveniência e guarda da âncora declarada em `heavy_mutex.root` (issue #75, PR #79).
#
# A chave `heavy_mutex.root` existe para CONVERGÊNCIA: um host onde N repositórios já se serializam
# por um protocolo legado precisa migrar UM de cada vez. O modo de falha que ela evita é o pior que
# esta biblioteca conhece — dois mutexes com o MESMO NOME em diretórios diferentes, cada lado
# adquirindo com sucesso e ACREDITANDO estar protegido. É pior que não ter lock, porque só aparece
# quando duas suítes pesadas colidem.
#
# Este gate cobre três buracos medidos no caminho do YAML, todos invisíveis para quem só olha o rc:
#
#   [a] symlink vindo do arquivo VERSIONADO é recusado — a guarda geral existe e funciona.
#   [b] symlink cujo realpath é o mesmo do default NÃO era recusado: o bloco de convergência roda
#       ANTES do bloco estrito e a condição dele faz `cd`+`pwd -P`, que SEGUE o link — exatamente a
#       operação que o `-L` existe para preceder. Um terceiro que plante o nome desvia o lock.
#   [c] o recibo MENTIA: anunciava "default fixo /tmp" para uma âncora vinda do forge.yaml. O
#       comentário da própria biblioteca diz que comparar recibos entre migrado e legado é o
#       INSTRUMENTO de detecção de partição — um recibo que atribui ao default o que veio do YAML
#       quebra o instrumento no exato momento em que ele seria consultado.
#   [d] o token literal `${TMPDIR:-/tmp}` era recusado, e com ele o único valor que um repositório
#       PODE versionar para convergir com o legado: congelar o `$TMPDIR` expandido de uma máquina
#       num arquivo versionado quebraria toda outra máquina, em silêncio.
#
# ISOLAMENTO. Nenhum cenário chama `acquire`/`release` — só `_fhm_resolve_root`, que não cria lock
# algum. Essa é a garantia PRIMÁRIA, e ela é estrutural, não uma checagem. O mutex real da máquina
# (`${TMPDIR:-/tmp}/axis-heavy-suite.lock` e `/tmp/axis-heavy-suite.lock`) é compartilhado por
# quatro repositórios: tocá-lo faria esta suíte virar a carga que o mutex existe para impedir.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib/heavy-mutex.sh"
T="$(mktemp -d /tmp/forge-w154.XXXXXX)"
trap 'rm -rf "$T"' EXIT INT TERM
GATE_START="$(date +%s)"; GATE_BUDGET_S="${W154_BUDGET_S:-60}"
SCENARIOS_RUN=0
scenario() { SCENARIOS_RUN=$((SCENARIOS_RUN + 1)); echo "$1"; }

[ -f "$LIB" ] || { echo "FAIL [setup]: biblioteca ausente em $LIB"; exit 1; }

# Sonda. `env -u` das DUAS variáveis é obrigatório: o caminho do YAML só é consultado quando
# FORGE_HEAVY_MUTEX_ROOT está vazia, e FORGE_HEAVY_MUTEX_TESTING=1 EXIGE aquela variável (trava
# deliberada da biblioteca) — herdá-la do ambiente de quem roda a suíte daria 69 em todo cenário,
# um vermelho que não fala sobre o código sob teste.
r_lib() {  # r_lib <lib> <valor-do-yaml|__SEM__> -> ecoa "<rc>|<root>|<proveniência>"
  local lib="$1" val="$2" B o rc
  B="$(mktemp -d "$T/box.XXXXXX")"; mkdir -p "$B/.forge"
  if [ "$val" = "__SEM__" ]; then
    printf 'heavy_mutex:\n  enabled: true\n' > "$B/.forge/forge.yaml"
  else
    printf 'heavy_mutex:\n  enabled: true\n  root: %s\n' "$val" > "$B/.forge/forge.yaml"
  fi
  o="$(env -u FORGE_HEAVY_MUTEX_ROOT -u FORGE_HEAVY_MUTEX_TESTING FORGE_ROOT="$B" \
        bash -c '. "$0"; _fhm_resolve_root' "$lib" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "$(printf '%s' "$o" | tr '\t\n' '|;')"
}
r() { r_lib "$LIB" "$1"; }

# O realpath de /tmp é calculado, nunca escrito à mão: no macOS é /private/tmp (symlink) e no Linux
# do CI é o próprio /tmp. Um fixture com `/private/tmp` fixo apontaria para o nada no CI, e o
# cenário [b] passaria por não existir o alvo — verde por vacuidade, sobre o defeito que ele existe
# para pegar.
TMPREAL="$(cd /tmp 2>/dev/null && pwd -P)"
[ -n "$TMPREAL" ] || { echo "FAIL [setup]: não consegui resolver o realpath de /tmp"; exit 1; }


scenario "[g] CONTROLE SINTÉTICO da sonda: ela lê a biblioteca sob teste e distingue aceito de recusado"
# Sem este cenário a sonda não tem como se provar: uma sonda que devolvesse sempre a mesma string
# faria todos os outros cenários concordarem com ela, e não com o código. Duas respostas CONHECIDAS
# e diferentes entre si, produzidas por bibliotecas sintéticas.
STUB_OK="$T/stub-ok.sh"; STUB_NO="$T/stub-no.sh"
printf '%s\n' '_fhm_resolve_root() { printf "SENTINELA-W154-ACEITO\tproveniencia-sintetica\n"; return 0; }' > "$STUB_OK"
printf '%s\n' '_fhm_resolve_root() { echo "SENTINELA-W154-RECUSADO" >&2; return 69; }' > "$STUB_NO"
og_ok="$(r_lib "$STUB_OK" "/qualquer")"
grep -q '^0|' <<<"$og_ok" && grep -qF 'SENTINELA-W154-ACEITO' <<<"$og_ok" \
  || { echo "FAIL [g]: a sonda não devolveu o que a biblioteca sintética imprimiu ('$og_ok') — ela não está lendo o arquivo sob teste, e todo veredito dos outros cenários seria sobre a própria sonda"; exit 1; }
og_no="$(r_lib "$STUB_NO" "/qualquer")"
grep -q '^69|' <<<"$og_no" && grep -qF 'SENTINELA-W154-RECUSADO' <<<"$og_no" \
  || { echo "FAIL [g]: a sonda não propagou a RECUSA da biblioteca sintética ('$og_no') — se ela não distingue 0 de 69, os cenários [a] e [b] não podem provar recusa nenhuma"; exit 1; }
echo "OK [g]"


scenario "[a] symlink declarado no forge.yaml é RECUSADO, e a recusa NOMEIA o caminho"
mkdir -p "$T/alvo-atacante"
LNA="$T/link-atacante"; ln -sfn "$T/alvo-atacante" "$LNA"
oa="$(r "$LNA")"
grep -q '^69|' <<<"$oa" \
  || { echo "FAIL [a]: symlink no arquivo VERSIONADO não foi recusado ('$oa') — um terceiro que plante o nome desvia o lock em silêncio, e `mkdir -p` aceitaria"; exit 1; }
grep -qF "$LNA" <<<"$oa" \
  || { echo "FAIL [a]: a recusa não NOMEIA o caminho recusado ('$oa') — rc 69 sozinho não prova QUAL coisa o gate pegou, e a recusa é a única informação que o operador recebe"; exit 1; }
grep -qi 'symlink' <<<"$oa" \
  || { echo "FAIL [a]: a recusa não diz que o motivo é o symlink ('$oa') — sem o motivo o operador troca o valor por outro igualmente inválido"; exit 1; }
echo "OK [a]"


scenario "[b] symlink cujo realpath é o do default é RECUSADO — a convergência não pode contornar o -L"
# O CASO CENTRAL. A guarda `-L` não está removida no caso geral (o [a] prova que ela dispara); ela
# é CONTORNADA aqui, porque o bloco de convergência roda antes e a condição dele resolve o link.
LNT="$T/link-para-tmp"; ln -sfn "$TMPREAL" "$LNT"
[ -L "$LNT" ] \
  || { echo "FAIL [b]: o fixture não é um symlink — o cenário não teria o que medir"; exit 1; }
[ "$(cd "$LNT" 2>/dev/null && pwd -P)" = "$TMPREAL" ] \
  || { echo "FAIL [b]: o fixture não resolve para o realpath de /tmp — sem isso ele não exercita o ramo da convergência, e o cenário viraria uma cópia do [a]"; exit 1; }
ob="$(r "$LNT")"
grep -q '^69|' <<<"$ob" \
  || { echo "FAIL [b]: symlink do forge.yaml que resolve para o default PASSOU ('$ob') — o bloco de convergência roda ANTES do estrito e sua própria condição faz cd+pwd -P, que SEGUE o link: é exatamente a operação que o -L existe para preceder. A guarda tem de valer para TODO valor vindo do arquivo versionado, antes de qualquer resolução"; exit 1; }
grep -qF "$LNT" <<<"$ob" \
  || { echo "FAIL [b]: a recusa não NOMEIA o caminho ('$ob') — rc 69 aqui poderia vir de qualquer outra guarda, e o cenário não provaria que foi a de symlink"; exit 1; }
grep -qi 'symlink' <<<"$ob" \
  || { echo "FAIL [b]: recusado, mas não pela guarda de symlink ('$ob') — o rc certo pelo motivo errado não fecha o buraco"; exit 1; }
echo "OK [b]"


scenario "[c] root: /tmp é ACEITO, e o recibo NÃO atribui ao default o que veio do forge.yaml"
oc="$(r "/tmp")"
grep -q '^0|' <<<"$oc" \
  || { echo "FAIL [c]: declarar root: /tmp — o valor que a documentação chama de default — foi recusado ('$oc')"; exit 1; }
grep -qF 'forge.yaml' <<<"$oc" \
  || { echo "FAIL [c]: o recibo não diz que a âncora veio do forge.yaml ('$oc') — comparar recibos entre migrado e legado é o INSTRUMENTO de detecção de partição, e um recibo que credita ao default uma âncora declarada quebra o instrumento no momento em que ele seria consultado"; exit 1; }
grep -q 'default fixo' <<<"$oc" \
  && { echo "FAIL [c]: o recibo diz 'default fixo' para uma âncora DECLARADA ('$oc') — é a proveniência mentindo, e quem investigar uma partição vai descartar o forge.yaml como causa justamente porque o recibo o inocentou"; exit 1; }
echo "OK [c]"


scenario "[d] o token do diretório temporário é ACEITO, com a barra final preservada e recibo compatível com o consumidor"
# É o único valor que um repositório PODE versionar para convergir com o protocolo legado: o valor
# EXPANDIDO de uma máquina, congelado num arquivo versionado, quebraria todas as outras em silêncio.
# E `eval` sobre string vinda de arquivo versionado é injeção de comando com o privilégio de quem
# empurra, então o valor tem de ser um token RECONHECIDO, nunca avaliado.
#
# A barra final que o macOS põe na variável é PRESERVADA de propósito: o legado monta
# `"${TMPDIR:-/tmp}/<recurso>.lock"` e produz `//` no meio. Normalizar daria um caminho que resolve
# para o mesmo inode e IMPRIME string diferente — e comparar recibos entre migrado e legado é o
# instrumento de detecção de partição.
#
# O token é montado por CONCATENAÇÃO, nunca escrito literal — mesma disciplina das fixtures do w145.
# O gate estático `check-heavy-mutex.sh` proíbe a variável do chamador numa linha não-comentada que
# também cite o arquivo de trava, e com razão: é exatamente a forma que ele existe para caçar.
# Escrito literal, este arquivo reprovava o repositório INTEIRO pelo cenário [46b] do w151 — medido,
# e é a razão de o gate novo ter nascido vermelho na primeira execução da suíte consolidada.
TOKEN='${'"TMPDIR:-/tmp}"
ESPERADO="${TMPDIR:-/tmp}"; ESPERADO="${ESPERADO%/}/"
RECIBO='heavy_mutex.root do forge.yaml (compartilhada com os repositórios legados)'
for forma in "$TOKEN" "\"$TOKEN\""; do
  od="$(r "$forma")"
  grep -q '^0|' <<<"$od" \
    || { echo "FAIL [d]: a forma <$forma> foi RECUSADA ('$od') — o repositório que precisa convergir com o legado fica sem valor versionável, cai no /tmp fixo, e passa a disputar um recurso de MESMO NOME em outro diretório: cada lado adquire com sucesso e se acha protegido"; exit 1; }
  grep -qF "|$ESPERADO|" <<<"$od" \
    || { echo "FAIL [d]: a forma <$forma> resolveu para '$od', e não para '$ESPERADO' — ver o comentário acima sobre a barra final: normalizar produz string diferente para o mesmo inode e quebra a comparação de recibos"; exit 1; }
  grep -qF "$RECIBO" <<<"$od" \
    || { echo "FAIL [d]: a forma <$forma> não emitiu o recibo compatível com o do consumidor ('$od') — esperado: $RECIBO. Recibo divergente entre template e consumidor faz a comparação acusar partição onde não há, que é o mesmo instrumento quebrado pelo outro lado"; exit 1; }
done
echo "OK [d]"


scenario "[e] CONTROLE: caminho absoluto real e comum continua ACEITO no regime estrito"
# Sem este controle, um patch que passasse a recusar TUDO faria [a] e [b] verdes e pareceria
# correto — recusar tudo é o modo trivial de passar num gate feito só de recusas.
mkdir -p "$T/real-comum"
oe="$(r "$T/real-comum")"
grep -q '^0|' <<<"$oe" \
  || { echo "FAIL [e]: um caminho absoluto, real, de dono correto e que NÃO é symlink foi recusado ('$oe') — a chave inteira ficou inerte"; exit 1; }
grep -qF "|$T/real-comum|" <<<"$oe" \
  || { echo "FAIL [e]: a raiz declarada não foi usada ('$oe')"; exit 1; }
grep -qi 'convergência declarada' <<<"$oe" \
  || { echo "FAIL [e]: o recibo perdeu a proveniência de convergência ('$oe') — a env significa ISOLAMENTO e a chave significa o OPOSTO, e reportar as duas igual faz o recibo mentir"; exit 1; }
echo "OK [e]"


scenario "[f] CONTROLE DE VACUIDADE: sem a chave, o default /tmp vale e ninguém é avisado de nada"
of="$(r "__SEM__")"
grep -q '^0|' <<<"$of" \
  || { echo "FAIL [f]: sem a chave o default deixou de valer ('$of')"; exit 1; }
grep -qF '|/tmp|default fixo /tmp' <<<"$of" \
  || { echo "FAIL [f]: sem a chave o recibo deixou de ser o do default ('$of') — e é ele que os outros cenários usam como contraste"; exit 1; }
grep -qiE 'inválido|invalido|symlink' <<<"$of" \
  && { echo "FAIL [f]: repositório que NÃO declara a chave recebeu aviso ('$of') — aviso que aparece sem problema é ruído, e ruído é o que ensina a ignorar aviso"; exit 1; }
echo "OK [f]"


[ "$SCENARIOS_RUN" -gt 0 ] \
  || { echo "FAIL [contador]: nenhum cenário executado — um gate que não roda nada não cobre nada"; exit 1; }
GATE_ELAPSED=$(( $(date +%s) - GATE_START ))
[ "$GATE_ELAPSED" -le "$GATE_BUDGET_S" ] \
  || { echo "FAIL [orçamento]: a suíte levou ${GATE_ELAPSED}s, acima do teto declarado de ${GATE_BUDGET_S}s"; exit 1; }
echo "PASS w154-heavy-mutex-yaml-root ($SCENARIOS_RUN cenário(s), ${GATE_ELAPSED}s de ${GATE_BUDGET_S}s)"
