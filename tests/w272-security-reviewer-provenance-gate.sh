#!/usr/bin/env bash
# Gate w272 — security-reviewer com passo de proveniência (#152).
#
# ESTÁTICO, mas ESTRUTURAL: as checagens leem a SEÇÃO certa do agente, nunca o arquivo inteiro. Uma frase-chave solta em outro lugar do arquivo (tabela, checklist, exemplo) não satisfaz o critério que tem de estar no corpo do §12.
#
#   [1] o §12 ("### 12. Proveniência") existe e o corpo da seção não está vazio;
#   [2] o corpo do §12 contém a pergunta "quem escreveu esse campo", o critério BLOCKER ligado à falta de ancoragem server-side e o bullet incondicional "**Percorra também os registros filhos**", sem condicional (opcional, quando houver tempo etc.);
#   [3] a regra de ancoragem, no corpo do §12, EXIGE comparar o dono gravado no registro com o principal do token (sub/userId) e também o tenant, antes do efeito; declara que comparar só o tenant num recurso com dono de usuário não basta; não usa "dono ou tenant"; restringe o principal às claims do JWT com "nunca do corpo" e não admite principal vindo do corpo; traz o contraste ExistsForTenant sem o dono (NÃO é ancoragem) versus a consulta com OwnerId == sub && TenantId == tenant; declara que checagem de existência não é ancoragem; nenhuma brecha pode aparecer, nem literal ("basta o runId existir", "conferido contra um registro que o servidor gravou") nem por paráfrase frase a frase (frase que fala de existência e ancoragem sem negar, ou que abre exceção por id GUID/UUID/imprevisível/não enumerável);
#   [4] a linha BLOCKER da tabela de Severidades cita proveniência/ancoragem server-side sem "dono ou tenant", e nenhuma linha HIGH/MEDIUM/LOW cita proveniência, ancoragem, registro filho ou campo de autorização (rebaixamento, inclusive por paráfrase);
#   [5] o checklist de saída referencia o §12 e a travessia de registros filhos, sem "dono ou tenant";
#   [6] controle de regressão: RBAC e IDOR continuam presentes.
#
# Mutação embutida: o mesmo verificador roda sobre cópias mutadas do agente e cada uma TEM de reprovar — (a) proveniência rebaixada de BLOCKER para HIGH na tabela, (b) corpo do §12 esvaziado, (c) brecha "basta o runId existir" inserida no §12, (d) regra de ancoragem trocada pelo critério antigo sem comparação de dono, (e) linha do checklist removida, (f) critério BLOCKER movido para fora do §12, (g) "existência também conta como ancoragem quando o id é um GUID imprevisível", (h) principal vindo de "claims do JWT ou campo tenantId do corpo", (i) "existência não é ancoragem, exceto com ids GUID não enumeráveis", (j) linha HIGH com "campo de autorização sem ancoragem em registro filho" sem a palavra proveniência, (k) travessia de filhos rebaixada para "Opcionalmente, quando houver tempo", (l) comparação de volta para "dono ou tenant", (m) contraste ExistsForTenant removido. Controle (arquivo real) rc 0 antes; recontrole (arquivo real) rc 0 depois. Cada mutação confere que a cópia de fato diverge do original (cmp), para não haver mutação fantasma.
#
# PBT: não se aplica — texto normativo, não espaço de entradas.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT="$WS/template/.forge/agents/review/security-reviewer.md"
[ -f "$AGENT" ] || { echo "FAIL (agente ausente: $AGENT)"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/forge-w272.XXXXXX")"
trap 'rm -rf "$T"' EXIT

# Corpo do §12: da linha seguinte ao header até o próximo header (## ou ###) ou separador ---.
section12() {
  awk '/^### 12\. Proveni/{f=1; next} f && (/^##/ || /^---[[:space:]]*$/){exit} f' "$1"
}

# Verificador. Imprime o motivo da primeira falha em stdout e devolve 1; devolve 0 se tudo passa.
check_agent() {
  local file="$1" body joined row low checklist
  grep -qE '^### 12\. Proveni' "$file" || { echo "FAIL [1] (sem header '### 12. Proveniência')"; return 1; }
  body="$(section12 "$file")"
  # guarda de instrumento: header presente e corpo sem nenhuma linha não vazia = corpo esvaziado.
  [ "$(grep -c '[^[:space:]]' <<<"$body" || true)" -ge 5 ] \
    || { echo "FAIL [1] (corpo do §12 vazio ou quase vazio)"; return 1; }
  # junta numa linha só e normaliza espaços: frases que atravessam quebra de linha continuam casando.
  joined="$(tr '\n' ' ' <<<"$body" | tr -s '[:space:]' ' ')"

  grep -qiE 'quem escreve(u)? esse campo' <<<"$joined" \
    || { echo "FAIL [2] (§12 não pergunta quem escreveu o campo)"; return 1; }
  grep -qiE 'sem ancoragem server-side[^|]{0,250}BLOCKER' <<<"$joined" \
    || { echo "FAIL [2] (critério BLOCKER por falta de ancoragem server-side ausente do corpo do §12)"; return 1; }
  # travessia de filhos é obrigação incondicional: bullet próprio, em negrito, sem condicional.
  grep -qE '^- \*\*Percorra também os registros filhos\*\*' <<<"$body" \
    || { echo "FAIL [2] (§12 não tem o bullet incondicional 'Percorra também os registros filhos')"; return 1; }
  if grep -i 'registros filhos' <<<"$body" | grep -qiE 'opcional|quando houver tempo|se houver tempo|se possível|quando possível|se der|eventualmente|facultativ|desejável|best[- ]effort'; then
    echo "FAIL [2] (travessia de registros filhos rebaixada a condicional/opcional)"; return 1
  fi

  # dono do registro comparado com o principal do token (sub/userId), e o tenant TAMBÉM.
  grep -qiE 'ANTES do efeito[^.;]{0,80}compara o dono gravado no registro com o principal do token \(`sub`/`userId`\) e também o tenant' <<<"$joined" \
    || { echo "FAIL [3] (regra de ancoragem do §12 não exige comparar o dono com o principal do token, e também o tenant, antes do efeito)"; return 1; }
  grep -qiE 'comparar só o tenant num recurso que tem dono de usuário não basta' <<<"$joined" \
    || { echo "FAIL [3] (§12 não declara que comparar só o tenant num recurso com dono de usuário não basta)"; return 1; }
  if grep -qiE 'dono ou tenant|dono/tenant' <<<"$joined"; then
    echo "FAIL [3] (§12 usa 'dono ou tenant': permite comparar só o tenant num recurso de usuário)"; return 1
  fi
  # principal: só das claims do JWT, com a negação explícita do corpo.
  grep -qiE 'principal vem exclusivamente das claims do JWT[^.;]{0,40}, nunca do corpo' <<<"$joined" \
    || { echo "FAIL [3] (§12 não restringe o principal às claims do JWT com 'nunca do corpo')"; return 1; }
  if perl -ne 'BEGIN{$r=1} $r=0 if /claims do JWT(?:(?!nunca)[^.;]){0,40}?\bou\b(?:(?!nunca)[^.;]){0,60}?\b(?:corpo|payload|body|query|header|rota)\b/i || /principal[^.;]{0,80}(?<!nunca )\b(?:do|da|no|na) (?:corpo|payload|body)\b/i; END{exit $r}' <<<"$joined"; then
    echo "FAIL [3] (§12 admite principal vindo do corpo/campo do cliente)"; return 1
  fi
  # contraste do falso positivo: ExistsForTenant sem o dono não ancora; a consulta com dono e tenant ancora.
  grep -qE 'ExistsForTenant\(runId, tenant\)` sem o dono[^;]{0,80}NÃO é ancoragem suficiente' <<<"$joined" \
    || { echo "FAIL [3] (§12 sem o contraste: ExistsForTenant sem o dono NÃO é ancoragem suficiente)"; return 1; }
  grep -qF 'r.OwnerId == sub && r.TenantId == tenant' <<<"$joined" \
    || { echo "FAIL [3] (§12 sem o exemplo ancorado com dono E tenant)"; return 1; }
  grep -qiE 'existência não é ancoragem' <<<"$joined" \
    || { echo "FAIL [3] (§12 não declara que checagem de existência não é ancoragem)"; return 1; }
  # brechas: aceitar existência como ancoragem, ou o critério antigo sem comparação de dono.
  if perl -ne 'BEGIN{$r=1} $r=0 if /(?<!não )\bbasta (?:que )?(?:o|a) [^.]{0,40}?exist/i || /\bexist\S*(?: do registro)? (?:basta|é suficiente|ancora|é ancoragem)/i || /conferido contra um registro que o (?:próprio )?servidor gravou/i; END{exit $r}' <<<"$joined"; then
    echo "FAIL [3] (§12 contém brecha que aceita existência/registro gravado sem comparação de dono)"; return 1
  fi
  # brechas por paráfrase, frase a frase: frase que fala de existência e ancoragem tem de NEGAR (não é/não conta como ancoragem) e não pode abrir exceção; nenhuma frase sobre ancoragem abre exceção por id imprevisível (GUID/UUID/não enumerável) — imprevisibilidade não é autorização. Perl roda em modo byte: acentos vão em alternância (ã|Ã|a), nunca em classe [ãa].
  if perl -ne 'BEGIN{$r=1} for my $s (split /(?<=[.;:])\s+/) { my $ex = $s =~ /exist/i; my $an = $s =~ /ancor/i; my $exc = $s =~ /\b(?:exceto|salvo|a menos que|desde que|com exceção|ressalvad)|\bGUID|\bUUID|imprevis|enumer/i; $r=0 if $ex && $an && ($s !~ /n(?:ã|Ã|a)o (?:é|É|conta como|vale como|serve como) ancoragem/i || $exc); $r=0 if $an && $exc; } $r=0 if /\bGUID|\bUUID|imprevis|n(?:ã|a)o enumer/i; END{exit $r}' <<<"$joined"; then
    echo "FAIL [3] (§12 contém frase que aceita existência como ancoragem ou abre exceção por id imprevisível)"; return 1
  fi

  row="$(grep -E '^\| `BLOCKER` \|' "$file" || true)"
  [ -n "$row" ] || { echo "FAIL [4] (linha BLOCKER da tabela de Severidades ausente)"; return 1; }
  grep -qi 'proveni' <<<"$row" && grep -qi 'ancoragem server-side' <<<"$row" \
    || { echo "FAIL [4] (proveniência sem ancoragem não está na linha BLOCKER da tabela)"; return 1; }
  low="$(grep -E '^\| `(HIGH|MEDIUM|LOW)` \|' "$file" || true)"
  [ -n "$low" ] || { echo "FAIL [4] (linhas HIGH/MEDIUM/LOW ausentes — tabela não foi lida)"; return 1; }
  # rebaixamento por paráfrase: nem proveniência, nem ancoragem, nem registro filho, nem campo de
  # autorização podem aparecer em HIGH/MEDIUM/LOW.
  if grep -qiE 'proveni|ancor|registros? filhos?|campo de autoriza' <<<"$low"; then
    echo "FAIL [4] (proveniência/ancoragem aparece em linha HIGH/MEDIUM/LOW — rebaixamento)"; return 1
  fi
  if grep -qiE 'dono ou tenant|dono/tenant' <<<"$row"; then
    echo "FAIL [4] (linha BLOCKER usa 'dono ou tenant')"; return 1
  fi

  checklist="$(awk '/^## Checklist de Saída/{f=1; next} /^## /{f=0} f' "$file")"
  [ -n "$checklist" ] || { echo "FAIL [5] (checklist de saída ausente ou vazio)"; return 1; }
  grep -qi 'proveni[^|]*§12' <<<"$checklist" \
    || { echo "FAIL [5] (checklist não referencia o passo de proveniência §12)"; return 1; }
  grep -qi 'registros filhos' <<<"$checklist" \
    || { echo "FAIL [5] (checklist não menciona a travessia de registros filhos)"; return 1; }
  if grep -qiE 'dono ou tenant|dono/tenant' <<<"$checklist"; then
    echo "FAIL [5] (checklist usa 'dono ou tenant')"; return 1
  fi

  grep -q 'RBAC' "$file" || { echo "FAIL [6] (RBAC sumiu — regressão)"; return 1; }
  grep -q 'IDOR' "$file" || { echo "FAIL [6] (IDOR sumiu — regressão)"; return 1; }
  return 0
}

echo "[controle] agente real"
check_agent "$AGENT" || exit 1
echo "OK controle (rc 0)"

# Aplica <perl-expr> sobre uma cópia, exige que a cópia mude e que o verificador reprove.
mutate_expect_fail() {
  local name="$1" expr="$2" copy="$T/$1.md" out rc
  cp "$AGENT" "$copy"
  perl -0pi -e "$expr" "$copy"
  if cmp -s "$AGENT" "$copy"; then
    echo "FAIL mutação $name (fantasma: a cópia não mudou — expressão não casou)"; exit 1
  fi
  set +e; out="$(check_agent "$copy")"; rc=$?; set -e
  if [ "$rc" -ne 1 ]; then
    echo "FAIL mutação $name (verificador devolveu rc $rc; esperado 1)"; exit 1
  fi
  echo "OK mutação $name reprova (rc 1): $out"
}

echo "[mutações]"
mutate_expect_fail a-rebaixa-na-tabela \
  's/(\| `BLOCKER` \|[^\n]*?), campo de autorização\/proveniência[^\n]*?registro filho( \|)/$1$2/; s/(\| `HIGH` \|[^\n]*?)( \|\n)/$1, campo de autorização\/proveniência sem ancoragem server-side$2/'
mutate_expect_fail b-esvazia-corpo-12 \
  's/(### 12\. Proveni[^\n]*\n).*?(\n---\n)/$1$2/s'
mutate_expect_fail c-brecha-existencia \
  's/(### 12\. Proveni[^\n]*\n)/$1\n- Basta o `runId` existir no banco para o identificador contar como ancorado.\n/'
mutate_expect_fail d-ancoragem-sem-comparacao \
  's/- Ancoragem server-side válida, e só ela:[^\n]*\n/- Ancoragem server-side válida: o identificador foi gerado pelo servidor, ou é resolvido a partir do token, ou é conferido contra um registro que o próprio servidor gravou antes.\n/'
mutate_expect_fail f-blocker-fora-do-12 \
  's/(- Se o campo é escrito \*\*pelo próprio ator[^\n]*\n)(.*?## Severidades\n)/$2\n$1/s'
mutate_expect_fail e-checklist-sem-12 \
  's/^- \[ \] \*\*Proveniência verificada[^\n]*\n//m'
mutate_expect_fail g-existencia-guid-conta \
  's/(### 12\. Proveni[^\n]*\n)/$1\n- Checagem de existência também conta como ancoragem quando o id é um GUID imprevisível.\n/'
mutate_expect_fail h-principal-do-corpo \
  's/das claims do JWT do token autenticado, nunca do corpo, da query, da rota, do header ou de qualquer outro campo enviado pelo cliente/das claims do JWT ou campo tenantId do corpo/'
mutate_expect_fail i-existencia-excecao-guid \
  's/Checagem de existência não é ancoragem:/Checagem de existência não é ancoragem, exceto com ids GUID não enumeráveis:/'
mutate_expect_fail j-high-sem-proveni \
  's/(\| `HIGH` \|[^\n]*?)( \|\n)/$1, campo de autorização sem ancoragem em registro filho$2/'
mutate_expect_fail k-filhos-opcional \
  's/\*\*Percorra também os registros filhos\*\*,/Opcionalmente, quando houver tempo, percorra também os registros filhos,/'
mutate_expect_fail l-dono-ou-tenant \
  's/compara o dono gravado no registro com o principal do token \(`sub`\/`userId`\) e também o tenant gravado com o tenant do token/compara o dono ou tenant gravado no registro com o principal autenticado/'
mutate_expect_fail m-sem-contraste \
  's/^- Contraste para não aprovar em falso:[^\n]*\n//m'

echo "[recontrole] agente real"
check_agent "$AGENT" || exit 1
echo "OK recontrole (rc 0)"

echo "PASS w272-security-reviewer-provenance-gate"
