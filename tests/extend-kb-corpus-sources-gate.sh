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
#   [25]-[27] (TASK-03) countKinds compartilhada em status/build: kinds.active-spec sempre presente
#       quando elegível, kinds['extra-path'] = 0 explícito quando configurado e vazio (ausente
#       quando não configurado), e a saída texto de build lista a contagem por fonte.
#   [28]-[35] (TASK-04) status MADR extraído de `- **Status:**` (primeiro termo, pontuação final
#       removida, variantes PT-BR mapeadas) e exposto em kb.sh query — rótulo [SUPERSEDED]/
#       [DEPRECATED]/[REJECTED] na saída texto, campo `status` estruturado no --json; `kind` sempre
#       exposto; bump de INDEX_FORMAT (3→4) força reconstrução automática de índice antigo.
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

# ---- (TASK-03) [25]-[27]: contagem por fonte compartilhada (countKinds) em status/build ----

# [25] kb.sh status --json inclui kinds.active-spec sempre que existir ao menos uma spec ativa
#      elegível no repositório.
R25="$T/count25"
mkdir -p "$R25/.forge/specs/active/some-change"
printf '# Requirements\n\nSpec ativa elegível para contagem por fonte.\n' > "$R25/.forge/specs/active/some-change/requirements.md"
STATUS25="$(FORGE_ROOT="$R25" bash "$KB" status --json 2>&1)" || fail 25 "kb.sh status --json falhou: $STATUS25"
node -e '
const s = JSON.parse(process.argv[1]);
if (!(Number.isInteger(s.kinds["active-spec"]) && s.kinds["active-spec"] > 0)) process.exit(1);
' "$STATUS25" || fail 25 "kinds.active-spec ausente ou não positivo: $STATUS25"
ok 25

# [26] kinds['extra-path'] aparece como 0 explícito quando kb.extra_paths está configurado mas
#      resultou em zero documentos (glob sintaticamente válido, sem match físico) — e AUSENTE
#      quando extra_paths não está configurado (retrocompat preservada).
R26="$T/count26"
mkdir -p "$R26/.forge"
printf 'kb:\n  extra_paths:\n    - docs/missing/**\n' > "$R26/.forge/forge.yaml"
printf 'docs/missing/**  # motivo: caso 26 — configurado, zero match\n' > "$R26/.forge/kb-extra-paths-allowlist.txt"
STATUS26A="$(FORGE_ROOT="$R26" bash "$KB" status --json 2>&1)" || fail 26 "kb.sh status --json (configurado) falhou: $STATUS26A"
node -e '
const s = JSON.parse(process.argv[1]);
if (!("extra-path" in s.kinds) || s.kinds["extra-path"] !== 0) process.exit(1);
' "$STATUS26A" || fail 26 "kinds[extra-path] deveria ser 0 explícito quando configurado sem match: $STATUS26A"
rm -f "$R26/.forge/forge.yaml" "$R26/.forge/kb-extra-paths-allowlist.txt"
STATUS26B="$(FORGE_ROOT="$R26" bash "$KB" status --json 2>&1)" || fail 26 "kb.sh status --json (não configurado) falhou: $STATUS26B"
node -e '
const s = JSON.parse(process.argv[1]);
if ("extra-path" in s.kinds) process.exit(1);
' "$STATUS26B" || fail 26 "kinds não deveria ter extra-path quando kb.extra_paths não está configurado: $STATUS26B"
ok 26

# [27] kb.sh build (saída texto, sem --json) lista a contagem por fonte na mesma linha do total.
R27="$T/count27"
mkdir -p "$R27/.forge/specs/active/some-change"
printf '# Requirements\n\nSpec ativa elegível para a saída texto de build.\n' > "$R27/.forge/specs/active/some-change/requirements.md"
BUILD27="$(FORGE_ROOT="$R27" bash "$KB" build 2>&1)" || fail 27 "kb.sh build falhou: $BUILD27"
LINE27="$(printf '%s\n' "$BUILD27" | grep 'documentos' || true)"
[ -n "$LINE27" ] || fail 27 "linha de total de documentos não encontrada na saída de build: $BUILD27"
case "$LINE27" in
  *"active-spec="*) : ;;
  *) fail 27 "contagem por fonte (active-spec=) ausente na mesma linha do total de build: $LINE27" ;;
esac
ok 27

# ---- (TASK-04) [28]-[35]: status MADR extraído e rotulo de origem em kb.sh query -------------
R28="$T/madr"
mkdir -p "$R28/.forge/product/current/adr" "$R28/.forge/specs/active/some-change"
printf '# ADR accepted\n\n- **Status:** accepted\n\nTexto do ADR accepted sem rotulo.\n' \
  > "$R28/.forge/product/current/adr/0001-accepted.md"
printf '# ADR accepted com sufixo\n\n- **Status:** accepted — gate `design_reviewed` aprovado para algo.\n\nTexto do ADR accepted com sufixo.\n' \
  > "$R28/.forge/product/current/adr/0002-accepted-suffix.md"
printf '# ADR superseded\n\n- **Status:** Superseded by [ADR-0099]\n\nTexto do ADR superseded.\n' \
  > "$R28/.forge/product/current/adr/0003-superseded.md"
printf '# ADR deprecated\n\n- **Status:** deprecated.\n\nTexto do ADR deprecated com pontuacao colada.\n' \
  > "$R28/.forge/product/current/adr/0004-deprecated.md"
printf '# ADR rejected\n\n- **Status:** rejected,\n\nTexto do ADR rejected com pontuacao colada.\n' \
  > "$R28/.forge/product/current/adr/0005-rejected.md"
printf '# ADR suplantado\n\n- **Status:** Suplantado\n\nTexto do ADR suplantado pt-br.\n' \
  > "$R28/.forge/product/current/adr/0006-pt-suplantado.md"
printf '# ADR depreciado\n\n- **Status:** Depreciado\n\nTexto do ADR depreciado pt-br.\n' \
  > "$R28/.forge/product/current/adr/0007-pt-depreciado.md"
printf '# ADR rejeitado\n\n- **Status:** Rejeitado\n\nTexto do ADR rejeitado pt-br.\n' \
  > "$R28/.forge/product/current/adr/0008-pt-rejeitado.md"
printf '# ADR aceito\n\n- **Status:** Aceito\n\nTexto do ADR aceito pt-br.\n' \
  > "$R28/.forge/product/current/adr/0009-pt-aceito.md"
printf '# Notas\n\nDocumento nao-ADR sem cabecalho de status, para o caso 31.\n' \
  > "$R28/.forge/product/current/notas.md"
printf '# Requirements\n\nTexto exclusivo da spec ativa para TASK-04 (caso 32).\n' \
  > "$R28/.forge/specs/active/some-change/requirements.md"

BUILD28="$(FORGE_ROOT="$R28" bash "$KB" build 2>&1)" || fail 28 "kb.sh build do fixture MADR falhou: $BUILD28"

qjson() { FORGE_ROOT="$R28" bash "$KB" query "$1" --top 50 --json 2>&1; }
qtext() { FORGE_ROOT="$R28" bash "$KB" query "$1" --top 50 2>&1; }

# [28] ADR accepted sem rótulo: nem em texto, nem como status in {superseded,deprecated,rejected}
Q28="$(qjson 'Texto do ADR accepted sem rotulo')" || fail 28 "query falhou: $Q28"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0001-accepted.md");
if (!r) process.exit(1);
if (["superseded", "deprecated", "rejected"].includes(r.status)) process.exit(1);
' "$Q28" || fail 28 "ADR accepted com status indevido: $Q28"
T28="$(qtext 'Texto do ADR accepted sem rotulo')" || fail 28 "query texto falhou: $T28"
L28="$(printf '%s\n' "$T28" | grep '0001-accepted.md' || true)"
[ -n "$L28" ] || fail 28 "ADR accepted nao apareceu na saida texto: $T28"
case "$L28" in *"[SUPERSEDED]"*|*"[DEPRECATED]"*|*"[REJECTED]"*) fail 28 "rotulo indevido em ADR accepted: $L28" ;; esac
ok 28

# [29] ADR accepted com sufixo depois de "accepted" ainda classificado como accepted (sem rótulo) —
#      prova de que só o primeiro termo após "Status:" é usado.
Q29="$(qjson 'Texto do ADR accepted com sufixo')" || fail 29 "query falhou: $Q29"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0002-accepted-suffix.md");
if (!r) process.exit(1);
if (["superseded", "deprecated", "rejected"].includes(r.status)) process.exit(1);
' "$Q29" || fail 29 "ADR accepted com sufixo classificado com status indevido: $Q29"
T29="$(qtext 'Texto do ADR accepted com sufixo')" || fail 29 "query texto falhou: $T29"
L29="$(printf '%s\n' "$T29" | grep '0002-accepted-suffix.md' || true)"
[ -n "$L29" ] || fail 29 "ADR accepted com sufixo nao apareceu na saida texto: $T29"
case "$L29" in *"[SUPERSEDED]"*|*"[DEPRECATED]"*|*"[REJECTED]"*) fail 29 "rotulo indevido em ADR accepted com sufixo: $L29" ;; esac
ok 29

# [30] ADR superseded com rótulo [SUPERSEDED] em texto E campo status:"superseded" em --json.
Q30="$(qjson 'Texto do ADR superseded')" || fail 30 "query falhou: $Q30"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0003-superseded.md");
if (!r || r.status !== "superseded") process.exit(1);
' "$Q30" || fail 30 "ADR superseded sem status=superseded em --json: $Q30"
T30="$(qtext 'Texto do ADR superseded')" || fail 30 "query texto falhou: $T30"
L30="$(printf '%s\n' "$T30" | grep '0003-superseded.md' || true)"
case "$L30" in *"[SUPERSEDED]"*) : ;; *) fail 30 "rotulo [SUPERSEDED] ausente na saida texto: $L30" ;; esac
ok 30

# [31] documento não-ADR sem campo status (ausente ou null), sem erro; kind sempre presente.
Q31="$(qjson 'Documento nao-ADR sem cabecalho de status, para o caso 31')" || fail 31 "query falhou: $Q31"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/notas.md");
if (!r) process.exit(1);
if (r.kind !== "baseline") process.exit(1);
if ("status" in r && r.status) process.exit(1);
' "$Q31" || fail 31 "documento nao-ADR com status indevido, ou kind ausente: $Q31"
ok 31

# [32] resultado de active-spec sempre traz kind: 'active-spec' em --json (campo estruturado,
#      design §2.4/REQ-01) — sem rótulo de status (não é ADR) nem em texto.
Q32="$(qjson 'Texto exclusivo da spec ativa para TASK-04 (caso 32)')" || fail 32 "query falhou: $Q32"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/specs/active/some-change/requirements.md");
if (!r || r.kind !== "active-spec") process.exit(1);
' "$Q32" || fail 32 "resultado de active-spec sem kind: active-spec em --json: $Q32"
T32="$(qtext 'Texto exclusivo da spec ativa para TASK-04 (caso 32)')" || fail 32 "query texto falhou: $T32"
L32="$(printf '%s\n' "$T32" | grep 'some-change/requirements.md' || true)"
[ -n "$L32" ] || fail 32 "active-spec nao apareceu na saida texto: $T32"
case "$L32" in *"[SUPERSEDED]"*|*"[DEPRECATED]"*|*"[REJECTED]"*) fail 32 "rotulo de status indevido em active-spec: $L32" ;; esac
ok 32

# [33] índice construído ANTES deste change (format: 3) é reconstruído automaticamente no próximo
#      build/query — prova do bump de INDEX_FORMAT 3→4.
R33="$T/fmt33"
mkdir -p "$R33/.forge/product/current/adr"
printf '# ADR fmt33\n\n- **Status:** accepted\n\nTexto fmt33 para bump de index format.\n' \
  > "$R33/.forge/product/current/adr/0001-fmt33.md"
FORGE_ROOT="$R33" bash "$KB" build >/dev/null 2>&1 || fail 33 "build inicial falhou"
IDXFILE="$R33/.forge/kb/index.json"
node -e '
const fs = require("node:fs");
const p = process.argv[1];
const idx = JSON.parse(fs.readFileSync(p, "utf8"));
idx.format = 3;
fs.writeFileSync(p, JSON.stringify(idx) + "\n");
' "$IDXFILE" || fail 33 "falha ao simular indice de formato 3"
QUERY33="$(FORGE_ROOT="$R33" bash "$KB" query "fmt33 para bump de index" --json 2>&1)" \
  || fail 33 "query apos downgrade de formato falhou: $QUERY33"
node -e '
const q = JSON.parse(process.argv[1]);
if (q.rebuilt !== true) process.exit(1);
' "$QUERY33" || fail 33 "indice de formato 3 nao foi reconstruido automaticamente: $QUERY33"
node -e '
const fs = require("node:fs");
const idx = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (idx.format !== 4) process.exit(1);
' "$IDXFILE" || fail 33 "indice apos reconstrucao automatica nao esta no format 4"
ok 33

# [34] deprecated./rejected, (pontuação colada) classificados corretamente — prova do strip de
#      pontuação final antes do mapeamento.
Q34D="$(qjson 'Texto do ADR deprecated com pontuacao colada')" || fail 34 "query deprecated falhou: $Q34D"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0004-deprecated.md");
if (!r || r.status !== "deprecated") process.exit(1);
' "$Q34D" || fail 34 "ADR deprecated (pontuacao colada) sem status=deprecated: $Q34D"
T34D="$(qtext 'Texto do ADR deprecated com pontuacao colada')" || fail 34 "query texto deprecated falhou: $T34D"
L34D="$(printf '%s\n' "$T34D" | grep '0004-deprecated.md' || true)"
case "$L34D" in *"[DEPRECATED]"*) : ;; *) fail 34 "rotulo [DEPRECATED] ausente: $L34D" ;; esac
Q34R="$(qjson 'Texto do ADR rejected com pontuacao colada')" || fail 34 "query rejected falhou: $Q34R"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0005-rejected.md");
if (!r || r.status !== "rejected") process.exit(1);
' "$Q34R" || fail 34 "ADR rejected (pontuacao colada) sem status=rejected: $Q34R"
T34R="$(qtext 'Texto do ADR rejected com pontuacao colada')" || fail 34 "query texto rejected falhou: $T34R"
L34R="$(printf '%s\n' "$T34R" | grep '0005-rejected.md' || true)"
case "$L34R" in *"[REJECTED]"*) : ;; *) fail 34 "rotulo [REJECTED] ausente: $L34R" ;; esac
ok 34

# [35] as 4 variantes PT-BR mapeadas para o status em inglês correto, inclusive Aceito → accepted
#      (sem rótulo).
Q35SUP="$(qjson 'Texto do ADR suplantado pt-br')" || fail 35 "query suplantado falhou: $Q35SUP"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0006-pt-suplantado.md");
if (!r || r.status !== "superseded") process.exit(1);
' "$Q35SUP" || fail 35 "Suplantado nao mapeado para superseded: $Q35SUP"
Q35DEP="$(qjson 'Texto do ADR depreciado pt-br')" || fail 35 "query depreciado falhou: $Q35DEP"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0007-pt-depreciado.md");
if (!r || r.status !== "deprecated") process.exit(1);
' "$Q35DEP" || fail 35 "Depreciado nao mapeado para deprecated: $Q35DEP"
Q35REJ="$(qjson 'Texto do ADR rejeitado pt-br')" || fail 35 "query rejeitado falhou: $Q35REJ"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0008-pt-rejeitado.md");
if (!r || r.status !== "rejected") process.exit(1);
' "$Q35REJ" || fail 35 "Rejeitado nao mapeado para rejected: $Q35REJ"
Q35ACE="$(qjson 'Texto do ADR aceito pt-br')" || fail 35 "query aceito falhou: $Q35ACE"
node -e '
const q = JSON.parse(process.argv[1]);
const r = q.results.find((x) => x.doc === ".forge/product/current/adr/0009-pt-aceito.md");
if (!r) process.exit(1);
if (["superseded", "deprecated", "rejected"].includes(r.status)) process.exit(1);
' "$Q35ACE" || fail 35 "Aceito classificado com status indevido: $Q35ACE"
T35ACE="$(qtext 'Texto do ADR aceito pt-br')" || fail 35 "query texto aceito falhou: $T35ACE"
L35ACE="$(printf '%s\n' "$T35ACE" | grep '0009-pt-aceito.md' || true)"
case "$L35ACE" in *"[SUPERSEDED]"*|*"[DEPRECATED]"*|*"[REJECTED]"*) fail 35 "rotulo indevido em Aceito: $L35ACE" ;; esac
ok 35

echo "PASS extend-kb-corpus-sources (35 casos)"
