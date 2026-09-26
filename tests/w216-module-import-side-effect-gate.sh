#!/usr/bin/env bash
# Gate W216 — importar sync-adapters.mjs não pode reconciliar os adapters do consumidor (#130).
#
# POR QUE ESTE GATE EXISTE. `template/.forge/scripts/lib/sync-adapters.mjs` rodava o bloco
# `// ── entry ──` incondicionalmente: sem guarda de módulo principal, `import(...)` (por exemplo
# um gate que só quer LER uma função exportada) reconciliava os 70 arquivos do consumidor como
# efeito colateral — apagando em silêncio qualquer edição pendente sob `.claude/`. Medido antes
# da correção: `OK claude adapter synced (70 targets)` e `OK reconcile complete: 1 active
# [claude]` apareciam ao simplesmente importar o módulo. Um gate com efeito colateral no alvo não
# mede o alvo, mede a si mesmo (issue #130).
#
#   [1] positivo — import: importar o módulo não muda o hash de nenhum arquivo sob `.claude/` e
#       expõe pelo menos uma exportação nomeada (`reconcile`, nome estável documentado no PR —
#       #160 e #125 tocam o mesmo arquivo depois e importam esta função).
#   [2] positivo — caminho legítimo: invocar `sync-adapters.sh` (que faz `exec node
#       lib/sync-adapters.mjs`, a invocação real) continua imprimindo `OK reconcile complete` e
#       sobrescrevendo a edição pendente — a guarda não pode desarmar quem de fato é o principal.
#       Sem este cenário, uma guarda invertida ou quebrada (ver retratação da issue #130: uma
#       versão usava `require('node:fs')` dentro de ESM, cujo `ReferenceError` caía no `catch` e
#       fazia a guarda avaliar `false` também na invocação direta) passaria em silêncio: o
#       gerador simplesmente pararia de reconciliar, sem nenhuma mensagem de erro.
#   [3] mutação — remover a condição da guarda (`if (isMainModule())` → `if (true)`) restaura o
#       defeito original: [1] falha porque o hash muda. Controle e recontrole por `cmp -s` contra
#       cópia salva da lib, restaurada byte a byte depois da asserção.
#   [4] mutação — inverter a condição (`isMainModule()` → `!isMainModule()`) faz a invocação
#       direta ser tratada como import: [2] falha porque `OK reconcile complete` não aparece.
#       Mesma disciplina de controle/recontrole.
#
# As duas mutações mutam a CÓPIA da lib dentro da fixture (`$C/.forge/scripts/lib/...`), nunca o
# arquivo rastreado em `template/.forge/`, e cada uma é restaurada e reconferida por `cmp -s`
# antes de seguir (LDG-0175/w213: fixture de teste nunca muta arquivo rastreado sem restauração
# garantida). Propriedade PBT: não se aplica — a entrada é binária (importado ou principal), sem
# espaço de valores para gerar.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_REL=".forge/scripts/lib/sync-adapters.mjs"
overall_rc=0

# nova_fixture <dir> — instala o template e resolve os placeholders mínimos para o gerador rodar.
nova_fixture() {
  local dir="$1"
  cp -R "$WS/template/.forge" "$dir/.forge"
  perl -pi -e 's/<PROJECT_SLUG>/fixture-app/g; s/<PROJECT_NAME>/Fixture App/g; s/<PROJECT_DESCRIPTION>/Fixture do w216/g' \
    "$dir/.forge/FORGE.md" "$dir/.forge/constitution.md" "$dir/.forge/context.md"
  bash "$dir/.forge/scripts/sync-adapters.sh" --set claude >/dev/null 2>&1
}

# hash_claude <dir> — hash agregado de todo arquivo sob .claude/ (não só o alvo editado).
hash_claude() {
  (cd "$1" && find .claude -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z \
    | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}

# marca_pendente <dir> — anexa uma linha a um arquivo real sob .claude/agents/ e devolve o path.
marca_pendente() {
  local dir="$1"
  local target
  target="$(find "$dir/.claude/agents" -name '*.md' | LC_ALL=C sort | head -1)"
  printf '// edicao-pendente\n' >> "$target"
  printf '%s' "$target"
}

# cenario_import <dir> — importa o módulo a partir do cwd da fixture; imprime "IMPORT_OK" e a
# lista de exports em stdout; qualquer exceção do import aparece em stderr (capturada pelo
# chamador).
cenario_import() {
  local dir="$1"
  ( cd "$dir" && node --input-type=module -e "
      const m = await import('$dir/$LIB_REL');
      console.log('IMPORT_OK exports=' + JSON.stringify(Object.keys(m).sort()));
    " )
}

# ── [1] import não muda nenhum arquivo sob .claude/ e expõe >= 1 exportação ─────────────────────
echo "[1] importar o módulo não reconcilia o consumidor e expõe exportação nomeada"
T1="$(mktemp -d /tmp/forge-w216-1.XXXXXX)"
nova_fixture "$T1"
TARGET1="$(marca_pendente "$T1")"
HASH_BEFORE1="$(hash_claude "$T1")"
IMPORT_OUT1="$(cenario_import "$T1" 2>&1)"
IMPORT_RC1=$?
HASH_AFTER1="$(hash_claude "$T1")"

if [ "$IMPORT_RC1" -ne 0 ]; then
  echo "FAIL [1]: o import lançou exceção (rc=$IMPORT_RC1) — não deveria nem reconciliar nem quebrar: $IMPORT_OUT1"
  overall_rc=1
elif [ "$HASH_BEFORE1" != "$HASH_AFTER1" ]; then
  echo "FAIL [1]: o import mudou o hash de .claude/ ($HASH_BEFORE1 -> $HASH_AFTER1) — reconciliou como efeito colateral"
  overall_rc=1
elif ! grep -q '"reconcile"' <<<"$IMPORT_OUT1"; then
  echo "FAIL [1]: o import não expôs a exportação nomeada 'reconcile' — $IMPORT_OUT1"
  overall_rc=1
else
  echo "OK [1] — hash de .claude/ inalterado ($HASH_AFTER1) e exportação 'reconcile' presente"
fi
rm -rf "$T1"

# ── [2] invocação direta continua sendo o caminho legítimo ──────────────────────────────────────
echo "[2] invocação direta (sync-adapters.sh) continua reconciliando"
T2="$(mktemp -d /tmp/forge-w216-2.XXXXXX)"
nova_fixture "$T2"
TARGET2="$(marca_pendente "$T2")"
HASH_BEFORE2="$(hash_claude "$T2")"
DIRECT_OUT2="$(bash "$T2/.forge/scripts/sync-adapters.sh" 2>&1)"
HASH_AFTER2="$(hash_claude "$T2")"

if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT2"; then
  echo "FAIL [2]: a invocação direta não imprimiu 'OK reconcile complete' — a guarda desarmou o caminho legítimo: $DIRECT_OUT2"
  overall_rc=1
elif [ "$HASH_BEFORE2" = "$HASH_AFTER2" ]; then
  echo "FAIL [2]: a invocação direta não mudou nada sob .claude/ — a edição pendente deveria ter sido sobrescrita pela reconciliação real"
  overall_rc=1
else
  echo "OK [2] — 'OK reconcile complete' impresso e a edição pendente foi sobrescrita"
fi
rm -rf "$T2"

# ── [3] mutação — remover a condição da guarda reintroduz o efeito colateral no import ──────────
echo "[3] mutação: remover a condição da guarda faz [1] voltar a falhar"
T3="$(mktemp -d /tmp/forge-w216-3.XXXXXX)"
nova_fixture "$T3"
LIB3="$T3/$LIB_REL"
BACKUP3="$(mktemp /tmp/forge-w216-3-backup.XXXXXX)"
cp "$LIB3" "$BACKUP3"

perl -pi -e 's/if \(isMainModule\(\)\) \{/if (true) {/' "$LIB3"
if cmp -s "$LIB3" "$BACKUP3"; then
  echo "FAIL [3]: a mutação não alterou nenhum byte da lib — o perl não achou o padrão da guarda"
  overall_rc=1
else
  TARGET3="$(marca_pendente "$T3")"
  HASH_BEFORE3="$(hash_claude "$T3")"
  cenario_import "$T3" >/dev/null 2>&1
  HASH_AFTER3="$(hash_claude "$T3")"
  if [ "$HASH_BEFORE3" = "$HASH_AFTER3" ]; then
    echo "FAIL [3]: com a guarda removida o import NÃO mudou .claude/ — a mutação não acusa, o cenário [1] não mede a guarda"
    overall_rc=1
  else
    echo "OK [3] — mutação acusa: sem a guarda, o import reconcilia de novo (hash $HASH_BEFORE3 -> $HASH_AFTER3)"
  fi
fi

cp "$BACKUP3" "$LIB3"
if ! cmp -s "$LIB3" "$BACKUP3"; then
  echo "FAIL [3]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  # recontrole: com a lib restaurada, [1] volta a passar (fixture completa: .forge E .claude)
  T3B="$(mktemp -d /tmp/forge-w216-3b.XXXXXX)"
  rm -rf "$T3B"
  cp -R "$T3" "$T3B"
  TARGET3B="$(marca_pendente "$T3B")"
  HASH_BEFORE3B="$(hash_claude "$T3B")"
  cenario_import "$T3B" >/dev/null 2>&1
  HASH_AFTER3B="$(hash_claude "$T3B")"
  if [ "$HASH_BEFORE3B" != "$HASH_AFTER3B" ]; then
    echo "FAIL [3]: recontrole — com a lib restaurada, o import ainda muda .claude/"
    overall_rc=1
  else
    echo "OK [3] recontrole — lib restaurada byte a byte, import volta a não ter efeito colateral"
  fi
  rm -rf "$T3B"
fi
rm -rf "$T3" "$BACKUP3"

# ── [4] mutação — inverter a condição da guarda desarma a invocação direta ──────────────────────
echo "[4] mutação: inverter a condição da guarda faz [2] voltar a falhar"
T4="$(mktemp -d /tmp/forge-w216-4.XXXXXX)"
nova_fixture "$T4"
LIB4="$T4/$LIB_REL"
BACKUP4="$(mktemp /tmp/forge-w216-4-backup.XXXXXX)"
cp "$LIB4" "$BACKUP4"

perl -pi -e 's/if \(isMainModule\(\)\) \{/if (!isMainModule()) {/' "$LIB4"
if cmp -s "$LIB4" "$BACKUP4"; then
  echo "FAIL [4]: a mutação não alterou nenhum byte da lib — o perl não achou o padrão da guarda"
  overall_rc=1
else
  TARGET4="$(marca_pendente "$T4")"
  DIRECT_OUT4="$(bash "$T4/.forge/scripts/sync-adapters.sh" 2>&1)"
  if grep -q 'OK reconcile complete\|OK claude adapter synced' <<<"$DIRECT_OUT4"; then
    echo "FAIL [4]: com a condição invertida a invocação direta AINDA reconciliou — a mutação não acusa, o cenário [2] não mede a guarda: $DIRECT_OUT4"
    overall_rc=1
  else
    echo "OK [4] — mutação acusa: com a condição invertida, a invocação direta deixa de reconciliar (saída: '${DIRECT_OUT4:-<vazia>}')"
  fi
fi

cp "$BACKUP4" "$LIB4"
if ! cmp -s "$LIB4" "$BACKUP4"; then
  echo "FAIL [4]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  # recontrole: com a lib restaurada, [2] volta a passar
  DIRECT_OUT4B="$(bash "$T4/.forge/scripts/sync-adapters.sh" 2>&1)"
  if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT4B"; then
    echo "FAIL [4]: recontrole — com a lib restaurada, a invocação direta ainda não reconcilia: $DIRECT_OUT4B"
    overall_rc=1
  else
    echo "OK [4] recontrole — lib restaurada byte a byte, invocação direta volta a reconciliar"
  fi
fi
rm -rf "$T4" "$BACKUP4"

if [ "$overall_rc" -eq 0 ]; then
  echo "OK"
else
  echo "FAIL"
fi
exit "$overall_rc"
