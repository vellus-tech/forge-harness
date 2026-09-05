#!/usr/bin/env bash
# Gate W194 — disciplina de escrita no ledger (issue #103 + LDG-0140).
#
# Três portas do mesmo arquivo (`ledger-ops.sh`) por onde entrava registro SEM CONTEÚDO enquanto o
# comando respondia `OK`:
#
#   (a) `update <id> --detail ""` imprimia "OK update — <id> atualizado", gravava o arquivo e
#       avançava `updated_at` sem alterar o campo, porque `if (de) e.detail = de;` trata string
#       vazia como falsa. O commit anunciava um conteúdo que o ledger não carrega.
#   (b) `update` que não muda nada devolvia `OK`: o único efeito garantido era mexer no
#       `updated_at`, o que faz a entrada PARECER recente sem carregar informação nova.
#   (c) os SEIS subcomandos terminavam o `case` de parsing em `*) shift ;;`, que engole a flag E,
#       na iteração seguinte, o VALOR dela. Um `--details "texto"` (typo) desaparecia inteiro e a
#       entrada nascia com `detail: ''` — com `OK` na saída. O idioma correto já existe no
#       repositório: `_reject_unknown` em `liaison-ops.sh:111`, 22 usos.
#
# E a etapa (3) do `harvest` casava QUALQUER bullet sob um heading que combinasse
# /desvios|ressalvas|observa/i, sem distinguir ressalva aberta de narrativa de algo já concluído —
# foi assim que nasceram LDG-0111..LDG-0114, 100% duplicadas de itens já resolvidos.
#
#   [1]  update --detail "" reprova, nomeia a flag, e o ledger.json fica byte a byte idêntico
#   [2]  update --title "" idem
#   [3]  update sem flag alguma reprova e não imprime OK
#   [4]  update --detail "texto" grava e imprime OK — o caminho feliz não regride (controle)
#   [5]  propriedade (OK implica gravação): rc=0 implica ao menos um campo de CONTEÚDO alterado
#   [6]  flag desconhecida em `add` reprova nomeando a flag, sem criar entrada
#   [7]  o mesmo para os outros cinco subcomandos, parametrizado
#   [8]  `add` sem --detail cria a entrada, imprime o id e AVISA que ela nasce sem conteúdo
#   [9]  harvest sobre bullet narrativo sob "Desvios e observações", sem marcador: zero entradas
#   [10] o mesmo com um bullet `PENDENTE:`: exatamente uma entrada
#   [11] bullet citando `LDG-00NN` é descartado mesmo com marcador
#   [12] contador de controle: harvest sobre change inexistente declara zero e não falha o caller
#   [12b] contador de controle DO PRÓPRIO GATE: a lista de subcomandos de [7] é contada e
#        declarada; lista vazia REPROVA (lib/gate-universe.sh)
#   [13] mutação: restaurar `if (de) e.detail = de;` faz [1] e [5] reprovarem; restaurar o
#        `*) shift ;;` faz [6] e [7] reprovarem; restauração verificada byte a byte com cmp
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w194.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# Teto de tempo em todo comando externo — idioma de check-push-ahead.sh / w157 (macOS não tem
# `timeout` de coreutils por padrão).
_run_to() { # _run_to <segundos> -- <cmd...>
  local secs="$1"; shift
  [ "${1:-}" = "--" ] && shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

# ── fixture viva: template completo sob git, para exercitar o script real ──────────────────────
cp -R "$WS/template/.forge" "$T/.forge"
git -C "$T" init -q
_run_to 20 -- git -C "$T" add -A
_run_to 20 -- git -C "$T" -c user.email=t@t -c user.name=t commit -qm init >/dev/null
LG="$T/.forge/scripts/ledger-ops.sh"
LF="$T/.forge/ledger/ledger.json"

_lg() { _run_to 20 -- env FORGE_ROOT="$T" bash "$LG" "$@"; }
_entries() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((d.entries||[]).length)' "$1"; }
_field_of() { node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(d.entries||[]).find(x=>x.id===process.argv[2]);process.stdout.write(e&&e[process.argv[3]]!=null?String(e[process.argv[3]]):"")' "$1" "$2" "$3"; }

_lg add --type known-bug --title "baseline do gate" --detail "conteúdo inicial" >/dev/null   # LDG-0001

echo "[1] update --detail \"\" reprova, nomeia a flag, ledger byte a byte idêntico"
cp "$LF" "$T/snap1.json"
set +e
out1="$(_lg update LDG-0001 --detail "" 2>&1)"; rc1=$?
set -e
[ "$rc1" -ne 0 ] || { echo "FAIL [1]: 'update --detail \"\"' devolveu rc=0 — got: $out1"; exit 1; }
grep -q -- "--detail" <<<"$out1" || { echo "FAIL [1]: a recusa não nomeia a flag '--detail' — got: $out1"; exit 1; }
cmp -s "$LF" "$T/snap1.json" || { echo "FAIL [1]: ledger.json foi alterado por um update recusado"; exit 1; }
echo "OK [1] — $out1"

echo "[2] update --title \"\" reprova, nomeia a flag, ledger byte a byte idêntico"
cp "$LF" "$T/snap2.json"
set +e
out2="$(_lg update LDG-0001 --title "" 2>&1)"; rc2=$?
set -e
[ "$rc2" -ne 0 ] || { echo "FAIL [2]: 'update --title \"\"' devolveu rc=0 — got: $out2"; exit 1; }
grep -q -- "--title" <<<"$out2" || { echo "FAIL [2]: a recusa não nomeia a flag '--title' — got: $out2"; exit 1; }
cmp -s "$LF" "$T/snap2.json" || { echo "FAIL [2]: ledger.json foi alterado por um update recusado"; exit 1; }
echo "OK [2] — $out2"

echo "[3] update sem flag alguma reprova e não imprime OK"
cp "$LF" "$T/snap3.json"
set +e
out3="$(_lg update LDG-0001 2>&1)"; rc3=$?
set -e
[ "$rc3" -ne 0 ] || { echo "FAIL [3]: 'update <id>' sem flag devolveu rc=0 — got: $out3"; exit 1; }
grep -q "^OK" <<<"$out3" && { echo "FAIL [3]: update sem flag imprimiu OK — got: $out3"; exit 1; }
cmp -s "$LF" "$T/snap3.json" || { echo "FAIL [3]: ledger.json foi alterado por um update sem flag"; exit 1; }
echo "OK [3] — $out3"

echo "[4] update --detail \"texto\" grava e imprime OK (controle: o caminho feliz não regride)"
set +e
out4="$(_lg update LDG-0001 --detail "detalhe novo do cenário 4" 2>&1)"; rc4=$?
set -e
[ "$rc4" -eq 0 ] || { echo "FAIL [4]: caminho feliz do update reprovou — got rc=$rc4: $out4"; exit 1; }
grep -q "^OK" <<<"$out4" || { echo "FAIL [4]: caminho feliz não imprimiu OK — got: $out4"; exit 1; }
got4="$(_field_of "$LF" LDG-0001 detail)"
[ "$got4" = "detalhe novo do cenário 4" ] || { echo "FAIL [4]: detail não gravado (got '$got4')"; exit 1; }
echo "OK [4] — detail='$got4'"

echo "[5] propriedade — rc=0 implica que ao menos um campo de CONTEÚDO mudou"
# Campos de conteúdo: title, detail, status, priority, severity. `updated_at` NÃO conta: mexer
# nele é justamente o efeito vazio que o defeito produzia.
_content_sig() { node -e '
  const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const e = (d.entries || []).find((x) => x.id === process.argv[2]) || {};
  process.stdout.write(JSON.stringify([e.title, e.detail, e.status, e.priority, e.severity]));
' "$1" "$2"; }

prop_n=0; prop_bad=0
# Cada linha: <rótulo>|<args separados por espaço, com \x1f entre eles>
PROP_CASES=(
  "detail-vazio|--detail|"
  "title-vazio|--title|"
  "priority-vazio|--priority|"
  "severity-vazio|--severity|"
  "status-vazio|--status|"
  "sem-flag|"
  "detail-novo|--detail|propriedade cenário 5 valor A"
  "detail-repetido|--detail|propriedade cenário 5 valor A"
  "priority-nova|--priority|P2"
  "priority-repetida|--priority|P2"
  "title-novo|--title|título da propriedade"
  "title-repetido|--title|título da propriedade"
)
for spec in "${PROP_CASES[@]}"; do
  IFS='|' read -r label f1 v1 <<<"$spec"
  args=(update LDG-0001)
  [ -z "$f1" ] || args+=("$f1" "${v1-}")
  before_sig="$(_content_sig "$LF" LDG-0001)"
  set +e
  outp="$(_lg "${args[@]}" 2>&1)"; rcp=$?
  set -e
  after_sig="$(_content_sig "$LF" LDG-0001)"
  prop_n=$((prop_n + 1))
  if [ "$rcp" -eq 0 ] && [ "$before_sig" = "$after_sig" ]; then
    echo "FAIL [5]: caso '$label' devolveu rc=0 sem alterar nenhum campo de conteúdo — got: $outp"
    prop_bad=$((prop_bad + 1))
  fi
done
[ "$prop_n" -gt 0 ] || { echo "FAIL [5]: matriz da propriedade vazia — o cenário não examinou nada"; exit 1; }
[ "$prop_bad" -eq 0 ] || { echo "FAIL [5]: $prop_bad de $prop_n casos violaram 'OK implica gravação'"; exit 1; }
echo "OK [5] — $prop_n casos de update examinados, 0 violações de 'OK implica gravação'"

echo "[6] flag desconhecida em 'add' reprova nomeando a flag, sem criar entrada"
before6="$(_entries "$LF")"
set +e
out6="$(_lg add --type known-bug --title "typo de flag" --details "conteúdo que sumiria" 2>&1)"; rc6=$?
set -e
[ "$rc6" -ne 0 ] || { echo "FAIL [6]: 'add --details' (typo) devolveu rc=0 — got: $out6"; exit 1; }
grep -q -- "--details" <<<"$out6" || { echo "FAIL [6]: a recusa não nomeia a flag desconhecida — got: $out6"; exit 1; }
after6="$(_entries "$LF")"
[ "$before6" = "$after6" ] || { echo "FAIL [6]: 'add' recusado mas criou entrada ($before6 -> $after6)"; exit 1; }
echo "OK [6] — $out6"

echo "[7] flag desconhecida nos outros cinco subcomandos (parametrizado)"
_lg add --type follow-up --title "alvo do cenário 7" --detail "conteúdo" >/dev/null   # LDG-0002
SUBCOMMANDS=(update resolve promote harvest list)
sub_n=0; sub_bad=0
for sub in "${SUBCOMMANDS[@]}"; do
  case "$sub" in
    update)  args=(update LDG-0002 --detail "x" --bogus-flag "valor engolido") ;;
    resolve) args=(resolve LDG-0002 --note "nota" --bogus-flag "valor engolido") ;;
    promote) args=(promote LDG-0002 --to ch-fake --bogus-flag "valor engolido") ;;
    harvest) args=(harvest ch-fake --origin close --bogus-flag "valor engolido") ;;
    list)    args=(list --status open --bogus-flag "valor engolido") ;;
  esac
  cp "$LF" "$T/snap7-$sub.json"
  set +e
  out7="$(_lg "${args[@]}" 2>&1)"; rc7=$?
  set -e
  sub_n=$((sub_n + 1))
  if [ "$rc7" -eq 0 ]; then
    echo "FAIL [7]: subcomando '$sub' engoliu '--bogus-flag' e devolveu rc=0 — got: $out7"
    sub_bad=$((sub_bad + 1))
    continue
  fi
  if ! grep -q -- "--bogus-flag" <<<"$out7"; then
    echo "FAIL [7]: subcomando '$sub' reprovou sem nomear '--bogus-flag' — got: $out7"
    sub_bad=$((sub_bad + 1))
    continue
  fi
  cmp -s "$LF" "$T/snap7-$sub.json" || {
    echo "FAIL [7]: subcomando '$sub' recusado mas alterou o ledger.json"
    sub_bad=$((sub_bad + 1))
  }
done
[ "$sub_bad" -eq 0 ] || { echo "FAIL [7]: $sub_bad de $sub_n subcomandos aceitaram flag desconhecida"; exit 1; }
echo "OK [7] — $sub_n subcomandos examinados, todos recusam flag desconhecida"

echo "[12b] contador de controle do próprio gate — a lista de [7] é contada e declarada"
# shellcheck source=/dev/null
. "$WS/template/.forge/scripts/lib/gate-universe.sh"
forge_universe_check "w194/subcomandos" "$sub_n" "subcomando(s) de ledger-ops" "cenário [7]" "$T" \
  || { echo "FAIL [12b]: lista de subcomandos vazia aprovaria [7] em silêncio"; exit 1; }
# contrapositiva: a guarda tem de REPROVAR quando a lista é vazia — sem isso ela é decoração
set +e
out12b="$(forge_universe_check "w194/subcomandos" 0 "subcomando(s) de ledger-ops" "contrapositiva" "$T" 2>&1)"; rc12b=$?
set -e
[ "$rc12b" -ne 0 ] || { echo "FAIL [12b]: universo vazio aprovou — got: $out12b"; exit 1; }
echo "OK [12b] — $sub_n subcomandos declarados; universo vazio reprova"

echo "[8] 'add' sem --detail cria a entrada, imprime o id e avisa que ela nasce sem conteúdo"
set +e
out8="$(_lg add --type feature-idea --title "entrada sem conteúdo" 2>&1)"; rc8=$?
set -e
[ "$rc8" -eq 0 ] || { echo "FAIL [8]: 'add' sem --detail deveria criar (aviso, não recusa) — got rc=$rc8: $out8"; exit 1; }
new_id8="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.entries[d.entries.length-1].id)' "$LF")"
grep -q "$new_id8" <<<"$out8" || { echo "FAIL [8]: saída não nomeia o id criado ($new_id8) — got: $out8"; exit 1; }
grep -qi "sem conteúdo\|sem --detail\|sem detail" <<<"$out8" || { echo "FAIL [8]: 'add' sem --detail não avisou que a entrada nasce sem conteúdo — got: $out8"; exit 1; }
echo "OK [8] — $out8"

# ── harvest: LDG-0140 ─────────────────────────────────────────────────────────────────────────
_mk_change() { # _mk_change <change-id> <corpo do verification.md via stdin>
  local id="$1" dir="$T/.forge/specs/active/$1"
  mkdir -p "$dir"
  cat > "$dir/verification.md"
}
_harvest_count() { # _harvest_count <change-id> -> nº de entradas criadas
  local id="$1" before after
  before="$(_entries "$LF")"
  _lg harvest "$id" --origin close >/dev/null 2>&1 || true
  after="$(_entries "$LF")"
  echo $((after - before))
}

echo "[9] harvest com bullet narrativo sem marcador: zero entradas"
_mk_change ch-narrativo <<'EOF'
# Verificação

## Desvios e observações

- O gate w120 foi renomeado para w121 durante a onda, e o tracker já reflete isso.
- A suíte rodou verde nas três máquinas de bancada.
EOF
n9="$(_harvest_count ch-narrativo)"
[ "$n9" -eq 0 ] || { echo "FAIL [9]: harvest criou $n9 entrada(s) a partir de bullets narrativos sem marcador"; exit 1; }
echo "OK [9] — 0 entradas de 2 bullets narrativos"

echo "[10] harvest com um bullet PENDENTE: exatamente uma entrada"
_mk_change ch-pendente <<'EOF'
# Verificação

## Desvios e observações

- O gate w120 foi renomeado para w121 durante a onda, e o tracker já reflete isso.
- PENDENTE: o validador de envelope ainda não cobre a exclusão mútua no schema.
EOF
n10="$(_harvest_count ch-pendente)"
[ "$n10" -eq 1 ] || { echo "FAIL [10]: harvest com um bullet PENDENTE criou $n10 entrada(s), esperado 1"; exit 1; }
echo "OK [10] — exatamente 1 entrada"

echo "[11] bullet citando \`LDG-00NN\` é descartado mesmo com marcador"
_mk_change ch-citando <<'EOF'
# Verificação

## Desvios e observações

- PENDENTE: acompanhar `LDG-0030`, que segue aberto e cobre exatamente este caso.
EOF
n11="$(_harvest_count ch-citando)"
[ "$n11" -eq 0 ] || { echo "FAIL [11]: harvest criou $n11 entrada(s) a partir de bullet que cita um LDG existente"; exit 1; }
echo "OK [11] — 0 entradas (dedupe por citação de LDG)"

echo "[12] contador de controle — harvest sobre change inexistente declara zero e não falha o caller"
set +e
out12="$(_lg harvest ch-que-nao-existe --origin close 2>&1)"; rc12=$?
set -e
[ "$rc12" -eq 0 ] || { echo "FAIL [12]: harvest de change inexistente falhou o caller (rc=$rc12) — got: $out12"; exit 1; }
grep -q "0 nova" <<<"$out12" || { echo "FAIL [12]: harvest de change inexistente não declarou zero — got: $out12"; exit 1; }
echo "OK [12] — $out12"

# ── [13] mutação ──────────────────────────────────────────────────────────────────────────────
echo "[13] mutação — reintroduzir cada defeito faz os cenários correspondentes reprovarem"
cp "$LG" "$T/ledger-ops.orig"
AG="$T/.forge/scripts/lib/arg-guards.sh"
cp "$AG" "$T/arg-guards.orig"

# [1] em uma linha. A asserção tem de ser a MESMA de [1] — rc≠0 E a mensagem nomeando a flag —,
# não só "rc≠0": medido nesta base, neutralizar a guarda de valor vazio ainda faz o comando
# reprovar, porque a detecção de no-op pega o mesmo caso um passo adiante (`--detail ""` não muda
# campo nenhum). Uma mutação medida só por rc seria satisfeita pela OUTRA guarda e provaria nada.
_empty_detail_rejects() {
  set +e
  local o r
  o="$(_lg update LDG-0001 --detail "" 2>&1)"; r=$?
  set -e
  [ "$r" -ne 0 ] && grep -q -- "--detail" <<<"$o"
}
_noop_update_rejects() { # [5] em uma linha: update que não muda nada tem de reprovar
  set +e
  local o r cur
  cur="$(_field_of "$LF" LDG-0001 detail)"
  o="$(_lg update LDG-0001 --detail "$cur" 2>&1)"; r=$?
  set -e
  [ "$r" -ne 0 ]
}

_empty_detail_rejects || { echo "FAIL [13a]: pré-condição — [1] não reprova antes da mutação"; exit 1; }
_noop_update_rejects || { echo "FAIL [13a]: pré-condição — [5] não reprova antes da mutação"; exit 1; }

# (a1) mutar a guarda de valor vazio (lib/arg-guards.sh): o único sítio que decide
perl -0pi -e 's/\[ -n "\$value" \] && return 0/return 0/' "$AG"
if _empty_detail_rejects; then
  echo "FAIL [13a]: neutralizar forge_require_value NÃO fez [1] reprovar — a guarda não é o que decide"
  exit 1
fi
cp "$T/arg-guards.orig" "$AG"
cmp -s "$AG" "$T/arg-guards.orig" || { echo "FAIL [13]: restauração de arg-guards.sh não bateu byte a byte"; exit 1; }
_empty_detail_rejects || { echo "FAIL [13a]: depois da restauração, [1] não voltou a reprovar"; exit 1; }

# (a2) mutar a detecção de no-op: restaurar o comportamento de "OK sem gravar"
perl -0pi -e "s/if \\(sig\\(\\) === before\\) \\{ console\\.error\\('NOCHANGE'\\); process\\.exit\\(3\\); \\}/;/" "$LG"
if _noop_update_rejects; then
  echo "FAIL [13a]: remover a detecção de no-op NÃO fez [5] reprovar"
  exit 1
fi
cp "$T/ledger-ops.orig" "$LG"
cmp -s "$LG" "$T/ledger-ops.orig" || { echo "FAIL [13]: restauração de ledger-ops.sh não bateu byte a byte"; exit 1; }
_noop_update_rejects || { echo "FAIL [13a]: depois da restauração, [5] não voltou a reprovar"; exit 1; }

# (b) mutar a recusa de flag desconhecida no `add`: voltar ao `*) shift ;;`
perl -0pi -e 's/\*\) _reject_unknown "add"[^\n]*\n/*) shift ;;\n/' "$LG"
set +e
out13b="$(_lg add --type known-bug --title "mutação 13b" --details "sumiria" 2>&1)"; rc13b=$?
set -e
[ "$rc13b" -eq 0 ] || { echo "FAIL [13b]: a mutação não reintroduziu o engolir de flag (rc=$rc13b) — got: $out13b"; exit 1; }
cp "$T/ledger-ops.orig" "$LG"
cmp -s "$LG" "$T/ledger-ops.orig" || { echo "FAIL [13]: restauração de ledger-ops.sh não bateu byte a byte"; exit 1; }
set +e
out13c="$(_lg add --type known-bug --title "recontrole 13b" --details "sumiria" 2>&1)"; rc13c=$?
set -e
[ "$rc13c" -ne 0 ] || { echo "FAIL [13b]: depois da restauração, [6] não voltou a reprovar — got: $out13c"; exit 1; }
echo "OK [13] — duas mutações reintroduziram os defeitos; restauração verificada com cmp"

echo "PASS w194-ledger-write-discipline"
