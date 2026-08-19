#!/usr/bin/env bash
# Gate W139 — segredo hardcoded em arquivo VERSIONADO é recusado (issue #37).
#
# O modo de falha que este gate ataca: credencial entra num arquivo de configuração durante o
# desenvolvimento, o build funciona, nada quebra, e ela permanece rastreada indefinidamente porque
# nenhum gate acusa. A descoberta acontece por auditoria ou por varredura externa — sempre depois
# de o valor já estar no histórico e em todos os clones.
#
# As asserções abaixo existem porque um gate de segredo é fácil de escrever verde e inútil. Cada
# classe detectada tem um cenário que INTRODUZ a violação numa fixture e observa a RECUSA; verde
# observado só no estado atual não prova que o gate avalia coisa alguma.
#   [1] credencial de conexão (Password=) em appsettings*.json versionado é recusada
#   [2] a mesma classe em *.config, *.properties, *.yml e .env — descoberta por extensão
#   [3] segredo DENTRO DE COMENTÁRIO é recusado — comentado continua versionado e legível
#   [4] sem falso positivo: placeholder de interpolação e valor vazio passam
#   [5] chave privada PEM é recusada em QUALQUER arquivo versionado, não só nos de config
#   [6] token de provedor com prefixo reconhecível é recusado; menção ao prefixo sem token, não
#   [7] Authorization: Basic <base64> literal é recusado — e o base64 é VALIDADO dos dois lados
#       antes de virar achado: sem par usuário:senha decodificável, não há credencial, e comparar
#       duas metades vazias produziria verde (ou vermelho) sobre nada
#   [8] arquivo NÃO versionado com segredo passa — o gate cobra o que está rastreado
#   [9] VACUIDADE: alvo sem nenhum arquivo versionado, path inexistente e range que não resolve
#       reprovam. "Não encontrei violação" e "não procurei" não podem colapsar no mesmo verde
#  [10] modo staged vê o índice; modo range vê o diff do range
#  [11] allowlist isenta por path COM justificativa; entrada sem justificativa reprova o gate;
#       e isentar tudo esvazia o conjunto varrido, que reprova pela regra de vacuidade
#  [12] enforce: warn rebaixa ACHADO (exit 0) e block reprova — mas vacuidade reprova em ambos
#  [13] modo report inventaria o passivo sem reprovar, e ainda assim reprova conjunto vazio
#  [14] o hook pre-commit reprova de verdade: `git commit` falha num repo real
#  [15] ESTE repositório passa no próprio gate (auto-varredura, com a allowlist que ele declara)
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$WS/template/.forge/scripts/check-secrets.sh"

T="$(mktemp -d /tmp/forge-w139.XXXXXX)"
trap 'rm -rf "$T"' EXIT

run_gate() { # run_gate <args...> — ecoa em $out, rc em $rc
  out="$(bash "$CHECK" "$@" 2>&1)"; rc=$?
}

mkfix() { # mkfix <dir> — repositório git de fixture, com o esqueleto .forge/
  mkdir -p "$1/.forge"
  # `enforce: block` EXPLÍCITO, como num projeto novo. Os cenários de detecção medem se o gate
  # ACHA o segredo; a política de quem herda o gate sem declarar nada é assunto do cenário [12],
  # e deixar os dois acoplados faria uma mudança de default virar 8 falhas sem relação com
  # detecção — foi o que aconteceu quando o default passou de block para warn.
  printf 'version: 1\nsecrets:\n  enforce: block\n' > "$1/.forge/forge.yaml"
  git -C "$1" init -q -b main
  git -C "$1" config user.email dev@test
  git -C "$1" config user.name dev
  git -C "$1" config commit.gpgsign false
}

commit_all() { # commit_all <dir>
  git -C "$1" add -A -f >/dev/null 2>&1
  git -C "$1" commit -qm "fixture" >/dev/null 2>&1
}

echo "[1] credencial de conexão em appsettings*.json versionado é recusada"
R1="$T/r1"; mkfix "$R1"
cat > "$R1/appsettings.Production.json" <<'EOF'
{
  "ConnectionStrings": {
    "Default": "Server=db.interno;Database=core;User Id=svc_app;Password=Tr0v4d0r-2024!;"
  }
}
EOF
commit_all "$R1"
run_gate path "$R1"
[ "$rc" -ne 0 ] || { echo "FAIL [1]: credencial em appsettings.Production.json passou (rc=$rc)"; echo "$out"; exit 1; }
grep -q "conn-cred" <<<"$out" || { echo "FAIL [1]: saída não identifica a classe conn-cred: $out"; exit 1; }
grep -q "appsettings.Production.json:3" <<<"$out" || { echo "FAIL [1]: saída não localiza arquivo:linha da ocorrência: $out"; exit 1; }
grep -q "Tr0v4d0r-2024" <<<"$out" && { echo "FAIL [1]: o gate ECOOU o segredo em claro — vazaria para o log de CI: $out"; exit 1; }
echo "OK [1]"

echo "[2] a mesma classe em *.config, *.properties, *.yml e .env (descoberta por extensão)"
R2="$T/r2"; mkfix "$R2"
printf '<configuration><add name="db" connectionString="Data Source=x;pwd=s3nh4-real-aqui;" /></configuration>\n' > "$R2/web.config"
printf 'spring.datasource.password=Pr0d-Secr3t-99\n' > "$R2/application.properties"
printf 'db:\n  password: umaSenhaLiteral123\n' > "$R2/values.yml"
printf 'DB_PASSWORD=outraSenhaLiteral456\n' > "$R2/.env"
commit_all "$R2"
for f in web.config application.properties values.yml .env; do
  R="$T/r2-$(printf '%s' "$f" | tr -d '.')"; mkfix "$R"
  cp "$R2/$f" "$R/$f"
  commit_all "$R"
  run_gate path "$R"
  [ "$rc" -ne 0 ] || { echo "FAIL [2]: $f passou com credencial de conexão (rc=$rc)"; echo "$out"; exit 1; }
  grep -q "$f" <<<"$out" || { echo "FAIL [2]: saída não cita $f: $out"; exit 1; }
done
echo "OK [2]"

echo "[3] segredo dentro de COMENTÁRIO é recusado"
R3="$T/r3"; mkfix "$R3"
cat > "$R3/legacy.config" <<'EOF'
<configuration>
  <!-- antigo: Server=db;User Id=sa;Password=Herdad0-2019; -->
  <add name="db" connectionString="Server=db;Integrated Security=true;" />
</configuration>
EOF
cat > "$R3/deploy.yml" <<'EOF'
db:
  # password: senhaComentadaMasVersionada
  host: db.interno
EOF
commit_all "$R3"
run_gate path "$R3"
[ "$rc" -ne 0 ] || { echo "FAIL [3]: segredo em comentário passou — comentado continua versionado e legível (rc=$rc)"; echo "$out"; exit 1; }
grep -q "legacy.config:2" <<<"$out" || { echo "FAIL [3]: comentário XML não foi varrido: $out"; exit 1; }
grep -q "deploy.yml:2" <<<"$out" || { echo "FAIL [3]: comentário YAML não foi varrido: $out"; exit 1; }
echo "OK [3]"

echo "[4] sem falso positivo: placeholder de interpolação e valor vazio passam"
R4="$T/r4"; mkfix "$R4"
cat > "$R4/appsettings.json" <<'EOF'
{
  "ConnectionStrings": {
    "Default": "Server=db;User Id=svc;Password=${DB_PASSWORD};"
  }
}
EOF
cat > "$R4/values.yaml" <<'EOF'
db:
  password: ""
  passwordFrom: "{{ .Values.secret.password }}"
  passwordEnv: "%DB_PASSWORD%"
  passwordDoc: <informe-a-senha>
EOF
printf 'spring.datasource.password=\n' > "$R4/application.properties"
commit_all "$R4"
run_gate path "$R4"
[ "$rc" -eq 0 ] || { echo "FAIL [4]: FALSO POSITIVO em placeholder/valor vazio — o gate seria desligado na primeira semana: $out"; exit 1; }
echo "OK [4]"

echo "[5] chave privada PEM é recusada em qualquer arquivo versionado"
R5="$T/r5"; mkfix "$R5"
mkdir -p "$R5/deploy"
cat > "$R5/deploy/service-account.txt" <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAxK4Uo9pQx2fT0aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789
-----END RSA PRIVATE KEY-----
EOF
# em .md: prosa também é arquivo versionado, e chave em README é chave vazada
printf 'Exemplo de chave:\n\n    -----BEGIN EC PRIVATE KEY-----\n' > "$R5/README.md"
commit_all "$R5"
run_gate path "$R5"
[ "$rc" -ne 0 ] || { echo "FAIL [5]: chave privada PEM passou (rc=$rc)"; echo "$out"; exit 1; }
grep -q "private-key" <<<"$out" || { echo "FAIL [5]: saída não identifica a classe private-key: $out"; exit 1; }
grep -q "deploy/service-account.txt:1" <<<"$out" || { echo "FAIL [5]: PEM em arquivo fora da lista de config não foi varrido: $out"; exit 1; }
grep -q "README.md:3" <<<"$out" || { echo "FAIL [5]: PEM em .md não foi varrido — prosa versionada é conteúdo versionado: $out"; exit 1; }
echo "OK [5]"

echo "[6] token de provedor com prefixo reconhecível é recusado"
# As amostras são MONTADAS em tempo de execução, nunca escritas como literal contíguo. A razão é
# concreta: o push protection do GitHub varre o conteúdo dos arquivos e barrou este próprio gate —
# "Push cannot contain secrets", apontando as linhas de Slack e Stripe. As amostras são sintéticas
# e inertes, mas têm de ser estruturalmente convincentes para exercitar o detector, e é exatamente
# isso que faz um scanner externo reagir a elas. Quebrar o literal em concatenação preserva o valor
# que chega ao arquivo de fixture (que é o que o gate lê) sem deixar o padrão contíguo no fonte
# deste teste. Ironia registrada: o único jeito de publicar o gate de segredos foi esconder do
# scanner do GitHub as fixtures que provam que ele funciona.
_p() { printf '%s' "$@"; }   # concatena sem separador ("$@" com um só %s reusa o formato)
tok_gh="$(_p 'ghp' '_' 'A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8')"
tok_aws="$(_p 'AKIA' 'IOSFODNN7' 'EXAMPLE')"
tok_gcp="$(_p 'AIza' 'SyD-9tSrke72PouQMnMX-a7eZSW0jkFMBWY')"
tok_slack="$(_p 'xox' 'b-2451234567-2456789012-AbCdEfGhIjKlMnOpQrStUvWx')"
tok_stripe="$(_p 'sk' '_live_' '51H8xYzAbCdEfGhIjKlMnOpQr')"
tok_npm="$(_p 'npm' '_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789')"
tok_llm="$(_p 'sk-' 'ant-api03-' 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789')"
# Um único repositório com um arquivo por amostra: `git init` domina o custo deste gate, e sete
# fixtures separadas custariam sete vezes o mesmo para provar exatamente a mesma coisa.
R6="$T/r6"; mkfix "$R6"
i=0
for tok in "$tok_gh" "$tok_aws" "$tok_gcp" "$tok_slack" "$tok_stripe" "$tok_npm" "$tok_llm"; do
  i=$((i + 1))
  printf 'const client = build({ token: "%s" });\n' "$tok" > "$R6/client$i.ts"
done
commit_all "$R6"
run_gate path "$R6"
[ "$rc" -ne 0 ] || { echo "FAIL [6]: token de provedor passou (rc=$rc)"; echo "$out"; exit 1; }
grep -q "provider-token — 7 ocorrência" <<<"$out" || { echo "FAIL [6]: nem toda amostra de token foi detectada — esperadas 7: $out"; exit 1; }
i=0
for tok in "$tok_gh" "$tok_aws" "$tok_gcp" "$tok_slack" "$tok_stripe" "$tok_npm" "$tok_llm"; do
  i=$((i + 1))
  grep -q "client$i.ts:1" <<<"$out" || { echo "FAIL [6]: amostra $i não foi localizada por arquivo:linha: $out"; exit 1; }
  grep -qF "$tok" <<<"$out" && { echo "FAIL [6]: o gate ECOOU o token em claro (amostra $i): $out"; exit 1; }
done
# sem falso positivo: documentar o PREFIXO não é vazar o token
R6b="$T/r6b"; mkfix "$R6b"
cat > "$R6b/SECURITY.md" <<'EOF'
Tokens do GitHub começam com ghp_ ou gho_; os da AWS, com AKIA.
Nunca versione um valor completo — use o cofre.
EOF
commit_all "$R6b"
run_gate path "$R6b"
[ "$rc" -eq 0 ] || { echo "FAIL [6]: FALSO POSITIVO — documentar o prefixo não é vazar o token: $out"; exit 1; }
echo "OK [6]"

echo "[7] Authorization: Basic <base64> literal é recusado, com validação dos dois lados"
R7="$T/r7"; mkfix "$R7"
printf 'curl -H "Authorization: Basic YWRtaW46czNuaDQtcHIwZA==" https://api.interno/v1/health\n' > "$R7/smoke.sh"
commit_all "$R7"
run_gate path "$R7"
[ "$rc" -ne 0 ] || { echo "FAIL [7]: Authorization: Basic literal passou (rc=$rc)"; echo "$out"; exit 1; }
grep -q "basic-auth" <<<"$out" || { echo "FAIL [7]: saída não identifica a classe basic-auth: $out"; exit 1; }
grep -q "YWRtaW46czNuaDQ" <<<"$out" && { echo "FAIL [7]: o gate ECOOU o base64 — decodificável é o mesmo que ecoar a senha: $out"; exit 1; }

# SEM COMPARAÇÃO VAZIA: só é credencial o base64 que decodifica num par usuário:senha com AMBOS os
# lados preenchidos. "administradorSemPar" (sem `:`), ":senhaLonga123456" (usuário vazio) e
# "usuarioLongo0123:" (senha vazia) não são credencial — e um detector que fatiasse em `:` sem
# validar as metades compararia vazio com vazio e concluiria ter achado par onde não há nada.
# As amostras são LONGAS de propósito: com base64 curto o regex nem chega a casar, e o cenário
# passaria sem nunca exercitar a validação — foi o que a prova de mutação revelou.
R7b="$T/r7b"; mkfix "$R7b"
for b64 in "YWRtaW5pc3RyYWRvclNlbVBhcg==" "OnNlbmhhTG9uZ2ExMjM0NTY=" "dXN1YXJpb0xvbmdvMDEyMzo="; do
  printf 'Authorization: Basic %s\n' "$b64" >> "$R7b/notas.txt"
done
commit_all "$R7b"
run_gate path "$R7b"
[ "$rc" -eq 0 ] || { echo "FAIL [7]: base64 sem par usuário:senha completo virou achado — comparação sem validar os dois lados: $out"; exit 1; }

# e o placeholder de template continua passando
R7c="$T/r7c"; mkfix "$R7c"
printf 'Authorization: Basic <token>\nAuthorization: Basic {{ .Values.auth }}\n' > "$R7c/exemplo.md"
commit_all "$R7c"
run_gate path "$R7c"
[ "$rc" -eq 0 ] || { echo "FAIL [7]: FALSO POSITIVO em placeholder de Authorization: $out"; exit 1; }
echo "OK [7]"

echo "[8] arquivo não versionado com segredo passa — o gate cobra o rastreado"
R8="$T/r8"; mkfix "$R8"
printf 'db:\n  host: db.interno\n' > "$R8/values.yaml"
printf '.env.local\n' > "$R8/.gitignore"
commit_all "$R8"
printf 'DB_PASSWORD=SegredoLocalNaoVersionado1\n' > "$R8/.env.local"
printf 'password=SegredoNemAdicionado2\n' > "$R8/solto.properties"
run_gate path "$R8"
[ "$rc" -eq 0 ] || { echo "FAIL [8]: arquivo não rastreado virou achado — o gate cobra o conjunto versionado: $out"; exit 1; }
echo "OK [8]"

echo "[9] VACUIDADE: conjunto vazio, path inexistente e range que não resolve reprovam"
R9="$T/r9"; mkfix "$R9"
printf 'nada\n' > "$R9/a.txt"
mkdir -p "$R9/vazio"
printf 'ignorado\n' > "$R9/vazio/nao-rastreado.txt"
printf 'vazio/\n' > "$R9/.gitignore"
git -C "$R9" add a.txt .gitignore >/dev/null 2>&1
git -C "$R9" commit -qm fixture >/dev/null 2>&1
run_gate path "$R9/vazio"
[ "$rc" -ne 0 ] || { echo "FAIL [9]: diretório sem NENHUM arquivo versionado devolveu OK — verde por vacuidade: $out"; exit 1; }
grep -q "scan-set" <<<"$out" || { echo "FAIL [9]: a saída não distingue 'não procurei' de 'não encontrei': $out"; exit 1; }
run_gate path "$R9/nao-existe-mesmo"
[ "$rc" -ne 0 ] || { echo "FAIL [9]: path inexistente devolveu OK: $out"; exit 1; }
run_gate range "nao-existe-1..nao-existe-2"
[ "$rc" -ne 0 ] || { echo "FAIL [9]: rev-range que não resolve devolveu OK: $out"; exit 1; }
echo "OK [9]"

echo "[10] modo staged vê o índice; modo range vê o diff do range"
R10="$T/r10"; mkfix "$R10"
printf 'db:\n  host: db.interno\n' > "$R10/values.yaml"
commit_all "$R10"
base="$(git -C "$R10" rev-parse HEAD)"
printf 'db:\n  password: SegredoQueEntraAgora9\n' > "$R10/values.yaml"
git -C "$R10" add values.yaml >/dev/null 2>&1
out="$(cd "$R10" && bash "$CHECK" staged 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [10]: modo staged não viu o segredo prestes a entrar no commit: $out"; exit 1; }
git -C "$R10" commit -qm "entra segredo" >/dev/null 2>&1
head="$(git -C "$R10" rev-parse HEAD)"
out="$(cd "$R10" && bash "$CHECK" range "$base..$head" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL [10]: modo range não viu o segredo introduzido no range: $out"; exit 1; }
echo "OK [10]"

echo "[11] allowlist: isenta com justificativa, reprova sem ela, e não pode esvaziar o conjunto"
R11="$T/r11"; mkfix "$R11"
printf 'db:\n  host: ok\n' > "$R11/values.yaml"
mkdir -p "$R11/tests/fixtures"
printf 'password=SenhaSinteticaDeFixture1\n' > "$R11/tests/fixtures/sample.properties"
commit_all "$R11"
run_gate path "$R11"
[ "$rc" -ne 0 ] || { echo "FAIL [11]: controle — a fixture deveria acionar o gate antes da allowlist: $out"; exit 1; }
printf 'tests/fixtures/*.properties  # motivo: amostra sintetica do suite de testes, sem valor real\n' > "$R11/.forge/secrets-allowlist.txt"
run_gate path "$R11"
[ "$rc" -eq 0 ] || { echo "FAIL [11]: allowlist com justificativa não isentou o path: $out"; exit 1; }
grep -q "1 arquivo(s) isento" <<<"$out" || { echo "FAIL [11]: a isenção não é reportada — allowlist tem de ser visível: $out"; exit 1; }
printf 'tests/fixtures/*.properties\n' > "$R11/.forge/secrets-allowlist.txt"
run_gate path "$R11"
[ "$rc" -ne 0 ] || { echo "FAIL [11]: entrada de allowlist SEM justificativa virou passe livre: $out"; exit 1; }
grep -q "secrets/allowlist" <<<"$out" || { echo "FAIL [11]: o gate não aponta a allowlist como a causa: $out"; exit 1; }
printf 'tests/fixtures/*.properties  # motivo: curto\n' > "$R11/.forge/secrets-allowlist.txt"
run_gate path "$R11"
[ "$rc" -ne 0 ] || { echo "FAIL [11]: justificativa de fachada foi aceita: $out"; exit 1; }
printf '**  # motivo: tentativa de isentar o repositorio inteiro de uma vez\n' > "$R11/.forge/secrets-allowlist.txt"
run_gate path "$R11"
[ "$rc" -ne 0 ] || { echo "FAIL [11]: allowlist total virou verde — dá para isentar o repo inteiro e passar: $out"; exit 1; }
grep -q "scan-set" <<<"$out" || { echo "FAIL [11]: isentar tudo deveria reprovar por conjunto varrido vazio: $out"; exit 1; }
echo "OK [11]"

echo "[12] enforce: warn rebaixa achado; block reprova; vacuidade reprova em ambos"
R12="$T/r12"; mkfix "$R12"
printf 'db:\n  password: SenhaLiteralDoPassivo7\n' > "$R12/values.yaml"
commit_all "$R12"
printf 'version: 1\nsecrets:\n  enforce: warn\n' > "$R12/.forge/forge.yaml"
run_gate path "$R12"
[ "$rc" -eq 0 ] || { echo "FAIL [12]: enforce warn bloqueou — brownfield não conseguiria adotar incrementalmente: $out"; exit 1; }
grep -q "WARN secrets/conn-cred" <<<"$out" || { echo "FAIL [12]: warn não reportou o achado: $out"; exit 1; }
printf 'version: 1\nsecrets:\n  enforce: block\n' > "$R12/.forge/forge.yaml"
run_gate path "$R12"
[ "$rc" -ne 0 ] || { echo "FAIL [12]: enforce block não reprovou: $out"; exit 1; }
printf 'version: 1\nsecrets:\n  enforce: warn\n' > "$R12/.forge/forge.yaml"
run_gate path "$R12/nao-existe"
[ "$rc" -ne 0 ] || { echo "FAIL [12]: vacuidade foi rebaixada por enforce warn — falha de integridade não é achado: $out"; exit 1; }
# Ausência do bloco `secrets:` resolve para warn — o caminho que TODO repositório existente
# percorre ao atualizar o harness, já que o gate não é opt-in (está fiado no pre-commit e no CI).
# Um default `block` bloquearia, no dia da atualização, todo commit que encostasse num arquivo com
# passivo antigo, sem aviso e sem janela para medir. Gate que trava o time no primeiro dia vira
# `--no-verify` de hábito.
printf 'version: 1\n' > "$R12/.forge/forge.yaml"
run_gate path "$R12"
[ "$rc" -eq 0 ] || { echo "FAIL [12]: sem bloco secrets: o gate bloqueou — um brownfield herdaria trava no dia da atualização: $out"; exit 1; }
grep -q "WARN secrets" <<<"$out" || { echo "FAIL [12]: sem bloco secrets: o achado sumiu em vez de virar aviso — pior que bloquear: $out"; exit 1; }
# E o default brando NÃO rebaixa falha de integridade.
run_gate path "$R12/nao-existe"
[ "$rc" -ne 0 ] || { echo "FAIL [12]: sem bloco secrets: vacuidade passou — gate que não rodou não pode se reportar verde: $out"; exit 1; }
printf 'version: 1\nsecrets:\n  enforce: warn\n' > "$R12/.forge/forge.yaml"
echo "OK [12]"

echo "[13] modo report inventaria sem reprovar, mas ainda reprova conjunto vazio"
run_gate report "$R12"
[ "$rc" -eq 0 ] || { echo "FAIL [13]: report reprovou — o inventário existe justamente para medir antes de decidir a política: $out"; exit 1; }
grep -q "REPORT secrets" <<<"$out" || { echo "FAIL [13]: report não emitiu o inventário: $out"; exit 1; }
grep -q "values.yaml:2" <<<"$out" || { echo "FAIL [13]: report não lista a ocorrência: $out"; exit 1; }
run_gate report "$R9/vazio"
[ "$rc" -ne 0 ] || { echo "FAIL [13]: report devolveu 0 sobre conjunto vazio — inventário de nada viraria 'limpo': $out"; exit 1; }
echo "OK [13]"

echo "[14] o hook pre-commit reprova de verdade (git commit falha)"
R14="$T/r14"; mkfix "$R14"
mkdir -p "$R14/.forge/worktrees"
cp -R "$WS/template/.forge/scripts" "$R14/.forge/"
cp -R "$WS/template/.forge/hooks" "$R14/.forge/"
git -C "$R14" config core.hooksPath .forge/hooks/git
printf 'db:\n  host: ok\n' > "$R14/values.yaml"
git -C "$R14" add -A >/dev/null 2>&1
git -C "$R14" commit -qm "base" >/dev/null 2>&1 || { echo "FAIL [14]: commit limpo foi bloqueado na preparação"; exit 1; }
printf 'db:\n  password: SenhaQueOHookTemDePegar3\n' > "$R14/values.yaml"
git -C "$R14" add values.yaml >/dev/null 2>&1
cout="$(git -C "$R14" commit -m "introduz segredo" 2>&1)"; crc=$?
[ "$crc" -ne 0 ] || { echo "FAIL [14]: git commit passou com segredo em arquivo versionado: $cout"; exit 1; }
grep -qi "secret" <<<"$cout" || { echo "FAIL [14]: o hook bloqueou sem explicar que a causa é segredo: $cout"; exit 1; }
git -C "$R14" checkout -- values.yaml 2>/dev/null || printf 'db:\n  host: ok\n' > "$R14/values.yaml"
printf 'db:\n  host: outro\n' > "$R14/values.yaml"
git -C "$R14" add values.yaml >/dev/null 2>&1
git -C "$R14" commit -qm "mudanca limpa" >/dev/null 2>&1 || { echo "FAIL [14]: commit limpo foi bloqueado pelo gate de segredos"; exit 1; }
echo "OK [14]"

echo "[15] este repositório passa no próprio gate"
run_gate path "$WS"
[ "$rc" -eq 0 ] || { echo "FAIL [15]: o harness não passa no próprio gate — auto-envenenamento pelas fixtures do teste: $out"; exit 1; }
grep -q "OK secrets/scan-set" <<<"$out" || { echo "FAIL [15]: o gate não varreu o repositório: $out"; exit 1; }
# rc=0 NÃO basta: este repositório não declara `secrets:` no .forge/forge.yaml, então herda o
# default `warn` — e em warn um achado real sairia com rc=0 e o cenário passaria por cima dele.
# A asserção que vale é ZERO achado, que independe do modo.
grep -q "^OK secrets —" <<<"$out" \
  || { echo "FAIL [15]: o gate achou segredo no próprio repositório (rebaixado a aviso pelo default warn, mas achado é achado): $out"; exit 1; }
grep -q "WARN secrets" <<<"$out" \
  && { echo "FAIL [15]: achado rebaixado a WARN no próprio repositório: $out"; exit 1; }
echo "OK [15]"

echo "PASS w139-secrets-gate"
