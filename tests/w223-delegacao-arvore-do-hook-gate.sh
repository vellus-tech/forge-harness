#!/usr/bin/env bash
# Gate W223 — issue #141: core.hooksPath absoluto para o tronco (#41/#54, LDG-0042) + delegação
# resolvida por $ROOT (a árvore que executa) faz um hook novo, vindo do tronco, encontrar
# scripts/libs antigos na worktree e bloquear por causa alheia.
#
# Desenho (L3 D14 reaproveitado): precedência de resolução do alvo delegado — primeiro a árvore
# que executa; se ausente lá e a árvore do hook (o tronco, quando hooksPath é absoluto) tiver o
# alvo, usa o do tronco com uma linha nomeando-o ("hook: <alvo> ausente em <worktree> — usando o
# do tronco (<caminho>); rode forge update na worktree"); bloqueio mantido quando falta nas duas.
#
#   [1] pre-commit — matriz exaustiva dos quatro estados (worktree x tronco, cada um com/sem):
#       [1a] sem na worktree, com no tronco  → passa e nomeia o tronco
#       [1b] sem nas duas                    → contrafactual: continua bloqueando
#       [1c] com nas duas (conteúdos diferentes) → usa o da PRÓPRIA árvore, nunca o do tronco
#       [1d] com só na worktree              → usa o próprio
#   [2] commit-msg — sem na worktree, com no tronco → passa e nomeia o tronco
#   [3] post-merge — os dois alvos (changelog-from-merge.mjs, check-liaison-log-integrity.sh)
#       ausentes na worktree e presentes no tronco → não FALHA, nomeia o tronco nos dois
#   [4] pre-push — DOCS_LIB, RED_LIB (require_hook_lib), AI_CHECK e ACKS ausentes na worktree e
#       presentes no tronco (stubs) → "pre-push OK", quatro linhas nomeando o tronco
#   [5] pre-push — HARNESS_SUITE (run-all.sh) ausente na worktree, presente no tronco → não
#       bloqueia, nomeia o tronco (e nomeia também o heavy-mutex.sh, resolvido no mesmo push)
#   [5b] pre-push — HARNESS_SUITE com o run-all.sh REAL (não stub): worktree TEM
#       .forge/scripts/tests/ com um teste que falha e SEM run-all.sh próprio; tronco tem o
#       run-all.sh real (sem testes) → BLOQUEIA nomeando o teste da PRÓPRIA worktree. Prova que o
#       runner do tronco, quando emprestado, examina a árvore que empresta o hook (--path), nunca
#       a própria (LDG — achado do adendo de revisão do w223)
#   [5c] pre-push — HARNESS_SUITE contrafactual: worktree SEM .forge/scripts/tests/ (diretório
#       inteiro ausente — harness anterior à #73); tronco tem run-all.sh real com um teste que
#       falha → passa (rc 0), a suíte do tronco NUNCA examina o alheio quando o diretório não
#       existe na worktree
#   [6] pre-push — lint de shell (check-shell-pipeline.sh) ausente na worktree, presente no
#       tronco, com um .sh no diff do push → não bloqueia, nomeia o tronco
#   [7] pre-push — contrafactual: AI_CHECK ausente nas DUAS árvores → continua BLOQUEANDO
#   [8] lib/check-red-first.sh — os dois alvos internos (check-red-first.sh delegado,
#       gate-universe.sh) ausentes na árvore que executa e presentes na árvore de onde a lib foi
#       sourced (o tronco) → não bloqueia, nomeia o tronco nos dois
#   [9] AUTO-IRONIA: os 16 sítios (12 de L3 §0 + RUNTIME_LIB + gate-phase.mjs + os 2 sítios de
#       aviso) chamam o mesmo resolvedor — contagem estrutural por arquivo, sem vacuidade, MAIS a
#       identidade byte a byte do corpo da função entre as 4 cópias (pre-commit, commit-msg,
#       post-merge, pre-push), porque a contagem de chamadas não pega uma correção aplicada só
#       numa cópia
#   [9b] as 4 cópias de resolve_delegated() batem byte a byte, e o corpo de
#       _redfirst_resolve_delegated() (lib/check-red-first.sh) é o MESMO código, normalizando só
#       as duas diferenças estruturais legítimas (REPO/ROOT; obtenção do diretório do tronco por
#       função em vez de variável global) — sem isso, uma correção aplicada só nas 4 cópias-irmãs
#       passava verde com a quinta cópia divergente
#   [10] pre-push — RUNTIME_LIB (forge-runtime.sh) ausente na worktree, presente no tronco, com
#       runtime.gates declarado (forma CSV) e o gate existindo na worktree → não bloqueia, nomeia
#       o tronco, e o gate declarado roda de verdade (achado do adendo de revisão do w223)
#   [10b] pre-push — forma MAPEADA (`gates:` vazio), forge-runtime.sh E gate-phase.mjs ausentes na worktree, presentes no tronco → não bloqueia, nomeia os dois, e o gate declarado na forma mapeada roda de verdade (achado HIGH do adendo de revisão do w223: o guarda do gate-phase.mjs checava `$ROOT` literal e bloqueava mesmo com o par completo no tronco)
#   [10c] pre-push — contrafactual do [10b]: forge-runtime.sh presente nas DUAS árvores (compatível, com forge_runtime_gate_entries), mas gate-phase.mjs AUSENTE nas duas → forma mapeada continua BLOQUEANDO (a coerência de par não inventa um arquivo que não existe em lugar nenhum)
#   [11] pre-push — a recusa de alvo ausente nas duas árvores nomeia AS DUAS árvores procuradas,
#       nunca afirma presença falsa de diretório que só existe numa delas (achado do adendo)
#   [12] pre-push — RUNTIME_LIB resolvido para a PRÓPRIA worktree (arquivo existe lá), mas é uma versão anterior a #82 (cópia real de v0.10.0, sem forge_runtime_gate_entries); tronco tem a lib compatível; runtime.gates CSV declara um gate que falha → o hook TROCA para a lib do tronco, nomeando-a, e o gate declarado RODA e FALHA de verdade (achado MEDIUM do adendo: sem a troca, `forge_runtime_gate_entries: command not found` era engolido por `|| true` e o push saía "NO-GATES", rc 0, sem rodar o gate)
#   [12b] pre-push — contrafactual do [12]: a mesma lib v0.10.0 na worktree, e o tronco TAMBÉM sem forge_runtime_gate_entries (mesma versão v0.10.0 lá) → BLOQUEIA nomeando a incompatibilidade, nunca silêncio verde
#   [13] pre-push — check-liaison-log-integrity.sh e check-worktree-prereqs.sh (sítios de AVISO, nunca bloqueio) ausentes na worktree, presentes no tronco → os dois RODAM de verdade a partir do tronco, nomeando-o (achado LOW do adendo: os dois só checavam `$ROOT` literal e perdiam a checagem em silêncio quando só o tronco tinha o script)
#   [13b] pre-push — contrafactual do [13]: os dois ausentes nas DUAS árvores → continuam como AVISO "NÃO VERIFICADO" (nunca bloqueio), comportamento inalterado
#
# Achados da rodada de correção (revisão adversarial sobre este PR, não sobre o w223 original):
#   [5d] pre-push — HARNESS_SUITE com runner PRÓPRIO da worktree, estrito (sai 64 ao receber
#       qualquer argumento) → passa sem `--path`, como sempre chamou; contrafactual embutido do
#       LOW "--path passado também ao runner próprio", que quebrava retrocompatibilidade com um
#       runner de consumidor mais estrito que a #141 não previu
#   [10d] pre-push — forma MAPEADA: forge-runtime.sh PRÓPRIO da worktree e COMPATÍVEL (tem
#       forge_runtime_gate_entries), mas gate-phase.mjs ausente só na worktree; tronco tem o par
#       completo → troca as DUAS (RUNTIME_LIB e gate-phase.mjs) para o tronco e o gate declarado,
#       que FALHA, roda de verdade (rc 1, marcador do gate impresso) — mutante sobrevivente do
#       achado MEDIUM do adendo de revisão: [10b] só cobria os dois alvos ausentes JUNTOS na
#       worktree, onde RUNTIME_LIB já vinha do tronco e a troca de par não fazia nada
#
# Decisão autônoma do orquestrador (registrada no CHANGELOG e no corpo do commit): árvore sem
# `.forge/` nenhum é árvore NÃO GERENCIADA — os 5 resolvedores devolvem o no-op anterior à #141
# (rc 2) sem consultar o tronco, sem aviso e sem escrita; a delegação ao tronco vale só para a
# árvore que TEM `.forge/` mas com o alvo ausente ou defasado:
#   [14] pre-push — worktree de branch anterior à adoção do harness, SEM `.forge/` nenhum → o push
#       sai rc 0 ("pre-push OK (sem harness)"), SEM rodar nenhum script do tronco e SEM a linha
#       "usando o do tronco ... rode forge update na worktree"; contrafactual [1a]/[3] (acima):
#       com `.forge/` presente e só o alvo ausente, a delegação ao tronco continua rodando de
#       verdade
#   [14b] post-merge — a mesma árvore sem `.forge/` nenhum, com um CHANGELOG.md versionado: o
#       merge não delega changelog-from-merge.mjs ao tronco, e `git status` fica LIMPO depois —
#       nenhuma escrita no CHANGELOG.md de uma árvore que nunca adotou o harness (MEDIUM); o
#       contrafactual é o próprio [3]: com `.forge/` presente, o tronco escreve de verdade
#   [14c] pre-commit — a mesma árvore sem `.forge/` nenhum: nenhum check do tronco roda (nem
#       check-secrets.sh), commit passa OK; contrafactual é o próprio [1a]
#
# Achado LOW da revisão do próprio PR desta issue (regressão em relação a f24b029): quando o hook
# é COPIADO para .git/hooks (nunca delegado por core.hooksPath), $0 é caminho absoluto em
# .git/hooks/, e dirname($0)/../.. cai no $ROOT do próprio repositório — não em `.forge`. Sem
# guarda, HOOK_FORGE_DIR virava esse $ROOT, e um `scripts/check-secrets.sh` alheio ao harness (do
# próprio projeto, na raiz) era tratado como se fosse `.forge/scripts/check-secrets.sh` do
# "tronco":
#   [15] pre-commit — `.forge/` presente sem `.forge/scripts/`, hook copiado p/ .git/hooks, e
#       `scripts/check-secrets.sh` do PROJETO (sai 3, cria marcador) na raiz → o alvo nunca é
#       confundido com o do tronco: commit sai rc 0, marcador não existe
#   [15b] pre-commit — variante do [15]: `scripts/` da raiz do projeto existe mas SEM
#       check-secrets.sh dentro → sem a mensagem falsa ".forge/scripts/ existe mas
#       check-secrets.sh não" (quem existe é `scripts/` do projeto, nunca `.forge/scripts/`)
set -uo pipefail
# Isolamento git (LDG-0201): GIT_DIR herdado do ambiente faria os comandos git abaixo
# obedecerem ao repositório de quem invocou o gate, e não ao repositório sintético criado aqui.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$WS/template/.forge/hooks/git"

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w223.XXXXXX")"
trap 'rm -rf "$T"' EXIT
# Canônico (resolve symlinks, ex.: /var -> /private/var no macOS): `git rev-parse --show-toplevel`
# e `cd && pwd` dentro dos hooks devolvem o caminho REAL, e os casts abaixo comparam string.
T="$(cd "$T" && pwd -P)"

ZERO=0000000000000000000000000000000000000000

# mktrunk <dir> — .forge de "tronco": só o que cada cenário precisa, populado pelo chamador.
# heavy-mutex.sh sempre presente (stub): heavy_mutex fica desligado por padrão nestes cenários
# (sem forge.yaml com enabled:true), então só a PRESENÇA do alvo importa — evita que o Bloco
# HEAVY_LIB (issue #141, sítio 5/6) bloqueie cenários que não são sobre ele.
mktrunk() {
  mkdir -p "$1/.forge/hooks/git/lib" "$1/.forge/scripts/lib" "$1/.forge/scripts/tests"
  printf '#!/usr/bin/env bash\nforge_heavy_mutex_acquire() { return 0; }\nforge_heavy_mutex_arm_trap() { :; }\n' \
    > "$1/.forge/scripts/lib/heavy-mutex.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$1/.forge/scripts/tests/run-all.sh"
  chmod +x "$1/.forge/scripts/tests/run-all.sh"
}

# mkrepo <dir> <hooksPath-dir> — repositório git mínimo com hooksPath apontando para
# <hooksPath-dir> (o "tronco"); $ROOT deste repo é a "worktree" que executa o hook.
mkrepo() {
  local d="$1" hp="$2"
  mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.email t@t; git -C "$d" config user.name t; git -C "$d" config commit.gpgsign false
  git -C "$d" config core.hooksPath "$hp"
  printf 'x\n' > "$d/a.txt"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -qm "chore: init" >/dev/null 2>&1
}

pass=0

# ── [1] pre-commit — matriz exaustiva ────────────────────────────────────────────────────────
echo "[1] pre-commit — matriz exaustiva dos quatro estados"

# [1a] sem na worktree, com no tronco
R1A="$T/r1a"; TR1A="$T/tr1a"
mktrunk "$TR1A"
cp "$HOOKS/pre-commit" "$TR1A/.forge/hooks/git/pre-commit"; chmod +x "$TR1A/.forge/hooks/git/pre-commit"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR1A/.forge/scripts/check-secrets.sh"; chmod +x "$TR1A/.forge/scripts/check-secrets.sh"
mkrepo "$R1A" "$TR1A/.forge/hooks/git"
mkdir -p "$R1A/.forge/scripts"   # worktree TEM o diretório, mas SEM check-secrets.sh
printf 'y\n' > "$R1A/b.txt"; git -C "$R1A" add b.txt >/dev/null 2>&1
out="$(cd "$R1A" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1a]: pre-commit bloqueou com o alvo presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"$TR1A/.forge/scripts/check-secrets.sh"*) : ;;
  *) echo "FAIL [1a]: passou sem nomear o tronco (saída: '$out')"; exit 1 ;;
esac
echo "OK [1a]"

# [1b] sem nas duas — contrafactual
R1B="$T/r1b"; TR1B="$T/tr1b"
mktrunk "$TR1B"
cp "$HOOKS/pre-commit" "$TR1B/.forge/hooks/git/pre-commit"; chmod +x "$TR1B/.forge/hooks/git/pre-commit"
mkrepo "$R1B" "$TR1B/.forge/hooks/git"
mkdir -p "$R1B/.forge/scripts"
printf 'y\n' > "$R1B/b.txt"; git -C "$R1B" add b.txt >/dev/null 2>&1
out="$(cd "$R1B" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [1b]: pre-commit passou com o alvo ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"check-secrets.sh"*"alvo ausente"*) : ;;
  *) echo "FAIL [1b]: bloqueou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [1b]"

# [1c] com nas duas, conteúdos diferentes — usa o da PRÓPRIA árvore
R1C="$T/r1c"; TR1C="$T/tr1c"
mktrunk "$TR1C"
cp "$HOOKS/pre-commit" "$TR1C/.forge/hooks/git/pre-commit"; chmod +x "$TR1C/.forge/hooks/git/pre-commit"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TR1C/.forge/scripts/check-secrets.sh"; chmod +x "$TR1C/.forge/scripts/check-secrets.sh"
mkrepo "$R1C" "$TR1C/.forge/hooks/git"
mkdir -p "$R1C/.forge/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R1C/.forge/scripts/check-secrets.sh"; chmod +x "$R1C/.forge/scripts/check-secrets.sh"
printf 'y\n' > "$R1C/b.txt"; git -C "$R1C" add b.txt >/dev/null 2>&1
out="$(cd "$R1C" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1c]: pre-commit não usou a própria versão (sucesso esperado; saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*) echo "FAIL [1c]: usou o do tronco em vez do da própria árvore (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [1c]"

# [1d] com só na worktree
R1D="$T/r1d"; TR1D="$T/tr1d"
mktrunk "$TR1D"
cp "$HOOKS/pre-commit" "$TR1D/.forge/hooks/git/pre-commit"; chmod +x "$TR1D/.forge/hooks/git/pre-commit"
mkrepo "$R1D" "$TR1D/.forge/hooks/git"
mkdir -p "$R1D/.forge/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R1D/.forge/scripts/check-secrets.sh"; chmod +x "$R1D/.forge/scripts/check-secrets.sh"
printf 'y\n' > "$R1D/b.txt"; git -C "$R1D" add b.txt >/dev/null 2>&1
out="$(cd "$R1D" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [1d]: pre-commit bloqueou com o alvo presente na própria árvore (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*) echo "FAIL [1d]: nomeou o tronco quando a própria árvore já tinha o alvo (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [1d] — os quatro estados da matriz cobertos"

# ── [2] commit-msg ────────────────────────────────────────────────────────────────────────────
echo "[2] commit-msg — ausente na worktree, presente no tronco"
R2="$T/r2"; TR2="$T/tr2"
mktrunk "$TR2"
cp "$HOOKS/commit-msg" "$TR2/.forge/hooks/git/commit-msg"; chmod +x "$TR2/.forge/hooks/git/commit-msg"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR2/.forge/scripts/check-ai-attribution.sh"; chmod +x "$TR2/.forge/scripts/check-ai-attribution.sh"
mkrepo "$R2" "$TR2/.forge/hooks/git"
mkdir -p "$R2/.forge/scripts"
printf 'chore: mensagem\n' > "$T/msg2.txt"
out="$(cd "$R2" && bash "$TR2/.forge/hooks/git/commit-msg" "$T/msg2.txt" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [2]: commit-msg bloqueou com o alvo presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"$TR2/.forge/scripts/check-ai-attribution.sh"*) : ;;
  *) echo "FAIL [2]: passou sem nomear o tronco (saída: '$out')"; exit 1 ;;
esac
echo "OK [2]"

# ── [3] post-merge — os dois alvos ───────────────────────────────────────────────────────────
echo "[3] post-merge — changelog-from-merge.mjs e check-liaison-log-integrity.sh via tronco"
R3="$T/r3"; TR3="$T/tr3"
mktrunk "$TR3"
cp "$HOOKS/post-merge" "$TR3/.forge/hooks/git/post-merge"; chmod +x "$TR3/.forge/hooks/git/post-merge"
printf 'process.exit(0);\n' > "$TR3/.forge/scripts/lib/changelog-from-merge.mjs"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR3/.forge/scripts/check-liaison-log-integrity.sh"; chmod +x "$TR3/.forge/scripts/check-liaison-log-integrity.sh"
mkrepo "$R3" "$TR3/.forge/hooks/git"
mkdir -p "$R3/.forge/scripts/lib"
out="$(cd "$R3" && bash "$TR3/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [3]: post-merge falhou com os alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"changelog-from-merge.mjs"*) : ;;
  *) echo "FAIL [3]: não nomeou o tronco para changelog-from-merge.mjs (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"check-liaison-log-integrity.sh"*) : ;;
  *) echo "FAIL [3]: não nomeou o tronco para check-liaison-log-integrity.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [3]"

# ── [4] pre-push — DOCS_LIB, RED_LIB, AI_CHECK, ACKS ────────────────────────────────────────
echo "[4] pre-push — DOCS_LIB, RED_LIB, AI_CHECK, ACKS ausentes na worktree, presentes no tronco"
R4="$T/r4"; TR4="$T/tr4"
mktrunk "$TR4"
cp "$HOOKS/pre-push" "$TR4/.forge/hooks/git/pre-push"; chmod +x "$TR4/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR4/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR4/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR4/.forge/scripts/check-ai-attribution.sh"; chmod +x "$TR4/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR4/.forge/scripts/check-liaison-acks.sh"; chmod +x "$TR4/.forge/scripts/check-liaison-acks.sh"
mkrepo "$R4" "$TR4/.forge/hooks/git"
mkdir -p "$R4/.forge/hooks/git/lib" "$R4/.forge/scripts"   # os diretórios existem; os 4 alvos, não
SHA4="$(git -C "$R4" rev-parse HEAD)"
out="$(cd "$R4" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA4" "$ZERO" | bash "$TR4/.forge/hooks/git/pre-push" origin "file://$R4" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [4]: pre-push bloqueou com os quatro alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in *"pre-push OK"*) : ;; *) echo "FAIL [4]: não terminou 'pre-push OK' (saída: '$out')"; exit 1 ;; esac
n_warn="$(grep -c "usando o do tronco" <<<"$out")"
[ "$n_warn" -eq 4 ] || { echo "FAIL [4]: esperava 4 linhas nomeando o tronco (DOCS_LIB, RED_LIB, AI_CHECK, ACKS), veio $n_warn (saída: '$out')"; exit 1; }
echo "OK [4] — 4 alvos resolvidos via tronco"

# ── [5] pre-push — HARNESS_SUITE ─────────────────────────────────────────────────────────────
echo "[5] pre-push — run-all.sh ausente na worktree, presente no tronco"
R5="$T/r5"; TR5="$T/tr5"
mktrunk "$TR5"
cp "$HOOKS/pre-push" "$TR5/.forge/hooks/git/pre-push"; chmod +x "$TR5/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR5/.forge/scripts/tests/run-all.sh"
mkrepo "$R5" "$TR5/.forge/hooks/git"
mkdir -p "$R5/.forge/hooks/git/lib" "$R5/.forge/scripts/tests"
cp "$TR5/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5/.forge/hooks/git/lib/check-red-first.sh" "$R5/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5/.forge/FORGE.md"
SHA5="$(git -C "$R5" rev-parse HEAD)"
out="$(cd "$R5" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5" "$ZERO" | bash "$TR5/.forge/hooks/git/pre-push" origin "file://$R5" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5]: pre-push bloqueou com run-all.sh presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"run-all.sh"*) : ;;
  *) echo "FAIL [5]: não nomeou o tronco para run-all.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"heavy-mutex.sh"*) : ;;
  *) echo "FAIL [5]: não nomeou o tronco para heavy-mutex.sh, resolvido no mesmo push (saída: '$out')"; exit 1 ;;
esac
echo "OK [5]"

# ── [5b] pre-push — HARNESS_SUITE com run-all.sh REAL: teste da PRÓPRIA worktree ────────────
echo "[5b] pre-push — run-all.sh real no tronco, teste que falha na PRÓPRIA worktree, sem runner"
R5B="$T/r5b"; TR5B="$T/tr5b"
mktrunk "$TR5B"
cp "$HOOKS/pre-push" "$TR5B/.forge/hooks/git/pre-push"; chmod +x "$TR5B/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5B/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5B/.forge/hooks/git/lib/check-red-first.sh"
# run-all.sh REAL do template no tronco (não o stub `exit 0` de mktrunk) — sem teste algum no
# diretório do tronco, para que qualquer FALHA só possa vir do que a worktree publica.
cp "$WS/template/.forge/scripts/tests/run-all.sh" "$TR5B/.forge/scripts/tests/run-all.sh"; chmod +x "$TR5B/.forge/scripts/tests/run-all.sh"
mkrepo "$R5B" "$TR5B/.forge/hooks/git"
mkdir -p "$R5B/.forge/hooks/git/lib" "$R5B/.forge/scripts/tests"   # worktree TEM o diretório de testes
cp "$TR5B/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5B/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5B/.forge/hooks/git/lib/check-red-first.sh" "$R5B/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5B/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5B/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5B/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5B/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5B/.forge/FORGE.md"
# ...mas SEM run-all.sh próprio, e com um teste que FALHA
printf '#!/usr/bin/env bash\nexit 1\n' > "$R5B/.forge/scripts/tests/meu-gate.test.sh"; chmod +x "$R5B/.forge/scripts/tests/meu-gate.test.sh"
SHA5B="$(git -C "$R5B" rev-parse HEAD)"
out="$(cd "$R5B" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5B" "$ZERO" | bash "$TR5B/.forge/hooks/git/pre-push" origin "file://$R5B" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [5b]: pre-push passou com um teste falhando na própria worktree (saída: '$out')"; exit 1; }
case "$out" in
  *"meu-gate.test.sh"*) : ;;
  *) echo "FAIL [5b]: bloqueou sem nomear o teste da worktree que falhou (saída: '$out')"; exit 1 ;;
esac
echo "OK [5b]"

# ── [5c] pre-push — HARNESS_SUITE contrafactual: sem o diretório de testes na worktree ──────
echo "[5c] pre-push — worktree SEM .forge/scripts/tests/, tronco com teste que falha → rc 0"
R5C="$T/r5c"; TR5C="$T/tr5c"
mktrunk "$TR5C"
cp "$HOOKS/pre-push" "$TR5C/.forge/hooks/git/pre-push"; chmod +x "$TR5C/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5C/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5C/.forge/hooks/git/lib/check-red-first.sh"
cp "$WS/template/.forge/scripts/tests/run-all.sh" "$TR5C/.forge/scripts/tests/run-all.sh"; chmod +x "$TR5C/.forge/scripts/tests/run-all.sh"
# teste que falha, mas é do TRONCO — causa alheia à worktree
printf '#!/usr/bin/env bash\nexit 1\n' > "$TR5C/.forge/scripts/tests/do-tronco.test.sh"; chmod +x "$TR5C/.forge/scripts/tests/do-tronco.test.sh"
mkrepo "$R5C" "$TR5C/.forge/hooks/git"
mkdir -p "$R5C/.forge/hooks/git/lib" "$R5C/.forge/scripts"   # SEM .forge/scripts/tests/ nenhum
cp "$TR5C/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5C/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5C/.forge/hooks/git/lib/check-red-first.sh" "$R5C/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5C/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5C/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5C/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5C/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5C/.forge/FORGE.md"
SHA5C="$(git -C "$R5C" rev-parse HEAD)"
out="$(cd "$R5C" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5C" "$ZERO" | bash "$TR5C/.forge/hooks/git/pre-push" origin "file://$R5C" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5c]: pre-push bloqueou por um teste que só existe no tronco, sem diretório de testes na worktree (saída: '$out')"; exit 1; }
case "$out" in
  *"do-tronco.test.sh"*) echo "FAIL [5c]: a suíte do tronco rodou (nomeou 'do-tronco.test.sh') mesmo sem o diretório de testes na worktree (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [5c]"

# ── [5d] pre-push — HARNESS_SUITE com runner PRÓPRIO da worktree, estrito ───────────────────
# Achado LOW da correção do #141 (rodada 2): `--path` era passado ao runner em QUALQUER origem,
# inclusive quando a worktree tem o seu PRÓPRIO run-all.sh — antes desta issue ele era chamado
# sem argumento nenhum. Um runner de consumidor mais estrito, que rejeita opção desconhecida com
# rc 64, passava a bloquear o push só por causa de um argumento que não era dele.
echo "[5d] pre-push — run-all.sh PRÓPRIO da worktree, estrito (rejeita qualquer argumento com rc 64)"
echo "     → chamado SEM --path, como sempre foi; passa"
R5D="$T/r5d"; TR5D="$T/tr5d"
mktrunk "$TR5D"
cp "$HOOKS/pre-push" "$TR5D/.forge/hooks/git/pre-push"; chmod +x "$TR5D/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR5D/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR5D/.forge/hooks/git/lib/check-red-first.sh"
mkrepo "$R5D" "$TR5D/.forge/hooks/git"
mkdir -p "$R5D/.forge/hooks/git/lib" "$R5D/.forge/scripts/tests"
cp "$TR5D/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R5D/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR5D/.forge/hooks/git/lib/check-red-first.sh" "$R5D/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5D/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R5D/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R5D/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R5D/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R5D/.forge/FORGE.md"
# runner PRÓPRIO, estrito: qualquer argumento (inclusive --path) sai 64; sem argumento, roda o
# teste (que passa) e sai 0.
printf '#!/usr/bin/env bash\n[ $# -eq 0 ] || exit 64\nexit 0\n' > "$R5D/.forge/scripts/tests/run-all.sh"
chmod +x "$R5D/.forge/scripts/tests/run-all.sh"
SHA5D="$(git -C "$R5D" rev-parse HEAD)"
out="$(cd "$R5D" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA5D" "$ZERO" | bash "$TR5D/.forge/hooks/git/pre-push" origin "file://$R5D" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [5d]: pre-push bloqueou com o runner próprio estrito — recebeu argumento que não deveria (saída: '$out')"; exit 1; }
case "$out" in
  *"harness-tests OK"*) : ;;
  *) echo "FAIL [5d]: harness-tests não passou pelo runner próprio (saída: '$out')"; exit 1 ;;
esac
echo "OK [5d]"

# ── [6] pre-push — lint de shell, com .sh no diff ───────────────────────────────────────────
echo "[6] pre-push — check-shell-pipeline.sh ausente na worktree, presente no tronco, .sh no diff"
R6="$T/r6"; TR6="$T/tr6"
mktrunk "$TR6"
cp "$HOOKS/pre-push" "$TR6/.forge/hooks/git/pre-push"; chmod +x "$TR6/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR6/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR6/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR6/.forge/scripts/check-shell-pipeline.sh"; chmod +x "$TR6/.forge/scripts/check-shell-pipeline.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR6/.forge/scripts/check-heredoc-hash.sh"; chmod +x "$TR6/.forge/scripts/check-heredoc-hash.sh"
mkrepo "$R6" "$TR6/.forge/hooks/git"
mkdir -p "$R6/.forge/hooks/git/lib" "$R6/.forge/scripts"
cp "$TR6/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R6/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR6/.forge/hooks/git/lib/check-red-first.sh" "$R6/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R6/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R6/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R6/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R6/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R6/.forge/FORGE.md"
printf 'echo hi\n' > "$R6/tool.sh"; git -C "$R6" add tool.sh >/dev/null 2>&1
git -C "$R6" commit -qm "chore: add tool.sh" >/dev/null 2>&1
SHA6="$(git -C "$R6" rev-parse HEAD)"
out="$(cd "$R6" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA6" "$ZERO" | bash "$TR6/.forge/hooks/git/pre-push" origin "file://$R6" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [6]: pre-push bloqueou com os lints presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"check-shell-pipeline.sh"*) : ;;
  *) echo "FAIL [6]: não nomeou o tronco para check-shell-pipeline.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [6]"

# ── [7] pre-push — contrafactual: ausente nas duas árvores ──────────────────────────────────
echo "[7] pre-push — AI_CHECK ausente nas duas árvores → continua bloqueando"
R7="$T/r7"; TR7="$T/tr7"
mktrunk "$TR7"
cp "$HOOKS/pre-push" "$TR7/.forge/hooks/git/pre-push"; chmod +x "$TR7/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR7/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR7/.forge/hooks/git/lib/check-red-first.sh"
mkrepo "$R7" "$TR7/.forge/hooks/git"
mkdir -p "$R7/.forge/hooks/git/lib" "$R7/.forge/scripts"   # check-ai-attribution.sh ausente nas duas
SHA7="$(git -C "$R7" rev-parse HEAD)"
out="$(cd "$R7" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA7" "$ZERO" | bash "$TR7/.forge/hooks/git/pre-push" origin "file://$R7" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [7]: pre-push passou com o alvo ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"check-ai-attribution.sh"*"alvo ausente"*) : ;;
  *) echo "FAIL [7]: bloqueou sem nomear o alvo ausente (saída: '$out')"; exit 1 ;;
esac
echo "OK [7]"

# ── [8] lib/check-red-first.sh — os dois alvos internos ─────────────────────────────────────
echo "[8] lib/check-red-first.sh — check-red-first.sh delegado e gate-universe.sh via tronco"
R8="$T/r8"; TR8="$T/tr8"
mkdir -p "$TR8/.forge/scripts/lib"
cp "$HOOKS/lib/check-red-first.sh" "$TR8/.forge/hooks-lib-check-red-first.sh" 2>/dev/null || true
mkdir -p "$TR8/.forge/hooks/git/lib"
cp "$HOOKS/lib/check-red-first.sh" "$TR8/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR8/.forge/scripts/check-red-first.sh"; chmod +x "$TR8/.forge/scripts/check-red-first.sh"
cat > "$TR8/.forge/scripts/lib/gate-universe.sh" <<'EOF'
#!/usr/bin/env bash
EOF
mkdir -p "$R8/.forge/scripts" "$R8/.forge/scripts/lib"   # dirs existem; os dois alvos, não
out="$(REPO="$R8" bash -c '
  set -u
  . "'"$TR8"'/.forge/hooks/git/lib/check-red-first.sh"
  check_red_first < /dev/null
' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [8]: check_red_first bloqueou com os dois alvos presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"check-red-first.sh"*) : ;;
  *) echo "FAIL [8]: não nomeou o tronco para check-red-first.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"gate-universe.sh"*) : ;;
  *) echo "FAIL [8]: não nomeou o tronco para gate-universe.sh (saída: '$out')"; exit 1 ;;
esac
echo "OK [8]"

# [8b] — MESMA cópia REAL de lib/check-red-first.sh (nunca um stub), isolada da pre-push/
# pre-commit/etc: $REPO sem .forge/ nenhum → check_red_first não consulta o tronco, não avisa e
# não toca os alvos internos (LOW-1: [14] usava um STUB `check_red_first() { return 0; }` no
# tronco, então a cópia REAL do resolvedor nunca era exercitada nesse cenário — só a de pre-push).
echo "[8b] lib/check-red-first.sh — REAL (sem stub), REPO sem .forge/ nenhum → no-op, sem"
echo "     consultar o tronco e sem o aviso 'rode forge update na worktree'"
R8B="$T/r8b"
mkdir -p "$R8B"   # REPO sem .forge/ nenhum — nem o diretório existe
out="$(REPO="$R8B" bash -c '
  set -u
  . "'"$TR8"'/.forge/hooks/git/lib/check-red-first.sh"
  check_red_first < /dev/null
' 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [8b]: check_red_first bloqueou numa árvore sem .forge/ nenhum (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*|*"rode forge update na worktree"*) echo "FAIL [8b]: consultou/nomeou o tronco numa árvore sem .forge/ nenhum (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
[ -z "$out" ] || { echo "FAIL [8b]: esperava saída vazia (no-op silencioso), obteve: '$out'"; exit 1; }
echo "OK [8b]"

# ── [9] AUTO-IRONIA ──────────────────────────────────────────────────────────────────────────
# Sem `declare -A`: o bash 3.2 do macOS (issue de portabilidade irmã do w97) não tem array
# associativo. Pares "hook:esperado" numa lista simples, um por linha.
echo "[9] os 16 sítios (12 de L3 §0 + RUNTIME_LIB + gate-phase.mjs + os 2 sítios de aviso, achados"
echo "    do adendo de revisão do w223) chamam o mesmo resolvedor — contagem + corpo"
total=0
for par in "pre-commit:1" "commit-msg:1" "post-merge:2" "pre-push:10"; do
  h="${par%%:*}"; esperado="${par##*:}"
  # `\$\(resolve_delegated ` — só a INVOCAÇÃO real (substituição de comando), nunca a linha da
  # definição nem o comentário que a documenta (que também contém o nome da função de propósito).
  n="$(grep -cE '\$\(resolve_delegated ' "$HOOKS/$h" 2>/dev/null || true)"
  n="${n:-0}"
  total=$((total + n))
  [ "$n" -eq "$esperado" ] || { echo "FAIL [9]: $h — esperava $esperado chamada(s) a resolve_delegated, achei $n"; exit 1; }
done
n_rf="$(grep -cE '\$\(_redfirst_resolve_delegated ' "$HOOKS/lib/check-red-first.sh" 2>/dev/null || true)"
n_rf="${n_rf:-0}"
total=$((total + n_rf))
[ "$n_rf" -eq 2 ] || { echo "FAIL [9]: lib/check-red-first.sh — esperava 2 chamadas ao resolvedor interno, achei $n_rf"; exit 1; }
[ "$total" -eq 16 ] || { echo "FAIL [9]/vacuidade — total de sítios contados foi $total, esperado 16 (L3 §0: pre-push 10 [6 + RUNTIME_LIB + gate-phase.mjs + log-integrity + worktree-prereqs], pre-commit 1, commit-msg 1, post-merge 2, check-red-first.sh 2)"; exit 1; }
echo "OK [9] — 16 sítios cobertos ($total)"

# Identidade byte a byte do CORPO da função entre as 4 cópias (pre-commit, commit-msg, post-merge,
# pre-push): a contagem acima só prova que cada arquivo CHAMA o resolvedor o número certo de vezes,
# nunca que as 4 definições continuam a MESMA função — uma correção aplicada numa cópia só passaria
# verde no laço acima. A quinta cópia (_redfirst_resolve_delegated, lib/check-red-first.sh) NÃO
# entra na comparação byte a byte porque tem duas diferenças ESTRUTURAIS legítimas — nome da
# variável de árvore (REPO em vez de ROOT) e a obtenção do diretório do tronco (a função
# _redfirst_hook_forge_dir em vez da variável global HOOK_FORGE_DIR, porque esta lib pode ser
# sourced a partir de árvores diferentes em chamadas diferentes) — então é comparada separadamente,
# com essas duas diferenças normalizadas antes do diff; sem esta segunda comparação, uma correção
# aplicada só nas 4 cópias-irmãs passaria verde com a quinta cópia divergente.
echo "[9b] as 4 cópias de resolve_delegated() têm o corpo byte a byte idêntico, e"
echo "     _redfirst_resolve_delegated() é o mesmo código, normalizando REPO/ROOT e a lib"
body_pc="$(awk '/^resolve_delegated\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOKS/pre-commit")"
for h in commit-msg post-merge pre-push; do
  body_h="$(awk '/^resolve_delegated\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOKS/$h")"
  [ "$body_pc" = "$body_h" ] || { echo "FAIL [9b]: resolve_delegated() em $h diverge de pre-commit — correção aplicada só numa cópia"; exit 1; }
done
# strip_code: remove comentários de linha inteira, linhas em branco, e o comentário à direita do
# cabeçalho da função (único trecho onde o texto do comentário difere entre as duas por nomear a
# própria função) — preserva todo o CÓDIGO, inclusive strings com texto de mensagem de erro.
strip_code() { grep -vE '^[[:space:]]*#' | sed -E '/^[[:space:]]*$/d' | sed -E 's/^([a-zA-Z_]+\(\) \{)[[:space:]]*#.*/\1/'; }
code_pc="$(printf '%s\n' "$body_pc" | strip_code)"
body_rf="$(awk '/^_redfirst_resolve_delegated\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOKS/lib/check-red-first.sh")"
code_rf="$(printf '%s\n' "$body_rf" | strip_code | sed -E \
  -e 's/_redfirst_resolve_delegated/resolve_delegated/' \
  -e 's/\$REPO/\$ROOT/g' \
  -e 's/ hook_forge_dir wt_dir/ wt_dir/' \
  -e '/^[[:space:]]*hook_forge_dir="\$\(_redfirst_hook_forge_dir\)"$/d' \
  -e 's/\$hook_forge_dir/\$HOOK_FORGE_DIR/g')"
[ "$code_pc" = "$code_rf" ] || {
  echo "FAIL [9b]: _redfirst_resolve_delegated diverge de resolve_delegated além de REPO/ROOT e da obtenção do diretório do tronco"
  diff <(printf '%s\n' "$code_pc") <(printf '%s\n' "$code_rf") || true
  exit 1
}
echo "OK [9b] — 4 cópias idênticas + _redfirst_resolve_delegated equivalente"

# ── [10] pre-push — RUNTIME_LIB (forge-runtime.sh) via tronco ───────────────────────────────
echo "[10] pre-push — forge-runtime.sh ausente na worktree, presente no tronco, gates: declarado"
R10="$T/r10"; TR10="$T/tr10"
mktrunk "$TR10"
cp "$HOOKS/pre-push" "$TR10/.forge/hooks/git/pre-push"; chmod +x "$TR10/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR10/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR10/.forge/hooks/git/lib/check-red-first.sh"
# forge-runtime.sh REAL do template no tronco — só ele existe, nunca na worktree.
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR10/.forge/scripts/lib/forge-runtime.sh"
mkrepo "$R10" "$TR10/.forge/hooks/git"
mkdir -p "$R10/.forge/hooks/git/lib" "$R10/.forge/scripts/lib"   # o diretório existe; o arquivo, não
cp "$TR10/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R10/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR10/.forge/hooks/git/lib/check-red-first.sh" "$R10/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R10/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R10/.forge/scripts/check-liaison-acks.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.forge/scripts/meu-gate.sh"; chmod +x "$R10/.forge/scripts/meu-gate.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n  gates: meu-gate\n' > "$R10/.forge/FORGE.md"
SHA10="$(git -C "$R10" rev-parse HEAD)"
out="$(cd "$R10" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA10" "$ZERO" | bash "$TR10/.forge/hooks/git/pre-push" origin "file://$R10" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [10]: pre-push bloqueou com forge-runtime.sh presente no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"forge-runtime.sh"*) : ;;
  *) echo "FAIL [10]: não nomeou o tronco para forge-runtime.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"meu-gate OK"*) : ;;
  *) echo "FAIL [10]: o leitor emprestado do tronco não rodou o gate declarado (saída: '$out')"; exit 1 ;;
esac
echo "OK [10]"

# ── [10b] pre-push — forma MAPEADA: forge-runtime.sh e gate-phase.mjs via tronco ─────────────
# Achado HIGH do adendo de revisão do w223: o guarda do gate-phase.mjs checava `$ROOT` literal e bloqueava mesmo com RUNTIME_LIB já resolvido para o tronco (a mesma classe do #141, no sítio que a correção original de #141 não cobria).
echo "[10b] pre-push — forma mapeada: forge-runtime.sh E gate-phase.mjs ausentes na worktree,"
echo "      presentes no tronco → não bloqueia, roda o gate declarado"
R10B="$T/r10b"; TR10B="$T/tr10b"
mktrunk "$TR10B"
cp "$HOOKS/pre-push" "$TR10B/.forge/hooks/git/pre-push"; chmod +x "$TR10B/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR10B/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR10B/.forge/hooks/git/lib/check-red-first.sh"
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR10B/.forge/scripts/lib/forge-runtime.sh"
cp "$WS/template/.forge/scripts/lib/gate-phase.mjs" "$TR10B/.forge/scripts/lib/gate-phase.mjs"
cp "$WS/template/.forge/scripts/lib/yaml-lite.mjs" "$TR10B/.forge/scripts/lib/yaml-lite.mjs"
mkrepo "$R10B" "$TR10B/.forge/hooks/git"
mkdir -p "$R10B/.forge/hooks/git/lib" "$R10B/.forge/scripts/lib"   # dirs existem; os dois alvos, não
cp "$TR10B/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R10B/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR10B/.forge/hooks/git/lib/check-red-first.sh" "$R10B/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10B/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R10B/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10B/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R10B/.forge/scripts/check-liaison-acks.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10B/.forge/scripts/meu-gate-mapeado.sh"; chmod +x "$R10B/.forge/scripts/meu-gate-mapeado.sh"
# O leitor da forma MAPEADA (gate-phase.mjs) lê `runtime:` de DENTRO do frontmatter YAML (entre
# os dois `---`), diferente do leitor CSV (`forge_get_runtime`, um awk que varre o arquivo
# inteiro) — por isso aqui, ao contrário das fixtures CSV deste gate, o bloco vai dentro dele.
printf -- '---\nforge_version: 1\nruntime:\n  test:\n  typecheck:\n  gates:\n    - meu-gate-mapeado\n---\n\n# FORGE\n' > "$R10B/.forge/FORGE.md"
SHA10B="$(git -C "$R10B" rev-parse HEAD)"
out="$(cd "$R10B" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA10B" "$ZERO" | bash "$TR10B/.forge/hooks/git/pre-push" origin "file://$R10B" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [10b]: pre-push bloqueou com forge-runtime.sh e gate-phase.mjs presentes no tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"forge-runtime.sh"*) : ;;
  *) echo "FAIL [10b]: não nomeou o tronco para forge-runtime.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"gate-phase.mjs"*) : ;;
  *) echo "FAIL [10b]: não nomeou o tronco para gate-phase.mjs (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"meu-gate-mapeado OK"*) : ;;
  *) echo "FAIL [10b]: o gate da forma mapeada, emprestando o leitor do tronco, não rodou (saída: '$out')"; exit 1 ;;
esac
echo "OK [10b]"

# ── [10c] pre-push — contrafactual: gate-phase.mjs ausente nas DUAS árvores ─────────────────
echo "[10c] pre-push — forma mapeada: forge-runtime.sh compatível nas DUAS árvores, mas"
echo "      gate-phase.mjs ausente nas duas → continua BLOQUEANDO"
R10C="$T/r10c"; TR10C="$T/tr10c"
mktrunk "$TR10C"
cp "$HOOKS/pre-push" "$TR10C/.forge/hooks/git/pre-push"; chmod +x "$TR10C/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR10C/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR10C/.forge/hooks/git/lib/check-red-first.sh"
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR10C/.forge/scripts/lib/forge-runtime.sh"
# gate-phase.mjs NÃO existe no tronco.
mkrepo "$R10C" "$TR10C/.forge/hooks/git"
mkdir -p "$R10C/.forge/hooks/git/lib" "$R10C/.forge/scripts/lib"
cp "$TR10C/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R10C/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR10C/.forge/hooks/git/lib/check-red-first.sh" "$R10C/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10C/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R10C/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10C/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R10C/.forge/scripts/check-liaison-acks.sh"
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$R10C/.forge/scripts/lib/forge-runtime.sh"
# gate-phase.mjs NÃO existe na worktree também — o par completo não existe em lugar nenhum.
printf -- '---\nforge_version: 1\nruntime:\n  test:\n  typecheck:\n  gates:\n    - meu-gate-mapeado\n---\n\n# FORGE\n' > "$R10C/.forge/FORGE.md"
SHA10C="$(git -C "$R10C" rev-parse HEAD)"
out="$(cd "$R10C" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA10C" "$ZERO" | bash "$TR10C/.forge/hooks/git/pre-push" origin "file://$R10C" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [10c]: pre-push passou sem gate-phase.mjs em lugar nenhum (saída: '$out')"; exit 1; }
case "$out" in
  *"NÃO PÔDE SER LIDA"*) : ;;
  *) echo "FAIL [10c]: bloqueou sem dizer que a declaração não pôde ser lida (saída: '$out')"; exit 1 ;;
esac
echo "OK [10c]"

# ── [10d] pre-push — forge-runtime.sh PRÓPRIO e compatível, gate-phase.mjs só no tronco ─────
# Mutante sobrevivente do achado MEDIUM do adendo de revisão do w223: [10b] só cobre o caso em
# que forge-runtime.sh E gate-phase.mjs faltam JUNTOS na worktree — aí RUNTIME_LIB já vem do
# tronco e a troca de par (linha "$_gp_dir" != "$(dirname "$RUNTIME_LIB")") não faz nada, porque
# as duas resoluções já coincidem. Este cenário isola a troca de verdade: RUNTIME_LIB resolve
# para a PRÓPRIA worktree (o arquivo existe lá e É compatível — tem forge_runtime_gate_entries),
# mas gate-phase.mjs só existe no tronco. Sem a troca das DUAS variáveis juntas,
# forge_runtime_gate_entries (sourced da worktree) buscaria gate-phase.mjs pelo `script_dir`
# INTERNO da própria lib (a worktree), onde ele não existe, e devolveria vazio em silêncio —
# "NO-GATES", pre-push OK, rc 0, sem o gate declarado nunca rodar.
echo "[10d] pre-push — forma mapeada: forge-runtime.sh PRÓPRIO da worktree (compatível), mas"
echo "      gate-phase.mjs só no tronco → troca as DUAS para o tronco e RODA o gate, que FALHA"
R10D="$T/r10d"; TR10D="$T/tr10d"
mktrunk "$TR10D"
cp "$HOOKS/pre-push" "$TR10D/.forge/hooks/git/pre-push"; chmod +x "$TR10D/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR10D/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR10D/.forge/hooks/git/lib/check-red-first.sh"
# tronco tem o PAR completo (forge-runtime.sh + gate-phase.mjs + yaml-lite.mjs).
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR10D/.forge/scripts/lib/forge-runtime.sh"
cp "$WS/template/.forge/scripts/lib/gate-phase.mjs" "$TR10D/.forge/scripts/lib/gate-phase.mjs"
cp "$WS/template/.forge/scripts/lib/yaml-lite.mjs" "$TR10D/.forge/scripts/lib/yaml-lite.mjs"
mkrepo "$R10D" "$TR10D/.forge/hooks/git"
mkdir -p "$R10D/.forge/hooks/git/lib" "$R10D/.forge/scripts/lib"
cp "$TR10D/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R10D/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR10D/.forge/hooks/git/lib/check-red-first.sh" "$R10D/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10D/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R10D/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10D/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R10D/.forge/scripts/check-liaison-acks.sh"
# forge-runtime.sh PRÓPRIO da worktree, compatível (mesma cópia do template — tem
# forge_runtime_gate_entries); gate-phase.mjs NÃO existe aqui.
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$R10D/.forge/scripts/lib/forge-runtime.sh"
printf '#!/usr/bin/env bash\necho "meu-gate-mapeado RODOU-E-FALHOU"\nexit 1\n' > "$R10D/.forge/scripts/meu-gate-mapeado.sh"
chmod +x "$R10D/.forge/scripts/meu-gate-mapeado.sh"
printf -- '---\nforge_version: 1\nruntime:\n  test:\n  typecheck:\n  gates:\n    - meu-gate-mapeado\n---\n\n# FORGE\n' > "$R10D/.forge/FORGE.md"
SHA10D="$(git -C "$R10D" rev-parse HEAD)"
out="$(cd "$R10D" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA10D" "$ZERO" | bash "$TR10D/.forge/hooks/git/pre-push" origin "file://$R10D" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [10d]: pre-push passou (rc 0) com gate-phase.mjs só no tronco e gate declarado que deveria FALHAR — silêncio verde (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"gate-phase.mjs"*) : ;;
  *) echo "FAIL [10d]: não nomeou a troca para o tronco de gate-phase.mjs (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"meu-gate-mapeado RODOU-E-FALHOU"*) : ;;
  *) echo "FAIL [10d]: o gate da forma mapeada não rodou de verdade (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"NO-GATES"*) echo "FAIL [10d]: saída contém NO-GATES — o par não foi trocado, silêncio verde (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [10d]"

# ── [11] pre-push — recusa nomeia AS DUAS árvores procuradas ────────────────────────────────
echo "[11] pre-push — alvo ausente nas duas árvores: a recusa nomeia onde procurou, nunca afirma"
echo "     presença falsa de diretório que só existe numa delas"
R11="$T/r11"; TR11="$T/tr11"
mkdir -p "$TR11/.forge/hooks/git/lib" "$TR11/.forge/scripts/lib" "$TR11/.forge/scripts/tests"
printf '#!/usr/bin/env bash\nforge_heavy_mutex_acquire() { return 0; }\nforge_heavy_mutex_arm_trap() { :; }\n' \
  > "$TR11/.forge/scripts/lib/heavy-mutex.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TR11/.forge/scripts/tests/run-all.sh"; chmod +x "$TR11/.forge/scripts/tests/run-all.sh"
cp "$HOOKS/pre-push" "$TR11/.forge/hooks/git/pre-push"; chmod +x "$TR11/.forge/hooks/git/pre-push"
# check-docs-reviewed.sh AUSENTE no tronco também — só o DIRETÓRIO hooks/git/lib existe lá.
mkrepo "$R11" "$TR11/.forge/hooks/git"
mkdir -p "$R11/.forge/scripts"   # worktree SEM .forge/hooks/git/lib nenhum (diretório não existe)
SHA11="$(git -C "$R11" rev-parse HEAD)"
out="$(cd "$R11" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA11" "$ZERO" | bash "$TR11/.forge/hooks/git/pre-push" origin "file://$R11" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [11]: pre-push passou com check-docs-reviewed.sh ausente nas duas árvores (saída: '$out')"; exit 1; }
case "$out" in
  *"alvo ausente"*) : ;;
  *) echo "FAIL [11]: bloqueou sem o texto literal de alvo ausente (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"(procurado em $R11/.forge/hooks/git/lib"*"$TR11/.forge/hooks/git/lib"*")"*) : ;;
  *) echo "FAIL [11]: a recusa não nomeia as DUAS árvores procuradas, ou nomeia caminho errado (saída: '$out')"; exit 1 ;;
esac
[ ! -d "$R11/.forge/hooks/git/lib" ] || { echo "FAIL [11]/setup: o diretório da worktree não deveria existir neste cenário"; exit 1; }
echo "OK [11]"

# ── [12] pre-push — worktree tem SUA PRÓPRIA forge-runtime.sh, mas incompatível ─────────────
# Achado MEDIUM do adendo de revisão do w223: RUNTIME_LIB resolve para a worktree (o arquivo existe lá — resolve_delegated não julga versão), mas é uma cópia real de v0.10.0, anterior a #82, sem forge_runtime_gate_entries. Sem a troca, a chamada era "command not found" engolida por `|| true`, e o push saía "NO-GATES", rc 0, com o gate declarado NUNCA rodando.
echo "[12] pre-push — forge-runtime.sh PRÓPRIO da worktree é v0.10.0 (sem forge_runtime_gate_entries);"
echo "     tronco tem a lib compatível; CSV declara um gate que falha → troca para o tronco e RODA"
R12="$T/r12"; TR12="$T/tr12"
mktrunk "$TR12"
cp "$HOOKS/pre-push" "$TR12/.forge/hooks/git/pre-push"; chmod +x "$TR12/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR12/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR12/.forge/hooks/git/lib/check-red-first.sh"
cp "$WS/template/.forge/scripts/lib/forge-runtime.sh" "$TR12/.forge/scripts/lib/forge-runtime.sh"
mkrepo "$R12" "$TR12/.forge/hooks/git"
mkdir -p "$R12/.forge/hooks/git/lib" "$R12/.forge/scripts/lib"
cp "$TR12/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R12/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR12/.forge/hooks/git/lib/check-red-first.sh" "$R12/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R12/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R12/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R12/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R12/.forge/scripts/check-liaison-acks.sh"
# cópia REAL de v0.10.0 (anterior a #82) — arquivo próprio da worktree, não emprestado.
git -C "$WS" show v0.10.0:template/.forge/scripts/lib/forge-runtime.sh > "$R12/.forge/scripts/lib/forge-runtime.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$R12/.forge/scripts/meu-gate.sh"; chmod +x "$R12/.forge/scripts/meu-gate.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n  gates: meu-gate\n' > "$R12/.forge/FORGE.md"
SHA12="$(git -C "$R12" rev-parse HEAD)"
out="$(cd "$R12" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA12" "$ZERO" | bash "$TR12/.forge/hooks/git/pre-push" origin "file://$R12" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [12]: pre-push passou (rc 0) com forge-runtime.sh incompatível e gate declarado — deveria trocar para o tronco e RODAR o gate, que falha (saída: '$out')"; exit 1; }
case "$out" in
  *"não tem forge_runtime_gate_entries"*"usando o do tronco"*) : ;;
  *) echo "FAIL [12]: não nomeou a troca para o tronco por incompatibilidade de API (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"meu-gate falhou"*) : ;;
  *) echo "FAIL [12]: o gate declarado não rodou de verdade após a troca (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"NO-GATES"*) echo "FAIL [12]: saída ainda contém NO-GATES — a troca não eliminou o falso silêncio (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [12]"

# ── [12b] pre-push — contrafactual: as DUAS árvores com lib incompatível ────────────────────
echo "[12b] pre-push — forge-runtime.sh v0.10.0 na worktree E no tronco (as duas incompatíveis)"
echo "      → BLOQUEIA nomeando a incompatibilidade, nunca silêncio verde"
R12B="$T/r12b"; TR12B="$T/tr12b"
mktrunk "$TR12B"
cp "$HOOKS/pre-push" "$TR12B/.forge/hooks/git/pre-push"; chmod +x "$TR12B/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR12B/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR12B/.forge/hooks/git/lib/check-red-first.sh"
git -C "$WS" show v0.10.0:template/.forge/scripts/lib/forge-runtime.sh > "$TR12B/.forge/scripts/lib/forge-runtime.sh"
mkrepo "$R12B" "$TR12B/.forge/hooks/git"
mkdir -p "$R12B/.forge/hooks/git/lib" "$R12B/.forge/scripts/lib"
cp "$TR12B/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R12B/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR12B/.forge/hooks/git/lib/check-red-first.sh" "$R12B/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R12B/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R12B/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R12B/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R12B/.forge/scripts/check-liaison-acks.sh"
git -C "$WS" show v0.10.0:template/.forge/scripts/lib/forge-runtime.sh > "$R12B/.forge/scripts/lib/forge-runtime.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$R12B/.forge/scripts/meu-gate.sh"; chmod +x "$R12B/.forge/scripts/meu-gate.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n  gates: meu-gate\n' > "$R12B/.forge/FORGE.md"
SHA12B="$(git -C "$R12B" rev-parse HEAD)"
out="$(cd "$R12B" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA12B" "$ZERO" | bash "$TR12B/.forge/hooks/git/pre-push" origin "file://$R12B" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [12b]: pre-push passou com as DUAS árvores incompatíveis — deveria bloquear (saída: '$out')"; exit 1; }
case "$out" in
  *"não tem forge_runtime_gate_entries"*) : ;;
  *) echo "FAIL [12b]: bloqueou sem nomear a causa (incompatibilidade de API) (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"NO-GATES"*) echo "FAIL [12b]: saída contém NO-GATES — silêncio verde disfarçado (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
echo "OK [12b]"

# ── [13] pre-push — sítios de AVISO (nunca bloqueio) via tronco ─────────────────────────────
# Achado LOW do adendo de revisão do w223: check-liaison-log-integrity.sh e check-worktree-prereqs.sh checavam só `$ROOT` literal — perdiam a checagem em silêncio quando só o tronco tinha o script, em vez de rodá-lo de lá como os sítios de bloqueio já faziam.
echo "[13] pre-push — check-liaison-log-integrity.sh e check-worktree-prereqs.sh ausentes na"
echo "     worktree, presentes no tronco → RODAM de verdade a partir do tronco"
R13="$T/r13"; TR13="$T/tr13"
mktrunk "$TR13"
cp "$HOOKS/pre-push" "$TR13/.forge/hooks/git/pre-push"; chmod +x "$TR13/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR13/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR13/.forge/hooks/git/lib/check-red-first.sh"
MARK_LI="$T/marker-logintegrity-13"; MARK_PQ="$T/marker-prereqs-13"
rm -f "$MARK_LI" "$MARK_PQ"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_LI" > "$TR13/.forge/scripts/check-liaison-log-integrity.sh"
chmod +x "$TR13/.forge/scripts/check-liaison-log-integrity.sh"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_PQ" > "$TR13/.forge/scripts/check-worktree-prereqs.sh"
chmod +x "$TR13/.forge/scripts/check-worktree-prereqs.sh"
mkrepo "$R13" "$TR13/.forge/hooks/git"
mkdir -p "$R13/.forge/hooks/git/lib" "$R13/.forge/scripts/lib"
cp "$TR13/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R13/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR13/.forge/hooks/git/lib/check-red-first.sh" "$R13/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R13/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R13/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R13/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R13/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R13/.forge/FORGE.md"
SHA13="$(git -C "$R13" rev-parse HEAD)"
out="$(cd "$R13" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA13" "$ZERO" | bash "$TR13/.forge/hooks/git/pre-push" origin "file://$R13" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [13]: pre-push bloqueou com os dois avisos resolvidos via tronco (saída: '$out')"; exit 1; }
case "$out" in
  *"usando o do tronco"*"check-liaison-log-integrity.sh"*) : ;;
  *) echo "FAIL [13]: não nomeou o tronco para check-liaison-log-integrity.sh (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"usando o do tronco"*"check-worktree-prereqs.sh"*) : ;;
  *) echo "FAIL [13]: não nomeou o tronco para check-worktree-prereqs.sh (saída: '$out')"; exit 1 ;;
esac
[ -f "$MARK_LI" ] || { echo "FAIL [13]: check-liaison-log-integrity.sh do tronco não rodou de verdade (marcador ausente)"; exit 1; }
[ -f "$MARK_PQ" ] || { echo "FAIL [13]: check-worktree-prereqs.sh do tronco não rodou de verdade (marcador ausente)"; exit 1; }
echo "OK [13]"

# ── [13b] pre-push — contrafactual: os dois ausentes nas DUAS árvores ───────────────────────
echo "[13b] pre-push — check-liaison-log-integrity.sh e check-worktree-prereqs.sh ausentes nas"
echo "      DUAS árvores → continuam como AVISO 'NÃO VERIFICADO', nunca bloqueio"
R13B="$T/r13b"; TR13B="$T/tr13b"
mktrunk "$TR13B"
cp "$HOOKS/pre-push" "$TR13B/.forge/hooks/git/pre-push"; chmod +x "$TR13B/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR13B/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR13B/.forge/hooks/git/lib/check-red-first.sh"
# check-liaison-log-integrity.sh e check-worktree-prereqs.sh AUSENTES no tronco também.
mkrepo "$R13B" "$TR13B/.forge/hooks/git"
mkdir -p "$R13B/.forge/hooks/git/lib" "$R13B/.forge/scripts/lib"
cp "$TR13B/.forge/hooks/git/lib/check-docs-reviewed.sh" "$R13B/.forge/hooks/git/lib/check-docs-reviewed.sh"
cp "$TR13B/.forge/hooks/git/lib/check-red-first.sh" "$R13B/.forge/hooks/git/lib/check-red-first.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R13B/.forge/scripts/check-ai-attribution.sh"; chmod +x "$R13B/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R13B/.forge/scripts/check-liaison-acks.sh"; chmod +x "$R13B/.forge/scripts/check-liaison-acks.sh"
printf -- '---\nforge_version: 1\n---\n\n# FORGE\n\nruntime:\n  test:\n  typecheck:\n' > "$R13B/.forge/FORGE.md"
SHA13B="$(git -C "$R13B" rev-parse HEAD)"
out="$(cd "$R13B" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA13B" "$ZERO" | bash "$TR13B/.forge/hooks/git/pre-push" origin "file://$R13B" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [13b]: pre-push bloqueou com os dois avisos ausentes nas duas árvores — deveria só avisar (saída: '$out')"; exit 1; }
grep -q "check-liaison-log-integrity.sh" <<<"$out" || { echo "FAIL [13b]: não nomeia check-liaison-log-integrity.sh (saída: '$out')"; exit 1; }
grep -q "check-worktree-prereqs.sh" <<<"$out" || { echo "FAIL [13b]: não nomeia check-worktree-prereqs.sh (saída: '$out')"; exit 1; }
[ "$(grep -c "NÃO VERIFICADO" <<<"$out")" -ge 2 ] || { echo "FAIL [13b]: não avisou 'NÃO VERIFICADO' duas vezes, uma por sítio (saída: '$out')"; exit 1; }
echo "OK [13b]"

# ── [14] pre-push — worktree de branch anterior à adoção do harness, SEM .forge/ nenhum ─────
# Decisão do orquestrador (registrada no CHANGELOG e no corpo do commit): árvore sem $ROOT/.forge
# nenhum é árvore NÃO GERENCIADA — nunca é uma worktree defasada. O resolvedor devolve o mesmo
# no-op de antes da #141 (rc 2): NÃO consulta o tronco, NÃO avisa e NÃO tem efeito colateral. A
# defesa em profundidade da rodada anterior (rodar os scripts do tronco de verdade, só suprimindo
# o aviso) foi revertida: medido no consumidor do tarball, ela fazia o pre-push de uma branch órfã
# ser checado por scripts de um repositório inteiro alheio, sem o dono da árvore ter pedido isso.
echo "[14] pre-push — worktree SEM .forge/ nenhum (branch anterior à adoção do harness) → rc 0,"
echo "     SEM rodar nenhum script do tronco e SEM a linha 'rode forge update na worktree'"
R14="$T/r14"; TR14="$T/tr14"
mktrunk "$TR14"
cp "$HOOKS/pre-push" "$TR14/.forge/hooks/git/pre-push"; chmod +x "$TR14/.forge/hooks/git/pre-push"
printf '#!/usr/bin/env bash\ncheck_docs_reviewed() { return 0; }\n' > "$TR14/.forge/hooks/git/lib/check-docs-reviewed.sh"
printf '#!/usr/bin/env bash\ncheck_red_first() { return 0; }\n' > "$TR14/.forge/hooks/git/lib/check-red-first.sh"
MARK_AI14="$T/marker-ai-14"; MARK_ACKS14="$T/marker-acks-14"
rm -f "$MARK_AI14" "$MARK_ACKS14"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_AI14" > "$TR14/.forge/scripts/check-ai-attribution.sh"
chmod +x "$TR14/.forge/scripts/check-ai-attribution.sh"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_ACKS14" > "$TR14/.forge/scripts/check-liaison-acks.sh"
chmod +x "$TR14/.forge/scripts/check-liaison-acks.sh"
mkrepo "$R14" "$TR14/.forge/hooks/git"
# worktree SEM .forge/ nenhum — nem o diretório existe. Não é "harness atualizado pela metade",
# é uma árvore que nunca teve harness instalado.
SHA14="$(git -C "$R14" rev-parse HEAD)"
out="$(cd "$R14" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA14" "$ZERO" | bash "$TR14/.forge/hooks/git/pre-push" origin "file://$R14" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14]: pre-push bloqueou numa worktree sem .forge/ nenhum (saída: '$out')"; exit 1; }
case "$out" in
  *"pre-push OK (sem harness)"*) : ;;
  *) echo "FAIL [14]: não terminou com 'pre-push OK (sem harness)' (saída: '$out')"; exit 1 ;;
esac
case "$out" in
  *"rode forge update na worktree"*) echo "FAIL [14]: o aviso 'rode forge update na worktree' apareceu numa árvore que nunca teve harness (saída: '$out')"; exit 1 ;;
  *"usando o do tronco"*) echo "FAIL [14]: nomeou o tronco numa árvore que nunca teve harness (saída: '$out')"; exit 1 ;;
  *) : ;;
esac
[ ! -d "$R14/.forge" ] || { echo "FAIL [14]/setup: a worktree não deveria ter .forge/ neste cenário"; exit 1; }
echo "OK [14]"

# [14-cf] contrafactual do [14]: MESMA árvore, mas com $ROOT/.forge presente (só o diretório, sem
# FORGE.md) — a delegação ao tronco volta a valer de verdade (marcador tocado, aviso nomeando-o).
# Prova que a supressão do [14] é sobre a AUSÊNCIA de .forge/, nunca sobre a ausência de FORGE.md.
echo "[14-cf] pre-push — contrafactual do [14]: .forge/ presente (só o diretório) → delegação ao"
echo "        tronco continua rodando de verdade, com o aviso nomeando-o"
R14CF="$T/r14cf"
mktrunk "$TR14"  # reaproveita o tronco de [14], já com os marcadores no lugar
mkdir -p "$R14CF/.forge/scripts"
git init -q -b main "$R14CF"
git -C "$R14CF" config user.email t@t; git -C "$R14CF" config user.name t; git -C "$R14CF" config commit.gpgsign false
git -C "$R14CF" config core.hooksPath "$TR14/.forge/hooks/git"
printf 'x\n' > "$R14CF/a.txt"; git -C "$R14CF" add -A >/dev/null 2>&1
git -C "$R14CF" commit -qm "chore: init" >/dev/null 2>&1
rm -f "$MARK_AI14" "$MARK_ACKS14"
SHA14CF="$(git -C "$R14CF" rev-parse HEAD)"
out="$(cd "$R14CF" && printf 'refs/heads/main %s refs/heads/main %s\n' "$SHA14CF" "$ZERO" | bash "$TR14/.forge/hooks/git/pre-push" origin "file://$R14CF" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14-cf]: pre-push bloqueou com .forge/ presente e alvo só no tronco (saída: '$out')"; exit 1; }
[ -f "$MARK_AI14" ] || { echo "FAIL [14-cf]: check-ai-attribution.sh do tronco não rodou — .forge/ presente deveria delegar de verdade"; exit 1; }
[ -f "$MARK_ACKS14" ] || { echo "FAIL [14-cf]: check-liaison-acks.sh do tronco não rodou — .forge/ presente deveria delegar de verdade"; exit 1; }
case "$out" in
  *"usando o do tronco"*"rode forge update na worktree"*) : ;;
  *) echo "FAIL [14-cf]: não nomeou o tronco nem instruiu 'forge update' (saída: '$out')"; exit 1 ;;
esac
echo "OK [14-cf]"

# ── [14b] post-merge — mesma árvore SEM .forge/ nenhum, com CHANGELOG.md versionado ─────────────
# MEDIUM: antes desta correção, o merge ainda delegava changelog-from-merge.mjs ao tronco (só o
# AVISO tinha sido suprimido na rodada anterior) e escrevia no CHANGELOG.md de uma árvore que nunca
# adotou o harness. Agora: sem .forge/ nenhum, post-merge não delega nada, e `git status` fica
# LIMPO depois do merge — nenhuma escrita numa árvore não gerenciada.
echo "[14b] post-merge — worktree SEM .forge/ nenhum, CHANGELOG.md versionado → git status LIMPO"
echo "      depois do merge (nenhuma escrita do tronco numa árvore não gerenciada)"
R14B="$T/r14b"; TR14B="$T/tr14b"
mktrunk "$TR14B"
cp "$HOOKS/post-merge" "$TR14B/.forge/hooks/git/post-merge"; chmod +x "$TR14B/.forge/hooks/git/post-merge"
MARK_CL14B="$T/marker-changelog-14b"
rm -f "$MARK_CL14B"
printf 'import { writeFileSync } from "fs";\nwriteFileSync(process.argv[2] + "/CHANGELOG.md", "mutated-by-trunk\\n", {flag:"a"});\n' \
  > "$TR14B/.forge/scripts/lib/changelog-from-merge.mjs"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_CL14B" > "$TR14B/.forge/scripts/check-liaison-log-integrity.sh"
chmod +x "$TR14B/.forge/scripts/check-liaison-log-integrity.sh"
mkrepo "$R14B" "$TR14B/.forge/hooks/git"
printf '# Changelog\n\n## [Unreleased]\n' > "$R14B/CHANGELOG.md"
git -C "$R14B" add CHANGELOG.md >/dev/null 2>&1
git -C "$R14B" commit -qm "chore: changelog" >/dev/null 2>&1
git -C "$R14B" checkout -qb feature >/dev/null 2>&1
printf 'y\n' > "$R14B/b.txt"; git -C "$R14B" add b.txt >/dev/null 2>&1
git -C "$R14B" commit -qm "feat: coisa" >/dev/null 2>&1
git -C "$R14B" checkout -q main >/dev/null 2>&1
git -C "$R14B" merge -q --no-ff feature -m "merge feature" >/dev/null 2>&1
# worktree SEM .forge/ nenhum — nem o diretório existe.
out="$(cd "$R14B" && bash "$TR14B/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14b]: post-merge falhou numa árvore sem .forge/ nenhum (saída: '$out')"; exit 1; }
status="$(git -C "$R14B" status --porcelain)"
[ -z "$status" ] || { echo "FAIL [14b]: git status não ficou limpo depois do merge (status: '$status')"; exit 1; }
[ ! -f "$MARK_CL14B" ] || { echo "FAIL [14b]: check-liaison-log-integrity.sh do tronco RODOU numa árvore sem .forge/ nenhum"; exit 1; }
[ ! -d "$R14B/.forge" ] || { echo "FAIL [14b]/setup: a worktree não deveria ter .forge/ neste cenário"; exit 1; }
echo "OK [14b]"

# [14b-cf] contrafactual do [14b]: MESMA árvore, mas com .forge/scripts/lib/ presente (só o
# diretório, sem changelog-from-merge.mjs próprio) → volta a delegar ao tronco de verdade, e o
# CHANGELOG.md RECEBE a escrita (prova que [14b] não é "o merge nunca escreve", é "árvore sem
# .forge/ nenhum nunca delega").
echo "[14b-cf] post-merge — contrafactual do [14b]: .forge/scripts/lib/ presente (só o diretório)"
echo "         → delega ao tronco de verdade, CHANGELOG.md recebe a escrita"
R14BCF="$T/r14bcf"
mkrepo "$R14BCF" "$TR14B/.forge/hooks/git"
mkdir -p "$R14BCF/.forge/scripts/lib"
printf '# Changelog\n\n## [Unreleased]\n' > "$R14BCF/CHANGELOG.md"
git -C "$R14BCF" add CHANGELOG.md >/dev/null 2>&1
git -C "$R14BCF" commit -qm "chore: changelog" >/dev/null 2>&1
git -C "$R14BCF" checkout -qb feature >/dev/null 2>&1
printf 'y\n' > "$R14BCF/b.txt"; git -C "$R14BCF" add b.txt >/dev/null 2>&1
git -C "$R14BCF" commit -qm "feat: coisa" >/dev/null 2>&1
git -C "$R14BCF" checkout -q main >/dev/null 2>&1
git -C "$R14BCF" merge -q --no-ff feature -m "merge feature" >/dev/null 2>&1
out="$(cd "$R14BCF" && bash "$TR14B/.forge/hooks/git/post-merge" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14b-cf]: post-merge falhou com .forge/scripts/lib/ presente (saída: '$out')"; exit 1; }
status="$(git -C "$R14BCF" status --porcelain)"
[ -n "$status" ] || { echo "FAIL [14b-cf]: git status ficou limpo — deveria ter recebido a escrita do tronco (.forge/ presente)"; exit 1; }
echo "OK [14b-cf]"

# ── [14c] pre-commit — mesma árvore SEM .forge/ nenhum ──────────────────────────────────────────
# Nenhum check do tronco roda (nem check-secrets.sh); o commit passa OK sem varredura nenhuma —
# mesmo invariante do [14]/[14b], agora no ponto de ENTRADA (commit) em vez do de saída (push).
echo "[14c] pre-commit — worktree SEM .forge/ nenhum → nenhum check do tronco roda, commit OK"
R14C="$T/r14c"; TR14C="$T/tr14c"
mktrunk "$TR14C"
cp "$HOOKS/pre-commit" "$TR14C/.forge/hooks/git/pre-commit"; chmod +x "$TR14C/.forge/hooks/git/pre-commit"
MARK_SEC14C="$T/marker-secrets-14c"
rm -f "$MARK_SEC14C"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 0\n' "$MARK_SEC14C" > "$TR14C/.forge/scripts/check-secrets.sh"
chmod +x "$TR14C/.forge/scripts/check-secrets.sh"
mkrepo "$R14C" "$TR14C/.forge/hooks/git"
printf 'y\n' > "$R14C/b.txt"; git -C "$R14C" add b.txt >/dev/null 2>&1
out="$(cd "$R14C" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14c]: pre-commit bloqueou numa árvore sem .forge/ nenhum (saída: '$out')"; exit 1; }
[ ! -f "$MARK_SEC14C" ] || { echo "FAIL [14c]: check-secrets.sh do tronco RODOU numa árvore sem .forge/ nenhum"; exit 1; }
[ ! -d "$R14C/.forge" ] || { echo "FAIL [14c]/setup: a worktree não deveria ter .forge/ neste cenário"; exit 1; }
echo "OK [14c]"

# [14c-cf] contrafactual do [14c]: MESMA árvore, mas com .forge/scripts/ presente (só o diretório)
# → volta a delegar ao tronco de verdade (marcador tocado) — mesmo invariante de [1a].
echo "[14c-cf] pre-commit — contrafactual do [14c]: .forge/scripts/ presente (só o diretório) →"
echo "         delega ao tronco de verdade"
R14CCF="$T/r14ccf"
mkrepo "$R14CCF" "$TR14C/.forge/hooks/git"
mkdir -p "$R14CCF/.forge/scripts"
rm -f "$MARK_SEC14C"
printf 'y\n' > "$R14CCF/b.txt"; git -C "$R14CCF" add b.txt >/dev/null 2>&1
out="$(cd "$R14CCF" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [14c-cf]: pre-commit bloqueou com .forge/scripts/ presente e alvo só no tronco (saída: '$out')"; exit 1; }
[ -f "$MARK_SEC14C" ] || { echo "FAIL [14c-cf]: check-secrets.sh do tronco não rodou — .forge/scripts/ presente deveria delegar de verdade"; exit 1; }
echo "OK [14c-cf]"

# ── [15] pre-commit — hook copiado p/ .git/hooks (sem hooksPath), .forge/ sem scripts/, alvo ────
# alheio ao harness na raiz do projeto nunca é confundido com o do tronco (achado LOW da revisão,
# regressão em relação a f24b029)
echo "[15] pre-commit — hook copiado p/ .git/hooks, .forge/ sem scripts/, scripts/check-secrets.sh"
echo "     do PROJETO (alheio ao harness) na raiz → nunca tratado como tronco"
R15="$T/r15"
mkdir -p "$R15/.git/hooks"
git -C "$R15" init -q -b main
git -C "$R15" config user.email t@t; git -C "$R15" config user.name t; git -C "$R15" config commit.gpgsign false
mkdir -p "$R15/.forge"  # .forge presente, mas SEM .forge/scripts/
cp "$HOOKS/pre-commit" "$R15/.git/hooks/pre-commit"; chmod +x "$R15/.git/hooks/pre-commit"
MARK15="$T/marker-secrets-15"; rm -f "$MARK15"
mkdir -p "$R15/scripts"
printf '#!/usr/bin/env bash\ntouch "%s"\nexit 3\n' "$MARK15" > "$R15/scripts/check-secrets.sh"
chmod +x "$R15/scripts/check-secrets.sh"
printf 'x\n' > "$R15/a.txt"; git -C "$R15" add -A >/dev/null 2>&1
git -C "$R15" commit -qm "chore: init" >/dev/null 2>&1
printf 'y\n' > "$R15/b.txt"; git -C "$R15" add b.txt >/dev/null 2>&1
out="$(cd "$R15" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [15]: pre-commit bloqueou por causa de scripts/check-secrets.sh alheio ao harness (saída: '$out')"; exit 1; }
[ ! -f "$MARK15" ] || { echo "FAIL [15]: scripts/check-secrets.sh do PROJETO rodou como se fosse .forge/scripts/ do tronco"; exit 1; }
echo "OK [15]"

# [15b] variante do [15]: scripts/ da raiz do projeto existe mas SEM check-secrets.sh dentro —
# não pode gerar a mensagem falsa ".forge/scripts/ existe mas check-secrets.sh não" (quem existe é
# scripts/ do projeto, nunca .forge/scripts/)
echo "[15b] pre-commit — variante do [15]: scripts/ do projeto sem check-secrets.sh dentro →"
echo "      sem mensagem falsa de .forge/scripts/ ausente"
R15B="$T/r15b"
mkdir -p "$R15B/.git/hooks"
git -C "$R15B" init -q -b main
git -C "$R15B" config user.email t@t; git -C "$R15B" config user.name t; git -C "$R15B" config commit.gpgsign false
mkdir -p "$R15B/.forge"
cp "$HOOKS/pre-commit" "$R15B/.git/hooks/pre-commit"; chmod +x "$R15B/.git/hooks/pre-commit"
mkdir -p "$R15B/scripts"  # scripts/ do projeto existe, mas sem check-secrets.sh
printf 'x\n' > "$R15B/a.txt"; git -C "$R15B" add -A >/dev/null 2>&1
git -C "$R15B" commit -qm "chore: init" >/dev/null 2>&1
printf 'y\n' > "$R15B/b.txt"; git -C "$R15B" add b.txt >/dev/null 2>&1
out="$(cd "$R15B" && git commit -q -m teste 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL [15b]: pre-commit bloqueou com mensagem falsa de .forge/scripts/ ausente (saída: '$out')"; exit 1; }
case "$out" in
  *".forge/scripts/ existe mas check-secrets.sh não"*) echo "FAIL [15b]: mensagem falsa apareceu — scripts/ do projeto tratado como .forge/scripts/ do tronco"; exit 1 ;;
esac
echo "OK [15b]"

echo "PASS w223-delegacao-arvore-do-hook"
