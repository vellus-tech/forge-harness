#!/usr/bin/env bash
# Gate W251 — universo de varredura do doctor por INCLUSÃO da fonte canônica (issue #127).
#
# Dois defeitos no mesmo par de checagens de `doctor.sh` (harness: refs .claude/ / placeholders
# <PROJECT_*>): CUSTO (o `grep -rl` varria "$ROOT/.forge" inteiro antes de filtrar a saída — numa
# árvore com worktrees, cada worktree é uma cópia completa do repositório, então o custo era pago
# mesmo quando o resultado saía certo) e PREDICADO (o filtro de saída não excluía `.forge/liaison/`
# nem `.forge/ledger/`, onde agentes CONVERSAM SOBRE o diretório `.claude/` em mensagens/ledger —
# texto, não configuração — então o gate ficava cronicamente vermelho pelo motivo errado).
#
# Desenho: universo por INCLUSÃO explícita da fonte canônica (rules/, agents/, skills/,
# commands/, templates/ + arquivos de topo de .forge/), em vez de "tudo sob .forge/ menos
# exceções". worktrees/, liaison/, ledger/, specs/, product/, evals/, custom/, cache/ nunca fazem
# parte da lista de entrada — o `grep` não desce lá porque o caminho nunca chega a ser candidato,
# não porque um filtro de saída o descartou depois. Isso resolve custo e predicado ao mesmo tempo.
#
#   [1] baseline: projeto limpo passa "sem refs .claude/" com contador de examinados > 0 (prova
#       positiva de que o mecanismo rodou, não de que não olhou para nada)
#   [2] positiva: menção a .claude/ plantada SÓ em liaison/, ledger/ e worktrees/ (dado, não
#       configuração) continua "sem refs .claude/", com o MESMO contador do baseline (prova de que
#       esses arquivos nunca entraram no universo, não só que foram filtrados na saída)
#   [3] contrafactual: a MESMA menção plantada em rules/ (fonte canônica) reprova, nomeando
#       exatamente 1 arquivo
#   [4] shim de `grep` em PATH: registra o argv de toda invocação: nenhuma chamada que carrega o
#       padrão '.claude/' recebe um caminho contendo "/worktrees/" — prova de não-descida
#       independente da leitura do resultado
#   [5] mini-PBT (enumeração exaustiva do espaço categórico de diretórios, canônico vs dado): para
#       cada diretório canônico testado a contagem reportada é 1; para cada diretório de dado
#       testado a contagem é 0 — a contagem reportada é sempre igual ao número de arquivos com
#       menção DENTRO do universo de inclusão, nunca ao total plantado
#   [6] mutação: substituir o universo de inclusão por "$ROOT/.forge" inteiro (a forma antiga) faz
#       o cenário [2] (menção só em liaison/) voltar a reprovar — prova de que o gate depende do
#       desenho real, não de uma coincidência de fixture
#
# Revalida also w158 (não repetido aqui — roda separado).
set -uo pipefail
# Isolamento git (LDG-0201): variáveis herdadas de sessão paralela mal isolada não devem
# direcionar `git init`/`git config` deste gate para o repositório real.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_CONFIG

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d /tmp/forge-w251.XXXXXX)"
trap 'rm -rf "$T"' EXIT

DOCTOR_SRC="$WS/template/.forge/scripts/doctor.sh"
[ -f "$DOCTOR_SRC" ] || { echo "FAIL [setup]: $DOCTOR_SRC ausente"; exit 1; }

echo "[0] instala projeto real via forge.mjs init"
node "$WS/bin/forge.mjs" init --target "$T" --slug demo --name Demo --desc t --yes --no-plugin \
  >"$T.init.log" 2>&1 || { echo "FAIL [0]: init falhou"; cat "$T.init.log"; exit 1; }
[ -f "$T/.forge/scripts/doctor.sh" ] || { echo "FAIL [0]: .forge/scripts/doctor.sh ausente pós-init"; exit 1; }
echo "OK [0]"

run_doctor() { # run_doctor <root> [doctor_bin]
  local root="$1" bin="${2:-$DOCTOR_SRC}"
  FORGE_ROOT="$root" bash "$bin" --report 2>&1
}

leak_line() { grep -E 'refs \.claude/' <<<"$1"; }

extract_n() { # extrai o "N arquivo(s) examinado(s))" da linha
  sed -n 's/.*(\([0-9]\{1,\}\) arquivo(s) examinado(s)).*/\1/p' <<<"$1"
}

echo "[1] baseline: projeto limpo passa 'sem refs .claude/' com contador > 0"
out0="$(run_doctor "$T")"
line0="$(leak_line "$out0")"
grep -q "sem refs .claude/" <<<"$line0" || { echo "FAIL [1]: baseline já reprova: $line0"; exit 1; }
n0="$(extract_n "$line0")"
[ -n "$n0" ] && [ "$n0" -gt 0 ] || { echo "FAIL [1]: contador de examinados ausente ou zero: $line0"; exit 1; }
echo "OK [1] — $n0 arquivo(s) examinado(s)"

echo "[2] positiva: menção .claude/ só em liaison/, ledger/ e worktrees/ não reprova, contador igual ao baseline"
mkdir -p "$T/.forge/liaison/canal-a/log" "$T/.forge/worktrees/wt1/scripts"
cat > "$T/.forge/liaison/canal-a/log/agente-x.jsonl" <<'EOF'
{"kind":"msg","body":"lembrar de conferir .claude/settings.json antes do merge"}
EOF
{
  echo ""
  echo "## Nota"
  echo "Mensagem do canal citou \`.claude/\` como diretório gerado, não config."
} >> "$T/.forge/ledger/LEDGER.md"
cat > "$T/.forge/worktrees/wt1/scripts/deploy.sh" <<'EOF'
#!/usr/bin/env bash
# cópia de worktree; referencia .claude/ só como exemplo de path
echo ".claude/settings.local.json"
EOF
out2="$(run_doctor "$T")"
line2="$(leak_line "$out2")"
grep -q "sem refs .claude/" <<<"$line2" || { echo "FAIL [2]: dado (liaison/ledger/worktrees) contou como leak: $line2"; exit 1; }
n2="$(extract_n "$line2")"
[ "$n2" = "$n0" ] || { echo "FAIL [2]: contador mudou ($n0 -> $n2) — os arquivos de dado entraram no universo"; exit 1; }
echo "OK [2] — contador inalterado ($n2)"

echo "[3] contrafactual: a MESMA menção em rules/ (fonte canônica) reprova, nomeando 1 arquivo"
mkdir -p "$T/.forge/rules/conventions"
cat > "$T/.forge/rules/conventions/leak-real.md" <<'EOF'
# Convenção

Nunca edite `.claude/settings.json` à mão — é gerado.
EOF
out3="$(run_doctor "$T")"
line3="$(leak_line "$out3")"
grep -q "1 arquivo(s) da fonte can" <<<"$line3" || { echo "FAIL [3]: leak real em rules/ não reprovou (ou contou errado): $line3"; exit 1; }
n3="$(extract_n "$line3")"
[ "$n3" = "$((n0 + 1))" ] || { echo "FAIL [3]: contador de examinados deveria crescer em 1 ($n0 -> esperado $((n0+1)), veio $n3): $line3"; exit 1; }
echo "OK [3]"
rm -f "$T/.forge/rules/conventions/leak-real.md"

echo "[4] shim de grep em PATH: nenhuma chamada com o padrão .claude/ recebe caminho /worktrees/"
SHIMDIR="$T/shim"; mkdir -p "$SHIMDIR"
REALGREP="$(command -v grep)"
cat > "$SHIMDIR/grep" <<SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/grep-argv.log"
exec "$REALGREP" "\$@"
SHIM
chmod +x "$SHIMDIR/grep"
: > "$T/grep-argv.log"
PATH="$SHIMDIR:$PATH" FORGE_ROOT="$T" bash "$DOCTOR_SRC" --report >/dev/null 2>&1
[ -s "$T/grep-argv.log" ] || { echo "FAIL [4]: shim não registrou nenhuma chamada — grep não veio do PATH?"; exit 1; }
leak_calls="$(grep -F '.claude/' "$T/grep-argv.log" || true)"
[ -n "$leak_calls" ] || { echo "FAIL [4]: nenhuma chamada de grep usou o padrão .claude/ — checagem não rodou"; exit 1; }
if grep -q '/worktrees/' <<<"$leak_calls"; then
  echo "FAIL [4]: uma chamada de grep com o padrão .claude/ recebeu caminho sob /worktrees/:"; echo "$leak_calls"; exit 1
fi
echo "OK [4] — $(wc -l <<<"$leak_calls" | tr -d ' ') chamada(s) com o padrão .claude/, nenhuma sob /worktrees/"

echo "[5] mini-PBT: enumeração canônico vs dado — contagem sempre igual ao universo de inclusão"
canon_dirs="rules agents skills commands templates"
data_dirs="liaison ledger worktrees specs product evals custom"
fail5=0
for d in $canon_dirs; do
  sub="$T/.forge/$d/w251-pbt"
  mkdir -p "$sub"
  printf 'menciona .claude/ aqui\n' > "$sub/x.md"
  out="$(run_doctor "$T")"
  line="$(leak_line "$out")"
  rm -rf "$sub"
  if ! grep -q "1 arquivo(s) da fonte can" <<<"$line"; then
    echo "FAIL [5]: diretório canônico '$d' deveria reprovar nomeando 1: $line"; fail5=1
  fi
done
for d in $data_dirs; do
  sub="$T/.forge/$d/w251-pbt"
  mkdir -p "$sub"
  printf 'menciona .claude/ aqui\n' > "$sub/x.md"
  out="$(run_doctor "$T")"
  line="$(leak_line "$out")"
  rm -rf "$sub"
  if ! grep -q "sem refs .claude/" <<<"$line"; then
    echo "FAIL [5]: diretório de dado '$d' não deveria reprovar: $line"; fail5=1
  fi
done
[ "$fail5" -eq 0 ] || exit 1
echo "OK [5] — $(wc -w <<<"$canon_dirs") diretório(s) canônico(s) reprovam isolados, $(wc -w <<<"$data_dirs") de dado não reprovam"

echo "[6] mutação: universo = \$ROOT/.forge inteiro (forma antiga) faz o cenário [2] voltar a reprovar"
MUT="$T/doctor-mutado.sh"
awk '
  /^  canon_scan_scope\(\) \{$/ { print; print "    find \"$ROOT/.forge\" -type f -print0 2>/dev/null; return  # MUTAÇÃO w251"; next }
  { print }
' "$DOCTOR_SRC" > "$MUT"
grep -q "MUTAÇÃO w251" "$MUT" || { echo "FAIL [6-setup]: mutação não aplicou (canon_scan_scope não encontrado — doctor.sh mudou de forma?)"; exit 1; }
outm="$(run_doctor "$T" "$MUT")"
linem="$(leak_line "$outm")"
if grep -q "sem refs .claude/" <<<"$linem"; then
  echo "FAIL [6]: mutação deveria reintroduzir o falso-negativo/positivo e reprovar o cenário [2] — continuou 'sem refs': $linem"; exit 1
fi
grep -qE '[1-9][0-9]* arquivo\(s\) da fonte can' <<<"$linem" || { echo "FAIL [6]: mutação não reprovou como esperado: $linem"; exit 1; }
echo "OK [6] — mutação reprova ($linem)"

echo "PASS w251-doctor-scan-universe-gate"
