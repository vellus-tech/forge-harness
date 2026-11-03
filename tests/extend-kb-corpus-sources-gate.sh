#!/usr/bin/env bash
# Gate único do change extend-kb-corpus-sources — cada TASK acrescenta seus casos aqui, nunca cria
# gate próprio (ver tasks.md). Grupos de cenário numerados continuamente, padrão `shell-gate`
# reconhecido por red-classify.mjs (`^FAIL \[[^\]\n]+\]`).
#
#   [1] (TASK-01) active-spec participa do mecanismo de staleness/fingerprint de ponta a ponta,
#       via comportamento observável de kb.sh (build/status/query) — nunca a função interna
#       sourceFiles(), que não é exportada (REQ-06).
#   [2]-[24] (TASK-02) kb.extra_paths: retrocompat, controles positivos, cada camada de validação
#       (sintaxe, resolução física/symlink, segurança de confinamento/overlap, allowlist), schema
#       e os dois casos de staleness de extra-path (ver tasks.md TASK-02 para a descrição completa
#       de cada caso, nesta ordem fixa).
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB="$WS/template/.forge/scripts/kb.sh"
T="$(mktemp -d /tmp/forge-extend-kb.XXXXXX)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL [$1] $2"; exit 1; }
ok() { echo "OK [$1]"; }

# [1]
R="$T/root"
mkdir -p "$R/.forge/specs/active/some-change"
printf '# Requirements\n\nTexto inicial da spec ativa.\n' > "$R/.forge/specs/active/some-change/requirements.md"

OUT1="$(FORGE_ROOT="$R" bash "$KB" build 2>&1)" || fail 1 "kb.sh build inicial falhou: $OUT1"

STATUS1="$(FORGE_ROOT="$R" bash "$KB" status --json 2>&1)" || fail 1 "kb.sh status --json inicial falhou: $STATUS1"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="atual") process.exit(1);' "$STATUS1" \
  || fail 1 "índice deveria estar atual logo após o build: $STATUS1"

printf '# Requirements\n\nTexto NOVO da spec ativa, editado entre dois builds.\n' > "$R/.forge/specs/active/some-change/requirements.md"

STATUS2="$(FORGE_ROOT="$R" bash "$KB" status --json 2>&1)" || fail 1 "kb.sh status --json após edição falhou: $STATUS2"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="defasado") process.exit(1);' "$STATUS2" \
  || fail 1 "status deveria reportar defasado após editar conteúdo active-spec sem rebuild: $STATUS2"

OUT2="$(FORGE_ROOT="$R" bash "$KB" build 2>&1)" || fail 1 "kb.sh build posterior à edição falhou: $OUT2"

QUERY="$(FORGE_ROOT="$R" bash "$KB" query "editado entre dois builds" --json 2>&1)" || fail 1 "kb.sh query falhou: $QUERY"
node -e '
const q = JSON.parse(process.argv[1]);
const hit = q.results.some((r) => r.doc === ".forge/specs/active/some-change/requirements.md");
if (!hit) process.exit(1);
' "$QUERY" || fail 1 "kb.sh query não reflete o texto novo da spec ativa após rebuild: $QUERY"

ok 1

# ---- Fixture compartilhada [2]-[16],[22]-[24]: sintaxe/segurança/allowlist de kb.extra_paths ----
# Cada caso reescreve .forge/forge.yaml (um glob por vez) e, quando aplicável, a allowlist — sem
# recriar o resto da árvore, que é compartilhada entre os casos desta seção.
R2="$T/extra"
LIB="$WS/template/.forge/scripts/lib"
mkdir -p "$R2/.forge/liaison/canal/log" "$R2/.forge/ledger" "$R2/docs/adr" "$R2/docs/plans/sub" "$R2/docs/runbooks"
printf '# Plano\n\nplano mestre\n' > "$R2/docs/plans/00-master.md"
printf '# Sub plano\n\nsub plano dentro de uma raiz ja coletada\n' > "$R2/docs/plans/sub/01-sub.md"
printf '# ADR extra\n\nTexto adr extra valido indexado via extra_paths.\n' > "$R2/docs/adr/0100-extra.md"
printf '# Runbook\n\nruniguebook sem allowlist.\n' > "$R2/docs/runbooks/00-run.md"
printf 'self:\n  id: eu\n' > "$R2/.forge/liaison/liaison.yaml"
printf -- '-----BEGIN PRIVATE KEY-----\nsegredo\n-----END PRIVATE KEY-----\n' > "$R2/docs/adr/segredo.pem"
# symlinks (relativos ao diretório onde o link vive, não à raiz do projeto)
ln -s ../.forge/liaison "$R2/docs/lnk-liaison"
ln -s .. "$R2/docs/lnk-root"
ln -s plans "$R2/docs/lnk-plans"
ln -s ../../.forge/liaison/liaison.yaml "$R2/docs/adr/lnk-liaison.md"
ln -s lnk-loop-b "$R2/docs/lnk-loop-a"
ln -s lnk-loop-a "$R2/docs/lnk-loop-b"

run2() { node --input-type=module -e "
import { collect } from '$LIB/kb-corpus.mjs';
const r = collect({ docRoot: process.argv[1] });
console.log(JSON.stringify(r));
" "$R2"; }
set_cfg() { # $1 glob, $2 linha de allowlist completa (ou vazio para omitir a allowlist)
  printf 'kb:\n  extra_paths:\n    - %s\n' "$1" > "$R2/.forge/forge.yaml"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" > "$R2/.forge/kb-extra-paths-allowlist.txt"; else rm -f "$R2/.forge/kb-extra-paths-allowlist.txt"; fi
}
assert_no_extra_path() {
  local n="$1" out
  out="$(run2)" || fail "$n" "collect() lançou erro"
  node -e 'const r=JSON.parse(process.argv[1]); if (r.docs.some((d) => d.kind === "extra-path")) process.exit(1);' "$out" \
    || fail "$n" "extra-path indexado quando deveria ser rejeitado: $out"
}
assert_extra_path() {
  local n="$1" id="$2" out
  out="$(run2)" || fail "$n" "collect() lançou erro"
  node -e 'const r=JSON.parse(process.argv[1]); if (!r.docs.some((d) => d.kind === "extra-path" && d.id === process.argv[2])) process.exit(1);' "$out" "$id" \
    || fail "$n" "extra-path esperado ausente: $id — $out"
}

# [2] retrocompat: ausência de forge.yaml, forge.yaml sem bloco kb, e kb.extra_paths: [] — nenhum
#     altera o comportamento atual (nenhum extra-path, sem erro).
rm -f "$R2/.forge/forge.yaml" "$R2/.forge/kb-extra-paths-allowlist.txt"
assert_no_extra_path 2
printf 'version: 1\n' > "$R2/.forge/forge.yaml"
assert_no_extra_path 2
printf 'kb:\n  extra_paths: []\n' > "$R2/.forge/forge.yaml"
assert_no_extra_path 2
ok 2

# [3] controle positivo: docs/adr/** aceito
set_cfg "docs/adr/**" "docs/adr/**  # motivo: controle positivo glob simples"
assert_extra_path 3 "docs/adr/0100-extra.md"
ok 3

# [4] controle positivo: docs/adr/**/*.md aceito (extensão explícita)
set_cfg "docs/adr/**/*.md" "docs/adr/**/*.md  # motivo: controle positivo com extensão"
assert_extra_path 4 "docs/adr/0100-extra.md"
ok 4

# [5] ./** e ** isolado rejeitados — mesma asserção de sintaxe para os dois
set_cfg "./**" "./**  # motivo: tentativa de prefixo relativo vazio"
assert_no_extra_path 5
set_cfg "**" "**  # motivo: tentativa de glob isolado"
assert_no_extra_path 5
ok 5

# [6] /etc/** rejeitado (prefixo absoluto)
set_cfg "/etc/**" "/etc/**  # motivo: tentativa de prefixo absoluto"
assert_no_extra_path 6
ok 6

# [7] docs/../docs/adr/** rejeitado (segmento ..)
set_cfg "docs/../docs/adr/**" "docs/../docs/adr/**  # motivo: tentativa de segmento .."
assert_no_extra_path 7
ok 7

# [8] .forge/** rejeitado (prefixo reservado, texto direto)
set_cfg ".forge/**" ".forge/**  # motivo: tentativa de prefixo reservado"
assert_no_extra_path 8
ok 8

# [9] .forge/liaison/** rejeitado (texto direto)
set_cfg ".forge/liaison/**" ".forge/liaison/**  # motivo: tentativa direta sobre o liaison"
assert_no_extra_path 9
ok 9

# [10] symlink docs/lnk-liaison -> ../.forge/liaison rejeitado (resolução física)
set_cfg "docs/lnk-liaison/**" "docs/lnk-liaison/**  # motivo: symlink commitado para .forge/liaison"
assert_no_extra_path 10
ok 10

# [11] symlink docs/lnk-root -> .. rejeitado (caminho relativo resultante vazio)
set_cfg "docs/lnk-root/**" "docs/lnk-root/**  # motivo: symlink commitado para a raiz do projeto"
assert_no_extra_path 11
ok 11

# [12] symlink de ARQUIVO interno a um diretório já aceito (docs/adr/lnk-liaison.md -> liaison.yaml)
#      nunca é indexado — walk() não segue symlink de arquivo, só a pasta de partida é resolvida.
set_cfg "docs/adr/**" "docs/adr/**  # motivo: controle positivo glob simples"
OUT12="$(run2)" || fail 12 "collect() lançou erro"
node -e '
const r = JSON.parse(process.argv[1]);
if (r.docs.some((d) => d.id === "docs/adr/lnk-liaison.md")) process.exit(1);
if (r.docs.some((d) => d.text.includes("self:"))) process.exit(1);
' "$OUT12" || fail 12 "symlink de arquivo interno a docs/adr foi indexado (deveria ser ignorado por walk())"
ok 12

# [13] docs/plans/sub/** rejeitado (overlap descendente de uma raiz já coletada)
set_cfg "docs/plans/sub/**" "docs/plans/sub/**  # motivo: tentativa de overlap descendente"
assert_no_extra_path 13
ok 13

# [14] symlink docs/lnk-plans -> docs/plans rejeitado (overlap via symlink)
set_cfg "docs/lnk-plans/**" "docs/lnk-plans/**  # motivo: symlink commitado para docs/plans"
assert_no_extra_path 14
ok 14

# [15] glob sem entrada na allowlist, OU entrada sem "# motivo:" — ignorado com aviso nos dois casos
printf 'kb:\n  extra_paths:\n    - docs/runbooks/**\n' > "$R2/.forge/forge.yaml"
rm -f "$R2/.forge/kb-extra-paths-allowlist.txt"
assert_no_extra_path 15
printf 'docs/runbooks/**  sem marcador de motivo aqui\n' > "$R2/.forge/kb-extra-paths-allowlist.txt"
assert_no_extra_path 15
ok 15

# [16] .FORGE/liaison/** — nunca indexado (case-insensitive: resolve para .forge/liaison via
#      realpathSync.native; case-sensitive: ENOENT e mesmo skip) — asserção única "nunca indexado"
set_cfg ".FORGE/liaison/**" ".FORGE/liaison/**  # motivo: tentativa com grafia case-insensitive"
assert_no_extra_path 16
ok 16

# [17] arquivo extra-path já indexado participa de staleness ponta a ponta: editar seu conteúdo
#      entre dois kb.sh build faz status reportar defasado, e um query DIRETO (sem build explícito)
#      já reflete o texto novo (REQ-06 critério 3 — reconstrução automática de loadIndex()).
R17="$T/extra17"
mkdir -p "$R17/docs/adr" "$R17/.forge"
printf '# ADR extra17\n\nTexto inicial do extra-path.\n' > "$R17/docs/adr/0100-extra.md"
printf 'kb:\n  extra_paths:\n    - docs/adr/**\n' > "$R17/.forge/forge.yaml"
printf 'docs/adr/**  # motivo: caso 17 de staleness\n' > "$R17/.forge/kb-extra-paths-allowlist.txt"
OUT17="$(FORGE_ROOT="$R17" bash "$KB" build 2>&1)" || fail 17 "kb.sh build inicial falhou: $OUT17"
STATUS17A="$(FORGE_ROOT="$R17" bash "$KB" status --json 2>&1)" || fail 17 "kb.sh status --json inicial falhou: $STATUS17A"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="atual") process.exit(1);' "$STATUS17A" \
  || fail 17 "índice deveria estar atual logo após o build: $STATUS17A"
printf '# ADR extra17\n\nTexto NOVO do extra-path, editado entre dois builds.\n' > "$R17/docs/adr/0100-extra.md"
STATUS17B="$(FORGE_ROOT="$R17" bash "$KB" status --json 2>&1)" || fail 17 "kb.sh status --json após edição falhou: $STATUS17B"
node -e 'const s=JSON.parse(process.argv[1]); if (s.index!=="defasado") process.exit(1);' "$STATUS17B" \
  || fail 17 "status deveria reportar defasado após editar conteúdo extra-path sem rebuild: $STATUS17B"
QUERY17="$(FORGE_ROOT="$R17" bash "$KB" query "editado entre dois builds" --json 2>/dev/null)" || fail 17 "kb.sh query falhou"
node -e '
const q = JSON.parse(process.argv[1]);
const hit = q.results.some((r) => r.doc === "docs/adr/0100-extra.md");
if (!hit) process.exit(1);
' "$QUERY17" || fail 17 "kb.sh query (sem build explícito) não reflete o texto novo do extra-path: $QUERY17"
ok 17

# [18] remover um arquivo extra-path já indexado faz o doc desaparecer do próximo índice.
OUT18="$(FORGE_ROOT="$R17" bash "$KB" build 2>&1)" || fail 18 "kb.sh build (pós-edição) falhou: $OUT18"
rm -f "$R17/docs/adr/0100-extra.md"
OUT18B="$(FORGE_ROOT="$R17" bash "$KB" build 2>&1)" || fail 18 "kb.sh build (pós-remoção) falhou: $OUT18B"
QUERY18="$(FORGE_ROOT="$R17" bash "$KB" query "editado entre dois builds" --json 2>&1)" || fail 18 "kb.sh query falhou: $QUERY18"
node -e '
const q = JSON.parse(process.argv[1]);
if (q.results.some((r) => r.doc === "docs/adr/0100-extra.md")) process.exit(1);
' "$QUERY18" || fail 18 "doc removido ainda aparece no índice após rebuild: $QUERY18"
ok 18

# [19]-[21] schema: forge.schema.json declara kb.extra_paths em forgeManifest, additionalProperties
#      false, extra_paths como array de string — via ajv (mesma convenção de tools/validate-forge.mjs
#      / tests/w20-spec-gate.sh caso [5]).
set +e
(cd "$WS" && node -e '
const Ajv2020 = require("ajv/dist/2020.js");
const { readFileSync } = require("node:fs");
const core = JSON.parse(readFileSync(process.argv[1], "utf8"));
const schema = { ...core.$defs.forgeManifest };
const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });
const validate = ajv.compile(schema);
const base = { version: 1, harness: { name: "forge", installed_at: "2026-01-01", template_version: "1.0.0", adapters: [] }, specs: { root: ".forge/specs", active: ".forge/specs/active", archived: ".forge/specs/archived", baseline: ".forge/product/current" } };

// [19] kb.extra_paths válido
const ok19 = { ...base, kb: { extra_paths: ["docs/adr/**"] } };
if (!validate(ok19)) { console.error("FAIL19", JSON.stringify(validate.errors)); process.exit(19); }

// [20] chave extra no bloco kb — additionalProperties:false deve reprovar
const bad20 = { ...base, kb: { extra_paths: ["x"], outra_chave: 1 } };
if (validate(bad20)) { console.error("FAIL20 deveria ter reprovado"); process.exit(20); }

// [21] kb.extra_paths não-array deve reprovar
const bad21 = { ...base, kb: { extra_paths: "x" } };
if (validate(bad21)) { console.error("FAIL21 deveria ter reprovado"); process.exit(21); }
console.log("OK schema kb.extra_paths (19-21)");
' "$WS/template/.forge/schemas/forge.schema.json")
RC=$?
set -e
case "$RC" in
  0) : ;;
  19) fail 19 "forge.yaml com kb.extra_paths válido deveria validar sem erro" ;;
  20) fail 20 "forge.yaml com chave extra em kb deveria falhar (additionalProperties: false)" ;;
  21) fail 21 "forge.yaml com kb.extra_paths não-array deveria falhar" ;;
  *) fail 19 "validação ajv do bloco kb falhou de forma inesperada (rc=$RC)" ;;
esac
ok 19
ok 20
ok 21

# [22] docs/adr/**/*.pem rejeitado (extensão fora de md/yaml/yml)
set_cfg "docs/adr/**/*.pem" "docs/adr/**/*.pem  # motivo: tentativa de extensão fora da lista permitida"
OUT22="$(run2)" || fail 22 "collect() lançou erro"
node -e 'const r=JSON.parse(process.argv[1]); if (r.docs.some((d) => d.id.endsWith(".pem"))) process.exit(1);' "$OUT22" \
  || fail 22 "arquivo .pem indexado via extra_paths: $OUT22"
ok 22

# [23] symlink em laço (ELOOP) gera erro distinto de ENOENT — skip, nunca "tratado como inexistente
#      e aceito por omissão".
set_cfg "docs/lnk-loop-a/**" "docs/lnk-loop-a/**  # motivo: symlink em laço (ELOOP)"
assert_no_extra_path 23
ok 23

# [24] docs/** (ancestral de docs/plans, já coletado como kind: plan) rejeitado por overlap
set_cfg "docs/**" "docs/**  # motivo: tentativa de overlap ancestral com docs/plans"
assert_no_extra_path 24
ok 24

echo "PASS extend-kb-corpus-sources (24 casos)"
