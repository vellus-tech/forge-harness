#!/usr/bin/env bash
# Gate W207 — `ledger-ops.sh render` é porta de ESCRITA e passa a anunciar divergência de raiz (LDG-0174).
#
# POR QUE ESTE GATE EXISTE. O comentário de `ledger-ops.sh` classificava as portas assim: "`render`,
# `status` e `list` só leem e ficam de fora — aviso em porta de leitura é ruído que treina o
# operador a ignorar a linha quando ela importa". A premissa é falsa para `render`: `_render()`
# grava `$OUT`, isto é, o `LEDGER.md`, que é arquivo RASTREADO. Só `status` e `list` de fato
# apenas leem.
#
# O DANO, medido antes da correção. Rodando `bash template/.forge/scripts/ledger-ops.sh render` de
# dentro de uma árvore de trabalho, sem `FORGE_ROOT` explícito, `forge_resolve_root` cai em
# `forge_main_root` (que resolve pelo `--git-common-dir`, ou seja, o TRONCO) e o comando reescreve o
# `LEDGER.md` do checkout principal — que pode estar noutra branch, com outro `ledger.json` e outro
# renderizador — emitindo `OK <caminho do tronco>` e NENHUMA linha de aviso. O operador lê `OK`,
# vê o caminho passar rápido e não tem como saber que gravou fora da árvore em que trabalha. Foi
# exatamente o que aconteceu nesta sessão: um agente de release precisou descobrir a regra lendo o
# fonte para não sujar a branch alheia que ocupava o checkout principal.
#
# A CORREÇÃO. `render` entra na lista de portas que chamam `forge_warn_root_divergence`. Nada mais
# muda: o aviso continua silencioso quando as raízes coincidem, continua silencioso quando
# `FORGE_ROOT` foi declarado (declaração não é acidente), e `status`/`list` continuam de fora,
# porque para elas a premissa original é verdadeira.
#
#   [1] CONTADOR DE CONTROLE POSITIVO: `add`, que já avisa desde o LDG-0068, emite o aviso na
#       fixture. Sem isto, um cenário que só verifica ausência de aviso seria satisfeito por uma
#       fixture quebrada em que NADA avisa — asserção negativa não prova nada sozinha.
#   [2] A PROPRIEDADE: `render` invocado da árvore de trabalho divergente emite o aviso, nomeando
#       a raiz que recebeu a escrita e a árvore de onde veio a invocação.
#   [3] `render` ESCREVE MESMO: o `LEDGER.md` da raiz resolvida muda de conteúdo. Prova que a
#       reclassificação corrige um fato, não uma opinião — se render só lesse, o aviso seria o
#       ruído que o comentário original temia.
#   [4] `list` continua SEM aviso: a correção não vale para porta de leitura de verdade.
#   [5] Com `FORGE_ROOT` explícito não há aviso, nem em `render`: quem declarou onde gravar já sabe.
#   [6] PROVA DE MUTAÇÃO sobre o arquivo RASTREADO real: (a) controle — [2] passa; (b) mutação —
#       remove `render` da lista de portas em `ledger-ops.sh` e vê [2] reprovar; (c) restauração
#       por `git checkout --`, NUNCA edição inversa; (d) recontrole — [2] passa de novo. Trap com
#       guarda MUTATED garante a restauração mesmo em saída inesperada por sinal.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WS" || { echo "FAIL: não foi possível entrar em '$WS'"; exit 2; }

LEDGER_OPS="$WS/template/.forge/scripts/ledger-ops.sh"
[ -f "$LEDGER_OPS" ] || { echo "FAIL: arquivo esperado ausente: $LEDGER_OPS"; exit 1; }

T="$(mktemp -d /tmp/forge-w207.XXXXXX)"
# MUTATED é a guarda de restauração: o cenário [6] muta `ledger-ops.sh`, que é arquivo rastreado.
# Sem ela, um sinal recebido dentro da janela deixaria o fix removido na árvore de trabalho — a
# classe do LDG-0164, e o mesmo achado que o code-review adversarial levantou contra o w203.
MUTATED=0
trap 'rm -rf "$T"; [ "$MUTATED" = "1" ] && git -C "$WS" checkout -- "$LEDGER_OPS"' EXIT

# ── fixture hermética: um repositório com layout .forge/ instalado, mais uma árvore de trabalho ──
# A fixture nunca lê nem escreve o `.forge/ledger/` real deste repositório.
FX="$T/repo"
mkdir -p "$FX/.forge/scripts/lib" "$FX/.forge/ledger" "$FX/.forge/templates/ledger"
cp "$LEDGER_OPS" "$FX/.forge/scripts/"
cp "$WS/template/.forge/scripts/lib/forge-root.sh" "$FX/.forge/scripts/lib/"
cp "$WS/template/.forge/scripts/lib/arg-guards.sh" "$FX/.forge/scripts/lib/"
cp "$WS/template/.forge/scripts/lib/ledger-render.mjs" "$FX/.forge/scripts/lib/"
cp "$WS/template/.forge/templates/ledger/LEDGER.md" "$FX/.forge/templates/ledger/" 2>/dev/null \
  || printf '# LEDGER fixture\n\nSECTION_ROADMAP\nSECTION_FEATURE_IDEA\nSECTION_TECH_DEBT\nSECTION_KNOWN_BUG\nSECTION_FOLLOW_UP\n' > "$FX/.forge/templates/ledger/LEDGER.md"
cat > "$FX/.forge/ledger/ledger.json" <<'JSON'
{"entries":[{"id":"LDG-0001","type":"tech-debt","title":"item de fixture","status":"open","source":{"origin":"manual"},"created_at":"2026-01-01T00:00:00Z","dedup_key":"manual:LDG-0001"}]}
JSON

git -C "$FX" init -q
git -C "$FX" config user.email fixture@example.com
git -C "$FX" config user.name Fixture
git -C "$FX" config commit.gpgsign false
git -C "$FX" add -A >/dev/null
git -C "$FX" commit -q --no-verify -m "fixture" >/dev/null

# a árvore de trabalho divergente — o cenário do dano
WTREE="$T/arvore"
git -C "$FX" worktree add -q --detach "$WTREE" HEAD >/dev/null 2>&1 \
  || { echo "FAIL: não foi possível montar a árvore de trabalho da fixture"; exit 2; }

# _run <porta> — roda a porta a partir da ÁRVORE DE TRABALHO, sem FORGE_ROOT, e devolve o stderr.
# Sem FORGE_ROOT de propósito: é a resolução AUTOMÁTICA que cai no tronco, que é o que o aviso
# existe para anunciar. O stdout vai para /dev/null porque o veredito deste gate está no stderr.
_run() {
  ( cd "$WTREE" && env -u FORGE_ROOT bash "$FX/.forge/scripts/ledger-ops.sh" "$@" 2>&1 >/dev/null )
}

# ── [1] contador de controle positivo ────────────────────────────────────────────────────────────
echo "[1] CONTADOR DE CONTROLE — 'add', porta que já avisa desde o LDG-0068, emite o aviso na fixture"
out1="$(_run add --type tech-debt --title "controle de w207")"
grep -q 'WARN' <<<"$out1" || {
  echo "FAIL [1]: a fixture não produz aviso nem na porta que já avisa — a divergência de raiz não está montada, e todo cenário negativo daqui em diante seria vazio. stderr: ${out1:-(vazio)}"; exit 1; }
grep -q 'ledger-ops' <<<"$out1" || {
  echo "FAIL [1]: o aviso não nomeia a porta — stderr: $out1"; exit 1; }
echo "OK [1] — a fixture avisa na porta de escrita conhecida, então a varredura enxerga algo"

# ── [2] a propriedade ────────────────────────────────────────────────────────────────────────────
echo "[2] PROPRIEDADE — 'render' invocado da árvore de trabalho divergente emite o aviso"
out2="$(_run render)"
grep -q 'WARN' <<<"$out2" || {
  echo "FAIL [2]: 'render' escreveu o LEDGER.md da raiz resolvida sem uma única linha de aviso — é a porta de escrita classificada como leitura (LDG-0174). stderr: ${out2:-(vazio)}"; exit 1; }
grep -q 'invocado de' <<<"$out2" || {
  echo "FAIL [2]: o aviso não nomeia a árvore de onde veio a invocação — sem isso o operador não consegue comparar as duas raízes. stderr: $out2"; exit 1; }
echo "OK [2] — 'render' anuncia a divergência antes de gravar fora da árvore de trabalho"

# ── [3] render escreve mesmo ─────────────────────────────────────────────────────────────────────
echo "[3] 'render' é porta de ESCRITA — o LEDGER.md da raiz resolvida muda de conteúdo"
OUTFILE="$FX/.forge/ledger/LEDGER.md"
printf 'conteudo plantado que nenhum render produz\n' > "$OUTFILE"
antes="$(cat "$OUTFILE")"
_run render >/dev/null 2>&1
depois="$(cat "$OUTFILE" 2>/dev/null || echo '(ausente)')"
[ "$antes" != "$depois" ] || {
  echo "FAIL [3]: 'render' não alterou $OUTFILE — se render de fato só lesse, o aviso de [2] seria o ruído que o comentário original temia, e este gate estaria errado"; exit 1; }
echo "OK [3] — render reescreveu o LEDGER.md da raiz resolvida (a premissa 'só lê' é falsa)"

# ── [4] porta de leitura de verdade continua sem aviso ───────────────────────────────────────────
echo "[4] 'list' — porta de leitura de verdade — continua SEM aviso"
out4="$(_run list)"
grep -q 'WARN' <<<"$out4" && {
  echo "FAIL [4]: 'list' passou a avisar — a correção transbordou para porta de leitura e vira o ruído que treina o operador a ignorar a linha. stderr: $out4"; exit 1; }
echo "OK [4] — 'list' segue silenciosa"

# ── [5] FORGE_ROOT declarado silencia ────────────────────────────────────────────────────────────
echo "[5] com FORGE_ROOT explícito não há aviso, nem em 'render' — declaração não é acidente"
out5="$( cd "$WTREE" && FORGE_ROOT="$FX" bash "$FX/.forge/scripts/ledger-ops.sh" render 2>&1 >/dev/null )"
grep -q 'WARN' <<<"$out5" && {
  echo "FAIL [5]: avisou mesmo com FORGE_ROOT declarado — quem exportou já disse onde quer gravar, e avisá-lo é ruído em todo fixture e todo CI. stderr: $out5"; exit 1; }
echo "OK [5] — FORGE_ROOT declarado silencia o aviso"

# ── [6] prova de mutação sobre o arquivo rastreado ───────────────────────────────────────────────
echo "[6] PROVA DE MUTAÇÃO — controle, mutação, git checkout --, recontrole"
out6a="$(_run render)"
grep -q 'WARN' <<<"$out6a" || { echo "FAIL [6] controle: [2] deveria passar antes de mutar"; exit 1; }
echo "OK [6] controle — o aviso está presente antes da mutação"

MUTATED=1
# a mutação remove `render` da lista de portas que avisam, que é exatamente o estado anterior à
# correção; o `sed` casa a linha do `case` pelo conjunto de portas, não por número de linha.
perl -0pi -e 's/\badd\|update\|resolve\|promote\|harvest\|render\)/add|update|resolve|promote|harvest)/' "$LEDGER_OPS"
if git -C "$WS" diff --quiet -- "$LEDGER_OPS"; then
  MUTATED=0
  echo "FAIL [6] mutação: o comando de mutação não alterou $LEDGER_OPS — a prova seria fantasma (LDG-0164). Ajuste o alvo do perl."; exit 1
fi
cp "$LEDGER_OPS" "$FX/.forge/scripts/ledger-ops.sh"
out6b="$(_run render)"
if grep -q 'WARN' <<<"$out6b"; then
  git -C "$WS" checkout -- "$LEDGER_OPS"; MUTATED=0
  echo "FAIL [6] mutação: mesmo sem 'render' na lista de portas o aviso apareceu — o cenário [2] não está medindo esta lista. stderr: $out6b"; exit 1
fi
echo "OK [6] mutação — sem 'render' na lista, o aviso desaparece (o cenário [2] mede a lista de portas)"

git -C "$WS" checkout -- "$LEDGER_OPS"; MUTATED=0
cp "$LEDGER_OPS" "$FX/.forge/scripts/ledger-ops.sh"
out6c="$(_run render)"
grep -q 'WARN' <<<"$out6c" || {
  echo "FAIL [6] recontrole: depois do 'git checkout --' o aviso não voltou — a restauração não funcionou e a mutação anterior não provou nada. stderr: ${out6c:-(vazio)}"; exit 1; }
echo "OK [6] recontrole — git checkout -- restaurou o aviso"

echo "TODOS OS CENÁRIOS OK — w207-ledger-render-write-port-gate"
