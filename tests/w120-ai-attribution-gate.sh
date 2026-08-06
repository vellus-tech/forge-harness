#!/usr/bin/env bash
# Gate W120 — proibição de assinatura de IA em commits, PRs e issues:
#   [1] trailer Claude-Session: (o caso real observado em azim-crm) é recusado
#   [2] Co-Authored-By com identidade de IA é recusado, em qualquer capitalização
#   [3] marcador de geração ("🤖 Generated with [Claude Code]") é recusado em qualquer linha
#   [4] outros agentes (Codex, Copilot, Cursor, Gemini) são recusados — a regra não é sobre um vendor
#   [5] SEM FALSO POSITIVO: prosa que menciona claude/anthropic/codex passa. Esta é a asserção que
#       torna o gate utilizável — este repositório documenta adapters de Claude e Codex em quase
#       todo commit, e um detector textual solto o tornaria impossível de usar
#   [6] o hook commit-msg reprova de verdade: `git commit` falha num repo real
#   [7] pre-push varre o RANGE e pega commit criado com --no-verify (defesa em profundidade)
#   [8] corpo de PR/issue com marca é recusado pelo modo `text`
#   [9] mensagem limpa passa, e um trailer legítimo (Refs:, Signed-off-by humano) não é tocado
#   [10] a mensagem de FAIL cita o path da rule canônica
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$WS/template/.forge/scripts"
CHECK="$S/check-ai-attribution.sh"
RULE="rules/conventions/no-ai-attribution.md"
T="$(mktemp -d /tmp/forge-w120.XXXXXX)"
trap 'rm -rf "$T"' EXIT

# roda o check em modo msg-file sobre um heredoc; ecoa rc e saída
run_msg() { # run_msg <arquivo>
  set +e
  out="$(bash "$CHECK" msg-file "$1" 2>&1)"; rc=$?
  set -e
}

echo "[1] trailer Claude-Session: recusado"
cat > "$T/m1.txt" <<'EOF'
feat(grpc): onda 3 W3 — pipeline lendo sinais por gRPC

Implementa o adapter e a flag de transporte.

Claude-Session: https://claude.ai/code/session_01NxvAk3YyBkk18NFESE2tPV
EOF
run_msg "$T/m1.txt"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: trailer Claude-Session passou"; exit 1; }
grep -qi "claude-session" <<<"$out" || { echo "FAIL [1]: saída não cita o trailer ofensor: $out"; exit 1; }
# [1b] o mesmo trailer SEM URL. Isola a regra de CHAVE: com a URL presente, a regra de valor já
# reprovaria sozinha e a de chave nunca seria exercitada — foi o que a prova de mutação revelou.
cat > "$T/m1b.txt" <<'EOF'
fix(x): corrigir algo

corpo do commit.

Claude-Session: session_01ABCDEF
EOF
run_msg "$T/m1b.txt"
[ "$rc" -ne 0 ] || { echo "FAIL [1b]: trailer de sessão sem URL passou — a regra de chave não está sendo aplicada"; exit 1; }
echo "OK [1]"

echo "[2] Co-Authored-By com identidade de IA recusado (qualquer capitalização)"
for v in "Co-Authored-By: Claude <noreply@anthropic.com>" \
         "Co-authored-by: Claude <noreply@anthropic.com>" \
         "co-authored-by: Codex <codex@openai.com>"; do
  printf 'fix(x): corrigir algo\n\ncorpo.\n\n%s\n' "$v" > "$T/m2.txt"
  run_msg "$T/m2.txt"
  [ "$rc" -ne 0 ] || { echo "FAIL [2]: passou -> $v"; exit 1; }
done
echo "OK [2]"

echo "[3] marcador de geração recusado em qualquer linha"
cat > "$T/m3.txt" <<'EOF'
chore(deps): atualizar pacote

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
run_msg "$T/m3.txt"
[ "$rc" -ne 0 ] || { echo "FAIL [3]: marcador de geração passou"; exit 1; }
echo "OK [3]"

echo "[4] outros agentes recusados (a regra não é sobre um vendor)"
for v in "Copilot-Session: https://github.com/copilot/session/abc" \
         "Generated-By: Cursor" \
         "Co-authored-by: Gemini Code Assist <noreply@google.com>"; do
  printf 'refactor(y): simplificar\n\ncorpo.\n\n%s\n' "$v" > "$T/m4.txt"
  run_msg "$T/m4.txt"
  [ "$rc" -ne 0 ] || { echo "FAIL [4]: passou -> $v"; exit 1; }
done
echo "OK [4]"

echo "[5] sem falso positivo: prosa mencionando claude/anthropic/codex passa"
cat > "$T/m5.txt" <<'EOF'
feat(adapters): materializar o adapter claude a partir de .forge

O adapter Claude Code e o adapter Codex passam a compartilhar a fonte canônica
em .forge/, e a documentação em https://claude.ai/code é citada no README como
referência da ferramenta. Nada aqui assina o commit em nome de uma IA.

Refs: LDG-0006
EOF
run_msg "$T/m5.txt"
[ "$rc" -eq 0 ] || { echo "FAIL [5]: FALSO POSITIVO em prosa sobre Claude/Codex — o gate seria inutilizável neste repo: $out"; exit 1; }
echo "OK [5]"

echo "[6] hook commit-msg reprova de verdade (git commit falha)"
R="$T/repo"
mkdir -p "$R/.forge"
cp -R "$WS/template/.forge/scripts" "$R/.forge/"
cp -R "$WS/template/.forge/hooks" "$R/.forge/"
cp -R "$WS/template/.forge/rules" "$R/.forge/"
git -C "$R" init -q
git -C "$R" config user.email dev@test
git -C "$R" config user.name dev
git -C "$R" config commit.gpgsign false
git -C "$R" config core.hooksPath .forge/hooks/git
echo "conteudo" > "$R/a.txt"
git -C "$R" add a.txt
set +e
cout="$(git -C "$R" commit -m "feat(a): adicionar arquivo

Claude-Session: https://claude.ai/code/session_01ABC" 2>&1)"; crc=$?
set -e
[ "$crc" -ne 0 ] || { echo "FAIL [6]: git commit passou com trailer de IA: $cout"; exit 1; }
grep -qi "ai-attribution\|assinatura de IA\|no-ai-attribution" <<<"$cout" || { echo "FAIL [6]: hook bloqueou sem explicar: $cout"; exit 1; }
# e o commit limpo passa pelo mesmo hook
git -C "$R" commit -qm "feat(a): adicionar arquivo" || { echo "FAIL [6]: commit limpo foi bloqueado"; exit 1; }
echo "OK [6]"

echo "[7] pre-push varre o range e pega commit criado com --no-verify"
echo "mais" > "$R/b.txt"
git -C "$R" add b.txt
git -C "$R" commit -q --no-verify -m "fix(b): burlar o hook

Claude-Session: https://claude.ai/code/session_01BURLADO"
base_sha="$(git -C "$R" rev-parse HEAD~1)"
head_sha="$(git -C "$R" rev-parse HEAD)"
set +e
rout="$(cd "$R" && bash .forge/scripts/check-ai-attribution.sh range "$base_sha..$head_sha" 2>&1)"; rrc=$?
set -e
[ "$rrc" -ne 0 ] || { echo "FAIL [7]: range não pegou o commit com --no-verify: $rout"; exit 1; }
grep -q "${head_sha:0:7}" <<<"$rout" || { echo "FAIL [7]: saída não identifica o commit ofensor: $rout"; exit 1; }
echo "OK [7]"

echo "[8] corpo de PR/issue recusado pelo modo text"
cat > "$T/pr.md" <<'EOF'
## Resumo

Migra o pipeline para gRPC.

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
set +e
tout="$(bash "$CHECK" text "$T/pr.md" 2>&1)"; trc=$?
set -e
[ "$trc" -ne 0 ] || { echo "FAIL [8]: corpo de PR com marca passou"; exit 1; }
echo "OK [8]"

echo "[9] mensagem limpa passa; trailer legítimo não é tocado"
cat > "$T/m9.txt" <<'EOF'
fix(liaison): recusar reescrita de história no import

Uma posição seq já conhecida não pode chegar com outro content_sha.

Refs: LDG-0006
Signed-off-by: Milton Antonio da Silva Jr <milton@axis-mobfintech.com>
EOF
run_msg "$T/m9.txt"
[ "$rc" -eq 0 ] || { echo "FAIL [9]: mensagem limpa foi reprovada: $out"; exit 1; }
echo "OK [9]"

echo "[10] a mensagem de FAIL cita a rule canônica"
run_msg "$T/m1.txt"
grep -q "$RULE" <<<"$out" || { echo "FAIL [10]: FAIL não cita $RULE: $out"; exit 1; }
[ -f "$WS/template/.forge/$RULE" ] || { echo "FAIL [10]: rule canônica não existe em template/.forge/$RULE"; exit 1; }
echo "OK [10]"

echo "PASS w120-ai-attribution-gate"
