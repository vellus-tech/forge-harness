#!/usr/bin/env bash
# Gate W275 — `approval-log.sh` grava YAML válido (ou falha sem tocar o arquivo) e `spec-close.sh` repassa `--autonomous` (issue #188).
#
# POR QUE ESTE GATE EXISTE. O template de spec cria `approvals.yaml` com `approvals: []` literal, e o `approval-log.sh` anexava a primeira decisão logo abaixo dessa linha e respondia `OK` — um documento que nenhum parser YAML aceita, produzido no primeiro gate de todo change. O parser de subconjunto do harness (yaml-lite) é leniente e aceitava o arquivo corrompido, então nada na suíte percebia; o oráculo aqui é um parser YAML estrito e independente do script (PyYAML, ou o pacote `yaml` do workspace). Além disso o `spec-close.sh` não tinha como repassar `--autonomous`, e todo fechamento decidido pelo revisor autônomo saía com `decided_by` igual ao `git config user.name`.
#
#   [1]  approvals.yaml copiado de templates/spec (que traz `approvals: []` literal) + approval-log → rc 0, OK, YAML estrito válido, a entrada DENTRO da lista
#   [2]  `approvals: [] # comentário` e arquivo sem quebra de linha final → YAML válido, entrada dentro da lista
#   [3]  `approvals:` em bloco com uma entrada → anexa a segunda, a primeira preservada (controle: o formato que já funcionava continua funcionando)
#   [4]  approvals.yaml ausente → criado válido (controle)
#   [5]  escrita que geraria YAML inválido (lista inline não vazia; chave escalar depois da lista) → rc != 0, sem OK, FAIL, arquivo byte-idêntico, sem temporário residual, gate do manifest intocado
#   [6]  spec-close --autonomous → entrada close com autonomous: true e decided_by do decisor autônomo, nunca o git user; sem a flag, decided_by é o git user (controle)
#   [7]  spec-close --autonomous com close em human_hard_stops → falha VISÍVEL (a mensagem do approval-log aparece), change continua ativo
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w275.XXXXXX")"
trap 'rm -rf "$T"' EXIT

FALHAS=0
falha() { echo "FAIL $*"; FALHAS=$((FALHAS + 1)); }

# Oráculo YAML estrito, independente do script sob teste. Imprime o documento como JSON ou sai != 0.
ORACULO=""
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  ORACULO=python
elif [ -d "$WS/node_modules/yaml" ]; then
  ORACULO=node
fi
[ -n "$ORACULO" ] || { echo "FAIL (sem oráculo YAML estrito: instale pyyaml ou rode npm ci)"; exit 1; }
yaml_json() {
  if [ "$ORACULO" = python ]; then
    python3 -c 'import sys,json,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1])), default=str))' "$1" 2>/dev/null
  else
    (cd "$WS" && node --input-type=module -e 'import {readFileSync} from "node:fs"; import {parse} from "yaml"; console.log(JSON.stringify(parse(readFileSync(process.argv[1],"utf8"))))' "$1" 2>/dev/null)
  fi
}
# jq-less: extrai campo via node sobre o JSON do oráculo. $1 = json, $2 = expressão JS sobre `d`.
jget() { node -e 'const d=JSON.parse(process.argv[1]); let v; try { v=eval(process.argv[2]); } catch { v=undefined; } console.log(typeof v==="object"?JSON.stringify(v):String(v))' "$1" "$2"; }

cp -R "$WS/template/.forge" "$T/.forge"
(cd "$T" && git init -q && git config user.name "Humano Fixture" && git config user.email h@fixture.invalid)
SN="$T/.forge/scripts/spec-new.sh"; AL="$T/.forge/scripts/approval-log.sh"; CL="$T/.forge/scripts/spec-close.sh"
ACT="$T/.forge/specs/active"
novo() { (cd "$T" && bash "$SN" "$1" --type feature --scale 1 >"$T/sn-$1.log" 2>&1) || { echo "FAIL (spec-new $1)"; tail -5 "$T/sn-$1.log"; exit 1; }; }
log() { (cd "$T" && bash "$AL" "$@" 2>&1); }

echo "[1] approvals: [] do template + approval-log → entrada dentro da lista"
novo chg-a
# O spec-new não cria approvals.yaml; quem cria é o agente de escrita de spec, a partir deste template.
cp "$T/.forge/templates/spec/approvals.yaml" "$ACT/chg-a/approvals.yaml"
grep -q '^approvals: \[\]$' "$ACT/chg-a/approvals.yaml" || falha "[1] pré-condição: o template não traz mais 'approvals: []' literal (reveja o gate)"
out="$(log chg-a --gate requirements_reviewed --decision approve)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK chg-a' || falha "[1] approval-log rc=$rc: $out"
j="$(yaml_json "$ACT/chg-a/approvals.yaml")" || falha "[1] approvals.yaml não parseia como YAML estrito: $(cat "$ACT/chg-a/approvals.yaml")"
if [ -n "${j:-}" ]; then
  [ "$(jget "$j" 'd.approvals.length')" = 1 ] || falha "[1] lista approvals não tem 1 entrada: $j"
  [ "$(jget "$j" 'd.approvals[0].gate')" = requirements_reviewed ] || falha "[1] entrada fora da lista ou gate errado: $j"
fi
echo "[1] fim"

echo "[2] variantes: '[] # comentário' e arquivo sem quebra de linha final"
novo chg-b
printf '# log\napprovals: []   # nenhum gate ainda\n' > "$ACT/chg-b/approvals.yaml"
out="$(log chg-b --gate requirements_reviewed --decision review --reason 'falta REQ-3')"; rc=$?
[ "$rc" -eq 0 ] || falha "[2a] rc=$rc: $out"
j="$(yaml_json "$ACT/chg-b/approvals.yaml")" || falha "[2a] YAML inválido: $(cat "$ACT/chg-b/approvals.yaml")"
[ -n "${j:-}" ] && { [ "$(jget "$j" 'd.approvals[0].decision')" = review ] || falha "[2a] entrada fora da lista: $j"; }
printf 'approvals:\n  - gate: requirements_reviewed\n    decision: approve\n    decided_by: "x"' > "$ACT/chg-b/approvals.yaml"
out="$(log chg-b --gate design_reviewed --decision approve)"; rc=$?
[ "$rc" -eq 0 ] || falha "[2b] rc=$rc: $out"
j="$(yaml_json "$ACT/chg-b/approvals.yaml")" || falha "[2b] YAML inválido: $(cat "$ACT/chg-b/approvals.yaml")"
if [ -n "${j:-}" ]; then
  [ "$(jget "$j" 'd.approvals.length')" = 2 ] || falha "[2b] esperava 2 entradas: $j"
  [ "$(jget "$j" 'd.approvals[0].decided_by')" = x ] || falha "[2b] entrada anterior corrompida: $j"
fi
echo "[2] fim"

echo "[3] approvals: em bloco com entrada existente → anexa (controle)"
novo chg-c
printf 'approvals:\n  - gate: requirements_reviewed\n    decision: approve\n    decided_by: "Fulana"\n' > "$ACT/chg-c/approvals.yaml"
out="$(log chg-c --gate design_reviewed --decision reject --reason 'acoplamento')"; rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^OK chg-c' || falha "[3] rc=$rc: $out"
j="$(yaml_json "$ACT/chg-c/approvals.yaml")" || falha "[3] YAML inválido"
if [ -n "${j:-}" ]; then
  [ "$(jget "$j" 'd.approvals.length')" = 2 ] || falha "[3] esperava 2 entradas: $j"
  [ "$(jget "$j" 'd.approvals[0].decided_by')" = Fulana ] || falha "[3] primeira entrada alterada: $j"
  [ "$(jget "$j" 'd.approvals[1].decision')" = reject ] || falha "[3] segunda entrada errada: $j"
fi
echo "[3] fim"

echo "[4] approvals.yaml ausente → criado válido (controle)"
novo chg-d
rm -f "$ACT/chg-d/approvals.yaml"
out="$(log chg-d --gate requirements_reviewed --decision approve)"; rc=$?
[ "$rc" -eq 0 ] || falha "[4] rc=$rc: $out"
j="$(yaml_json "$ACT/chg-d/approvals.yaml")" || falha "[4] YAML inválido"
[ -n "${j:-}" ] && { [ "$(jget "$j" 'd.approvals[0].gate')" = requirements_reviewed ] || falha "[4] entrada errada: $j"; }
echo "[4] fim"

echo "[5] escrita que geraria YAML inválido → rc != 0, sem OK, arquivo intocado"
novo chg-e
n_casos=0
for caso in inline-nao-vazia chave-depois-da-lista; do
  case "$caso" in
    inline-nao-vazia) printf '# legado\napprovals: [legado]\n' > "$ACT/chg-e/approvals.yaml" ;;
    chave-depois-da-lista) printf 'approvals:\n  - gate: requirements_reviewed\n    decision: approve\nobservacao: manual\n' > "$ACT/chg-e/approvals.yaml" ;;
  esac
  cp "$ACT/chg-e/approvals.yaml" "$T/antes.yaml"; cp "$ACT/chg-e/manifest.yaml" "$T/man-antes.yaml"
  out="$(log chg-e --gate requirements_reviewed --decision approve)"; rc=$?
  [ "$rc" -ne 0 ] || falha "[5 $caso] approval-log saiu rc 0 com YAML inválido: $out"
  printf '%s\n' "$out" | grep -q '^OK ' && falha "[5 $caso] reportou OK: $out"
  printf '%s\n' "$out" | grep -q '^FAIL' || falha "[5 $caso] sem linha FAIL explicando: $out"
  cmp -s "$T/antes.yaml" "$ACT/chg-e/approvals.yaml" || falha "[5 $caso] approvals.yaml alterado apesar da falha: $(cat "$ACT/chg-e/approvals.yaml")"
  cmp -s "$T/man-antes.yaml" "$ACT/chg-e/manifest.yaml" || falha "[5 $caso] manifest alterado apesar da falha"
  resid="$(find "$ACT/chg-e" -name '.approvals*' | wc -l | tr -d ' ')"
  [ "$resid" = 0 ] || falha "[5 $caso] $resid temporário(s) residual(is) na pasta do change"
  n_casos=$((n_casos + 1))
done
[ "$n_casos" -eq 2 ] || falha "[5] contador de controle: esperava 2 casos, rodou $n_casos"
echo "[5] fim"

echo "[6] spec-close --autonomous → autonomous: true e decided_by do decisor autônomo"
novo chg-f
out="$(cd "$T" && bash "$CL" chg-f --reason abandoned --note 'escopo absorvido por chg-x' --autonomous 2>&1)"; rc=$?
ARCH="$T/.forge/specs/archived/$(date +%F)-chg-f"
[ "$rc" -eq 0 ] && [ -d "$ARCH" ] || falha "[6] spec-close --autonomous rc=$rc: $out"
if [ -f "$ARCH/approvals.yaml" ]; then
  j="$(yaml_json "$ARCH/approvals.yaml")" || falha "[6] YAML inválido no close: $(cat "$ARCH/approvals.yaml")"
  if [ -n "${j:-}" ]; then
    [ "$(jget "$j" 'd.approvals.at(-1).gate')" = close ] || falha "[6] última entrada não é o close: $j"
    [ "$(jget "$j" 'd.approvals.at(-1).autonomous')" = true ] || falha "[6] close autônomo sem autonomous: true: $j"
    by="$(jget "$j" 'd.approvals.at(-1).decided_by')"
    [ "$by" = "forge-yolo (opus, high)" ] || falha "[6] decided_by='$by' (esperava o decisor autônomo, nunca o git user)"
  fi
fi
novo chg-g
out="$(cd "$T" && bash "$CL" chg-g --reason abandoned --note 'decisão humana' 2>&1)"; rc=$?
ARCH="$T/.forge/specs/archived/$(date +%F)-chg-g"
[ "$rc" -eq 0 ] || falha "[6 controle] close humano rc=$rc: $out"
j="$(yaml_json "$ARCH/approvals.yaml")" || falha "[6 controle] YAML inválido"
if [ -n "${j:-}" ]; then
  [ "$(jget "$j" 'd.approvals.at(-1).decided_by')" = "Humano Fixture" ] || falha "[6 controle] close humano sem o git user: $j"
  [ "$(jget "$j" 'd.approvals.at(-1).autonomous')" = undefined ] || falha "[6 controle] close humano marcado autonomous: $j"
fi
echo "[6] fim"

echo "[7] spec-close --autonomous com close em human_hard_stops → falha visível, change ativo"
novo chg-h
perl -0pi -e 's/(  human_hard_stops:\n)/$1    - close\n/' "$T/.forge/forge.yaml"
grep -q '^    - close$' "$T/.forge/forge.yaml" || falha "[7] pré-condição: não consegui pôr close em human_hard_stops"
out="$(cd "$T" && bash "$CL" chg-h --reason abandoned --note 'tentativa autônoma' --autonomous 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || falha "[7] close autônomo passou por cima do hard-stop: $out"
printf '%s\n' "$out" | grep -q 'human_hard_stops' || falha "[7] falha muda — a razão do approval-log não apareceu: '$out'"
[ -d "$ACT/chg-h" ] || falha "[7] change saiu de active/ apesar da recusa"
echo "[7] fim"

if [ "$FALHAS" -gt 0 ]; then echo "FAIL ($FALHAS falha(s))"; exit 1; fi
echo "OK"
