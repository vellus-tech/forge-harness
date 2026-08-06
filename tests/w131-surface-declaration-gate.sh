#!/usr/bin/env bash
# Gate W131 — fechar as duas portas de saída por omissão.
#
# A Onda A converteu em script os checks que o harness já especificava. Mas um check que só roda
# quando o change se declara sujeito a ele é um check opcional, e a omissão acontece justamente no
# change grande: o maior change de API do repositório que motivou este trabalho NÃO declara
# `affects_surfaces`, e por isso nunca foi obrigado a preencher o mapa endpoint→ação→recurso→policy.
# Duas portas, dois checks:
#
#   SRF-00 — o change TOCA superfície de API e não a DECLARA. Sem isso, todo o resto é opt-out por
#            omissão: basta não escrever `affects_surfaces: [api]` para o REQ-13 inteiro evaporar.
#   WAV-01 — `wave close` aceitava o veredito do CHAMADOR (`gate_result="OK"` por default) e não
#            executava gate nenhum. Autocertificação: quem é verificado assinava o próprio laudo.
#
#   [0] CONTROLE: change coerente (declara o que toca) passa; wave com gate real passa
#   [1] SRF-00 — toca node layer:api sem declarar `api` → reprova, nomeando quantos arquivos
#   [2] SRF-00 — toca `contracts/openapi|asyncapi/**` sem declarar → reprova
#   [3] SRF-00 — task com verbo HTTP + path no texto sem declarar → reprova
#   [4] SRF-00 — CONTROLE: acrescentar `- api` ao manifest deixa verde (o mesmo change, um campo)
#   [5] SRF-00 — change que NÃO toca API não é obrigado a declarar nada (proporcionalidade)
#   [6] SRF-00 encadeia com REQ-13: declarar `api` passa a exigir o mapa endpoint→policy
#   [7] WAV-01 — `--gate OK` mentiroso NÃO fecha mais a wave quando o gate real reprova
#   [8] WAV-01 — sem `--gate`, o close EXECUTA os gates (não assume OK)
#   [9] WAV-01 — `--gate FAIL` continua reprovando (não regredimos o caminho honesto)
#   [10] WAV-01 — gate real verde fecha a wave, e o resultado gravado é o OBSERVADO
#   [11] REPRODUÇÃO — fixture do manifest real: reprova por não declarar `api`
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$WS/template/.forge/scripts/lib"
SCR="$WS/template/.forge/scripts"
T="$(mktemp -d /tmp/forge-w131.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# ── fixture: um change com tasks/requirements/manifest parametrizáveis ───────────────────────
# mk_change <id> <affects_surfaces-yaml-ou-vazio> <tasks-extra-line> [graph-json]
mk_change() {
  local id="$1" surfaces="$2" extra="$3"
  local dir="$T/$id/.forge/specs/active/$id"
  mkdir -p "$dir" "$T/$id/.forge/graph"
  {
    echo "id: $id"
    echo "type: feature"
    echo "mode: feature-only"
    echo "rigor: spec-first"
    echo "scale: 2"
    echo "status: tasks-ready"
    echo "created_at: 2026-07-29"
    echo "updated_at: 2026-07-29"
    echo "owner: milton"
    [ -n "$surfaces" ] && printf '%s\n' "$surfaces"
    echo "gates:"
    echo "  requirements_reviewed: true"
    echo "  design_reviewed: true"
    echo "  tasks_reviewed: false"
    echo "  implementation_verified: false"
    echo "  human_archive_approval: false"
  } > "$dir/manifest.yaml"
  printf '# Proposal\n\n## 1. Por quê\n\ntexto\n\n## 2. O que muda\n\ntexto\n' > "$dir/proposal.md"
  printf '# Design\n\ntexto\n' > "$dir/design.md"
  cat > "$dir/requirements.md" <<'REQ'
# Requirements

## REQ-01 — algo

Critérios de aceite: dado x, quando y, então z.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | janela | tela Configurações | TASK-01 |
REQ
  {
    echo '# Tasks'
    echo
    echo '## Wave 1 — base'
    echo
    echo '- [ ] TASK-01 — aplica a política (rastreia: REQ-01; paths: `src/Core/Policy.cs`; depende: —)'
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$dir/tasks.md"
  echo "$dir"
}

run_vs() { FORGE_ROOT="$T/$1" node "$LIB/validate-spec.mjs" "$T/$1/.forge/specs/active/$1" 2>&1 || true; }

# ── [0] CONTROLE ─────────────────────────────────────────────────────────────────────────────
echo "[0] CONTROLE: change coerente passa"
mk_change ctl "" "" >/dev/null
out="$(run_vs ctl)"
grep -q '^OK ctl' <<< "$out" || { echo "FAIL [0]: change coerente reprovou: $out"; exit 1; }
grep -q 'SRF-00' <<< "$out" && { echo "FAIL [0]: SRF-00 acusou change que não toca API: $out"; exit 1; }
echo "OK [0]"

# ── [1] toca node layer:api sem declarar ────────────────────────────────────────────────────
echo "[1] SRF-00 — toca layer:api sem declarar affects_surfaces"
D="$(mk_change apinodecl "" '- [ ] TASK-02 — registro (rastreia: REQ-01; paths: `src/Acme.Web.Api/Endpoints/P.cs`; depende: TASK-01)')"
cat > "$T/apinodecl/.forge/graph/graph.json" <<'GRAPH'
{"nodes":[{"id":"src/Acme.Web.Api/Endpoints/P.cs","layer":"api"},
          {"id":"src/Acme.Web.Api/Endpoints/Q.cs","layer":"api"},
          {"id":"src/Core/Policy.cs","layer":"domain"}],"edges":[]}
GRAPH
out="$(run_vs apinodecl)"
grep -q 'FAIL' <<< "$out" || { echo "FAIL [1]: passou tocando API sem declarar: $out"; exit 1; }
grep -q 'SRF-00' <<< "$out" || { echo "FAIL [1]: não reportou SRF-00: $out"; exit 1; }
# a mensagem tem que NOMEAR quantos arquivos — "declare api" sem contagem não ensina onde olhar
grep -qE 'SRF-00[^)]*[0-9]+' <<< "$out" || { echo "FAIL [1]: mensagem sem contagem de arquivos: $out"; exit 1; }
# SRF-00 BLOQUEIA — sai no FAIL, nunca como WARN. Diferente do SRF-01, aqui não há ambiguidade a
# calibrar: a afirmação é sobre o que o change TOCA, verificável nos próprios paths declarados.
grep -qE '^FAIL[^)]*SRF-00|^FAIL \(.*SRF-00' <<< "$out" || { echo "FAIL [1]: SRF-00 não é bloqueante: $out"; exit 1; }
grep -q 'WARN.*SRF-00' <<< "$out" && { echo "FAIL [1]: SRF-00 saiu como aviso: $out"; exit 1; }
echo "OK [1]"

# ── [2] toca contrato sem declarar ──────────────────────────────────────────────────────────
echo "[2] SRF-00 — toca contracts/openapi sem declarar"
mk_change contractnodecl "" '- [ ] TASK-02 — contrato (rastreia: REQ-01; paths: `contracts/openapi/svc.v1.yaml`; depende: TASK-01)' >/dev/null
out="$(run_vs contractnodecl)"
grep -q 'SRF-00' <<< "$out" || { echo "FAIL [2]: contrato de API não disparou SRF-00: $out"; exit 1; }
echo "OK [2]"

# ── [3] verbo HTTP + path no texto da task ──────────────────────────────────────────────────
echo "[3] SRF-00 — task com verbo HTTP + path no texto"
mk_change verbnodecl "" '- [ ] TASK-02 — POST /internal/v1/release (rastreia: REQ-01; paths: `src/Core/X.cs`; depende: TASK-01)' >/dev/null
out="$(run_vs verbnodecl)"
grep -q 'SRF-00' <<< "$out" || { echo "FAIL [3]: verbo+path no texto não disparou SRF-00: $out"; exit 1; }
echo "OK [3]"

# ── [4] CONTROLE do SRF-00: um campo resolve ────────────────────────────────────────────────
echo "[4] SRF-00 CONTROLE — declarar affects_surfaces: [api] deixa verde"
mk_change declared $'affects_surfaces:\n  - api' '- [ ] TASK-02 — contrato (rastreia: REQ-01; paths: `contracts/openapi/svc.v1.yaml`; depende: TASK-01)' >/dev/null
# declarar `api` liga o REQ-13, que exige os dois mapas — o change tem que fornecê-los
cat >> "$T/declared/.forge/specs/active/declared/requirements.md" <<'REQ'

## Mapa endpoint → ação → recurso → policy

| Endpoint | Ação | Recurso | Policy |
|---|---|---|---|
| `POST /v1/x` | criar | x | `x:create` |

## Mapa de eventos auditáveis

| Evento | Quando | Campos |
|---|---|---|
| `x.criado` | após criar | id |
REQ
out="$(run_vs declared)"
grep -q 'SRF-00' <<< "$out" && { echo "FAIL [4]: SRF-00 persistiu após declarar api: $out"; exit 1; }
grep -q '^OK declared' <<< "$out" || { echo "FAIL [4]: change declarado reprovou: $out"; exit 1; }
echo "OK [4]"

# ── [5] proporcionalidade ───────────────────────────────────────────────────────────────────
echo "[5] SRF-00 — change que não toca API não precisa declarar nada"
mk_change nosurface "" '- [ ] TASK-02 — refatora domínio (rastreia: REQ-01; paths: `src/Core/Store.cs`, `docs/nota.md`; depende: TASK-01)' >/dev/null
out="$(run_vs nosurface)"
grep -q 'SRF-00' <<< "$out" && { echo "FAIL [5]: SRF-00 exigiu declaração de change sem API: $out"; exit 1; }
grep -q '^OK nosurface' <<< "$out" || { echo "FAIL [5]: change sem API reprovou: $out"; exit 1; }
echo "OK [5]"

# ── [6] encadeamento com REQ-13 ─────────────────────────────────────────────────────────────
echo "[6] SRF-00 encadeia: declarar api passa a exigir o mapa endpoint→policy"
mk_change declaredbare $'affects_surfaces:\n  - api' '- [ ] TASK-02 — contrato (rastreia: REQ-01; paths: `contracts/openapi/svc.v1.yaml`; depende: TASK-01)' >/dev/null
out="$(run_vs declaredbare)"
grep -q 'FAIL' <<< "$out" || { echo "FAIL [6]: declarou api sem os mapas e passou: $out"; exit 1; }
grep -qi 'endpoint' <<< "$out" || { echo "FAIL [6]: não exigiu o mapa endpoint→policy: $out"; exit 1; }
# fecha o círculo: sem SRF-00, este change simplesmente omitiria `affects_surfaces` e escaparia
echo "OK [6]"

# ── wave: fixture com gate real ─────────────────────────────────────────────────────────────
# mk_wave <dir> <exit-code-do-gate> — monta um change com uma wave aberta e UM gate declarado.
# `runtime.gates` é CSV escalar de NOMES DE SCRIPT (não comando shell), e cada nome resolve para
# `.forge/scripts/<nome>.sh` — é o formato real que o spec-verify.sh já lia.
mk_wave() {
  local d="$1" rc="$2"
  mkdir -p "$d/.forge/specs/active/chg"
  cat > "$d/.forge/specs/active/chg/waves.json" <<'WAVES'
{"waves":[{"id":"W1","title":"primeira","status":"open","depends_on":[]}]}
WAVES
  printf '{"current_wave":"W1","updated_at":"2026-07-29"}\n' > "$d/.forge/specs/active/chg/progress.json"
  # o FORGE.md canônico do harness vive em .forge/FORGE.md (é de lá que forge_get_runtime lê)
  cat > "$d/.forge/FORGE.md" <<'FORGE'
---
runtime:
  primary_stack: bash
  gates: fixture-gate
---

# FORGE.md — fixture
FORGE
  printf '#!/usr/bin/env bash\nexit %s\n' "$rc" > "$d/.forge/scripts/fixture-gate.sh"
  chmod +x "$d/.forge/scripts/fixture-gate.sh"
}

# close_wave <workspace> [args...] → ecoa a saída, devolve o rc. Interface real do script:
#   wave-ops.sh close <change-id> <wave-id> [--gate OK|FAIL]
close_wave() {
  local w="$1"; shift
  set +e
  CW_OUT="$(cd "$w" && FORGE_ROOT="$w" bash "$w/.forge/scripts/wave-ops.sh" close chg "$@" 2>&1)"
  CW_RC=$?
  set -e
}
# Reprovar por erro de USO não é reprovar pelo gate. Sem esta distinção, a asserção passaria com o
# script quebrado de qualquer maneira — foi o que aconteceu na primeira versão deste gate, que
# chamava `close W1` sem o change-id e colhia "wave-id obrigatório" como se fosse veredito.
assert_gate_refusal() { # assert_gate_refusal <item>
  [ "$CW_RC" -ne 0 ] || { echo "FAIL [$1]: a wave fechou (rc=0): $CW_OUT"; exit 1; }
  case "$CW_OUT" in
    *Usage*|*obrigatório*|*"não encontrada"*)
      echo "FAIL [$1]: reprovou por erro de uso, não pelo gate: $CW_OUT"; exit 1 ;;
  esac
  grep -qiE 'gate' <<< "$CW_OUT" || { echo "FAIL [$1]: a mensagem não menciona o gate: $CW_OUT"; exit 1; }
  # e o estado em disco não pode ter avançado
  if grep -q '"status": *"closed"' "$2/.forge/specs/active/chg/waves.json"; then
    echo "FAIL [$1]: a wave foi marcada closed apesar da reprovação"; exit 1
  fi
}

# ── [7] o --gate OK mentiroso ───────────────────────────────────────────────────────────────
echo "[7] WAV-01 — '--gate OK' não fecha a wave quando o gate REAL reprova"
mkdir -p "$T/wliar"; cp -R "$WS/template/.forge" "$T/wliar/.forge"
mk_wave "$T/wliar" 1
close_wave "$T/wliar" W1 --gate OK
assert_gate_refusal 7 "$T/wliar"
# a reprovação tem de vir do ramo que olha o RESULTADO DA EXECUÇÃO. Sem esta asserção, uma
# implementação que ignora o exit code do run-gates.sh e cai numa barreira acidental adiante
# produziria o veredito certo pelo motivo errado — e a próxima regressão passaria calada.
grep -qi 'reprovou na execução' <<< "$CW_OUT" || { echo "FAIL [7]: a recusa não veio da execução do gate: $CW_OUT"; exit 1; }
grep -q 'fixture-gate: failed' <<< "$CW_OUT" || { echo "FAIL [7]: o gate real não foi executado: $CW_OUT"; exit 1; }
echo "OK [7]"

# ── [7b] gate DECLARADO e script AUSENTE reprova (pré-requisito faltando nunca é skip) ───────
echo "[7b] WAV-01 — gate declarado cujo script não existe REPROVA (não é skip silencioso)"
mkdir -p "$T/wmissing"; cp -R "$WS/template/.forge" "$T/wmissing/.forge"
mk_wave "$T/wmissing" 0
rm -f "$T/wmissing/.forge/scripts/fixture-gate.sh"     # declarado no FORGE.md, ausente em disco
close_wave "$T/wmissing" W1
assert_gate_refusal 7b "$T/wmissing"
grep -qi 'MISSING' <<< "$CW_OUT" || { echo "FAIL [7b]: não nomeou o gate ausente: $CW_OUT"; exit 1; }
echo "OK [7b]"

# ── [8] sem --gate, executa ─────────────────────────────────────────────────────────────────
echo "[8] WAV-01 — sem '--gate', o close EXECUTA os gates em vez de assumir OK"
mkdir -p "$T/wnoarg"; cp -R "$WS/template/.forge" "$T/wnoarg/.forge"
mk_wave "$T/wnoarg" 1
close_wave "$T/wnoarg" W1
assert_gate_refusal 8 "$T/wnoarg"
echo "OK [8]"

# ── [9] --gate FAIL continua reprovando ─────────────────────────────────────────────────────
echo "[9] WAV-01 — '--gate FAIL' continua reprovando (o caminho honesto não regrediu)"
mkdir -p "$T/wfail"; cp -R "$WS/template/.forge" "$T/wfail/.forge"
mk_wave "$T/wfail" 0
close_wave "$T/wfail" W1 --gate FAIL
assert_gate_refusal 9 "$T/wfail"
echo "OK [9]"

# ── [10] gate verde fecha, e grava o observado ──────────────────────────────────────────────
echo "[10] WAV-01 — gate real verde fecha a wave e grava o resultado OBSERVADO"
mkdir -p "$T/wok"; cp -R "$WS/template/.forge" "$T/wok/.forge"
mk_wave "$T/wok" 0
close_wave "$T/wok" W1
[ "$CW_RC" -eq 0 ] || { echo "FAIL [10]: gate verde não fechou a wave: $CW_OUT"; exit 1; }
node -e '
const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const w = d.waves.find((x) => x.id === "W1");
if (w.status !== "closed") { console.error("wave não fechou: " + w.status); process.exit(1); }
// o veredito gravado tem de vir da EXECUÇÃO, com rastro de qual gate rodou — "OK" cru não
// distingue "rodou e passou" de "ninguém rodou", que é a ambiguidade que este check remove
if (!w.gate_result || !/executed|observed|unit/i.test(JSON.stringify(w.gate_result))) {
  console.error("gate_result não registra a execução: " + JSON.stringify(w.gate_result)); process.exit(1);
}
' "$T/wok/.forge/specs/active/chg/waves.json" || { echo "FAIL [10]: veredito não é o observado"; exit 1; }
echo "OK [10]"

# ── [11] REPRODUÇÃO contra o manifest real ──────────────────────────────────────────────────
echo "[11] REPRODUÇÃO — o manifest real reprova por não declarar api"
FIX="$WS/tests/fixtures/w131"
[ -f "$FIX/manifest-real.yaml" ] || { echo "FAIL [11]: fixture $FIX/manifest-real.yaml ausente (pré-requisito faltando reprova)"; exit 1; }
# o guard olha o CAMPO (linha própria), não a palavra: o cabeçalho do fixture a menciona ao
# explicar o defeito, e um guard textual reprovaria a própria documentação dele
grep -qE '^affects_surfaces:' "$FIX/manifest-real.yaml" && { echo "FAIL [11]: o fixture do manifest real NÃO deveria declarar affects_surfaces — é o defeito que ele documenta"; exit 1; }
mkdir -p "$T/real/.forge/specs/active/fixture-change-b" "$T/real/.forge/graph"
R="$T/real/.forge/specs/active/fixture-change-b"
cp "$FIX/manifest-real.yaml" "$R/manifest.yaml"
cp "$WS/tests/fixtures/w130/tasks-real.md" "$R/tasks.md"
cp "$WS/tests/fixtures/w130/requirements-real.md" "$R/requirements.md"
printf '# Proposal\n\n## 1. Por quê\n\ntexto\n\n## 2. O que muda\n\ntexto\n' > "$R/proposal.md"
printf '# Design\n\ntexto\n' > "$R/design.md"
out="$(FORGE_ROOT="$T/real" node "$LIB/validate-spec.mjs" "$R" 2>&1 || true)"
grep -q 'SRF-00' <<< "$out" || { echo "FAIL [11]: o manifest real não disparou SRF-00: $out"; exit 1; }
# CONTROLE: acrescentar `- api` numa cópia → o SRF-00 cala
printf 'affects_surfaces:\n  - api\n' >> "$R/manifest.yaml"
out2="$(FORGE_ROOT="$T/real" node "$LIB/validate-spec.mjs" "$R" 2>&1 || true)"
grep -q 'SRF-00' <<< "$out2" && { echo "FAIL [11] CONTROLE: SRF-00 persistiu após declarar api: $out2"; exit 1; }
echo "OK [11]"

# ── [12] "não havia gate" ≠ "passou nos gates" ──────────────────────────────────────────────
# Projeto que não declarou `runtime.gates` continua podendo fechar wave (compatibilidade), mas o
# waves.json tem de registrar QUE não havia gate. Gravar `OK` nos dois casos apagaria a diferença —
# e é essa ambiguidade, não o fechamento em si, que sustentava a autocertificação.
echo "[12] WAV-01 — projeto sem gates declarados fecha, mas o registro diz NO-GATES"
mkdir -p "$T/wnone"; cp -R "$WS/template/.forge" "$T/wnone/.forge"
mk_wave "$T/wnone" 0
# remove a declaração de gates, preservando o resto do FORGE.md
sed -i.bak 's/^  gates: fixture-gate$/  gates:/' "$T/wnone/.forge/FORGE.md" && rm -f "$T/wnone/.forge/FORGE.md.bak"
close_wave "$T/wnone" W1
[ "$CW_RC" -eq 0 ] || { echo "FAIL [12]: projeto sem gates declarados não pôde fechar: $CW_OUT"; exit 1; }
node -e '
const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const w = d.waves.find((x) => x.id === "W1");
if (w.status !== "closed") { console.error("não fechou: " + w.status); process.exit(1); }
if (!/NO-GATES/.test(String(w.gate_result))) {
  console.error("registro não distingue ausência de gate de aprovação: " + JSON.stringify(w.gate_result));
  process.exit(1);
}
' "$T/wnone/.forge/specs/active/chg/waves.json" || { echo "FAIL [12]: NO-GATES não registrado"; exit 1; }
# e o caso COM gate verde grava procedência diferente — senão os dois estados colapsam
node -e '
const a = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).waves[0].gate_result;
const b = JSON.parse(require("fs").readFileSync(process.argv[2], "utf8")).waves[0].gate_result;
if (String(a) === String(b)) { console.error("mesmo registro para ausência de gate e gate verde: " + a); process.exit(1); }
' "$T/wnone/.forge/specs/active/chg/waves.json" "$T/wok/.forge/specs/active/chg/waves.json" \
  || { echo "FAIL [12]: 'sem gate' e 'gate verde' gravam o mesmo veredito"; exit 1; }
echo "OK [12]"

# ── [13] a referência morta virou script real ───────────────────────────────────────────────
# `commands/waves/wave.md` invocava `run-gates.sh` e o arquivo não existia. Um comando que chama um
# script ausente é um comando cujo gate ninguém roda — e nenhum teste percebia.
echo "[13] run-gates.sh existe e é o que a documentação invoca"
[ -f "$SCR/run-gates.sh" ] || { echo "FAIL [13]: run-gates.sh ausente"; exit 1; }
for f in "$WS/template/.forge/commands/waves/wave.md" "$WS/template/.forge/skills/wave-advance/SKILL.md"; do
  # nenhuma doc pode mandar passar veredito ao close: é o padrão de autocertificação
  if grep -qE 'wave-ops\.sh close[^\n]*--gate (OK|"\$gate_result")' "$f"; then
    echo "FAIL [13]: $f ainda manda repassar veredito ao close"; exit 1
  fi
done
# todo script citado como `.forge/scripts/<nome>.sh` nas docs de wave tem de existir
while IFS= read -r ref; do
  [ -f "$WS/template/.forge/scripts/$ref" ] || { echo "FAIL [13]: doc de wave cita .forge/scripts/$ref, que não existe"; exit 1; }
done < <(grep -rhoE '\.forge/scripts/[a-z0-9-]+\.sh' "$WS/template/.forge/commands/waves/" "$WS/template/.forge/skills/wave-advance/" | sed 's|.forge/scripts/||' | sort -u)
echo "OK [13]"

# ── [14] logs de gate não colidem entre execuções concorrentes ──────────────────────────────
# Um path fixo `/tmp/forge-gates-<id>-<gate>.log` faz duas execuções simultâneas do MESMO change
# escreverem no mesmo arquivo. O veredito continua vindo do exit code, mas o log que o autor vai
# ler para entender a reprovação pode ser o da outra execução — diagnóstico cruzado é a forma mais
# cara de erro, porque manda procurar no lugar errado com convicção.
echo "[14] run-gates — duas execuções simultâneas não cruzam log"
mkdir -p "$T/wconc"; cp -R "$WS/template/.forge" "$T/wconc/.forge"
mk_wave "$T/wconc" 0
# um gate que ESCREVE algo identificável e demora o suficiente para as execuções se sobreporem
cat > "$T/wconc/.forge/scripts/fixture-gate.sh" <<'GATE'
#!/usr/bin/env bash
echo "marcador-$FORGE_RUN_TAG"
sleep 1
exit 0
GATE
chmod +x "$T/wconc/.forge/scripts/fixture-gate.sh"
( cd "$T/wconc" && FORGE_ROOT="$T/wconc" FORGE_RUN_TAG=alfa bash .forge/scripts/run-gates.sh chg W1 > "$T/conc-a.txt" 2>&1 ) &
pid_a=$!
( cd "$T/wconc" && FORGE_ROOT="$T/wconc" FORGE_RUN_TAG=beta bash .forge/scripts/run-gates.sh chg W1 > "$T/conc-b.txt" 2>&1 ) &
pid_b=$!
wait "$pid_a" || { echo "FAIL [14]: execução A reprovou: $(cat "$T/conc-a.txt")"; exit 1; }
wait "$pid_b" || { echo "FAIL [14]: execução B reprovou: $(cat "$T/conc-b.txt")"; exit 1; }
log_a="$(sed -n 's/.*log: \([^)]*\)).*/\1/p' "$T/conc-a.txt" | head -1)"
log_b="$(sed -n 's/.*log: \([^)]*\)).*/\1/p' "$T/conc-b.txt" | head -1)"
[ -n "$log_a" ] && [ -n "$log_b" ] || { echo "FAIL [14]: run-gates não reportou o path do log"; exit 1; }
[ "$log_a" != "$log_b" ] || { echo "FAIL [14]: as duas execuções escreveram o MESMO log ($log_a)"; exit 1; }
grep -q 'marcador-alfa' "$log_a" || { echo "FAIL [14]: o log de A não tem a marca de A: $(cat "$log_a")"; exit 1; }
grep -q 'marcador-beta' "$log_b" || { echo "FAIL [14]: o log de B não tem a marca de B: $(cat "$log_b")"; exit 1; }
grep -q 'marcador-beta' "$log_a" && { echo "FAIL [14]: o log de A foi contaminado por B"; exit 1; }
echo "OK [14]"

echo "PASS w131-surface-declaration-gate"
