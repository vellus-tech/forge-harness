#!/usr/bin/env bash
# Gate W216 — importar sync-adapters.mjs não pode reconciliar nem matar o consumidor (#130).
#
# POR QUE ESTE GATE EXISTE. `template/.forge/scripts/lib/sync-adapters.mjs` rodava o bloco
# `// ── entry ──` incondicionalmente: sem guarda de módulo principal, `import(...)` (por exemplo
# um gate que só quer LER uma função exportada) reconciliava os 70 arquivos do consumidor como
# efeito colateral — apagando em silêncio qualquer edição pendente sob `.claude/`. Medido antes
# da correção: `OK claude adapter synced (70 targets)` e `OK reconcile complete: 1 active
# [claude]` apareciam ao simplesmente importar o módulo. Um gate com efeito colateral no alvo não
# mede o alvo, mede a si mesmo (issue #130). Uma segunda revisão (achado de correção) mediu que
# `import()` a partir de um cwd SEM `.forge/FORGE.md` também matava o processo importador — um
# segundo `process.exit(1)` de nível de módulo, anterior ao bloco de entrada, sobrevivia à
# primeira correção — e que a exportação certa para #125/#160 lerem é uma função PURA que MONTA
# a fiação (`preToolUseWiring(root)`), não `reconcile` (que escreve — deixou de ser exportada,
# achado de correção MEDIUM-4: nunca foi exportada em `origin/develop` antes desta issue, nenhum
# consumidor real a importa, e só o CLI, internamente, precisa dela).
#
#   [1] positivo — import: importar o módulo não muda o hash de nenhum arquivo sob `.claude/`,
#       expõe SÓ `preToolUseWiring` (a leitura pura que #125/#160 usam — `reconcile` não é mais
#       exportada), e `preToolUseWiring(dir)` bate byte a byte com a chave `hooks` do
#       `.claude/settings.json` que a invocação real materializa — as duas leituras nunca podem
#       divergir.
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
#   [5] positivo — import a partir de um cwd SEM `.forge/FORGE.md` (nenhum `--root` passado)
#       sobrevive: rc 0, nem `SURVIVED`/`CAUGHT` ambíguo (a retratação da issue mediu nenhum dos
#       dois — o processo simplesmente morria), e a exportação `preToolUseWiring` continua
#       presente. Uma leitura pura não pode depender de o cwd de quem importou ter um projeto
#       Forge válido.
#   [6] mutação — reintroduzir o `process.exit(1)` de nível de módulo que fechava [5] mata o
#       processo de novo: rc ≠ 0 e nem `SURVIVED` nem `CAUGHT` aparecem. Controle/recontrole por
#       `cmp -s` contra cópia isolada (nunca a lib rastreada em `template/.forge/`).
#   [7] positivo — invocação legítima a partir de um diretório com ESPAÇO no caminho continua
#       reconciliando. Existe para dar ao mutante [9] um jeito de acusar que funciona em
#       QUALQUER SO (não só macOS/`/tmp`): `import.meta.url` percent-encoda o espaço (`%20`), a
#       comparação crua de string com `process.argv[1]` (sem `%20`) não bate.
#   [8] positivo — invocação legítima via SYMLINK apontando para o `.mjs` continua reconciliando.
#       `realpathSync` nos dois lados resolve o link; a comparação crua de `import.meta.url` (que
#       o Node resolve para o alvo real do link) contra `process.argv[1]` (que preserva o caminho
#       do link, não resolvido) não bateria.
#   [9] mutação — trocar `isMainModule()` pela alternativa descartada da seção do plano
#       (`import.meta.url === 'file://' + process.argv[1]`, o idioma de `plugin-build.mjs`) faz
#       [7] (espaço) e [8] (symlink) falharem: a invocação legítima deixa de reconciliar em
#       QUALQUER SO — não é uma armadilha específica de `$TMPDIR` no macOS. Controle/recontrole
#       por `cmp -s`, uma fixture por sub-caso, sempre restaurada.
#   [10] positivo — achado de correção MEDIUM-1: a mensagem/ordem de erro do CLI quando falta
#       `.forge/FORGE.md` é IDÊNTICA (texto e ordem) nos três modos de invocação (default,
#       `--adapter all`, `--set claude`) — a checagem roda na primeira linha do galho principal,
#       antes de `readActive()`/`writeActive()` tocarem `forge.yaml`. Sem isto, `--set`/default
#       vazavam `FAIL (ENOENT: ... forge.yaml)` em vez de `FAIL (no .forge/FORGE.md ... — run
#       /forge:init first)`, porque a checagem só rodava dentro de `reconcile()`, depois de
#       `readActive()`/`writeActive()` já terem tentado ler `forge.yaml` (que nem existe num
#       diretório sem `.forge`).
#   [11] positivo — achado de correção MEDIUM-2: `--set` que falha por falta de `.forge/FORGE.md`
#       NÃO grava `forge.yaml` (sha256 inalterado) — antes, `writeActive()` rodava ANTES da
#       checagem (que só existia dentro de `reconcile()`), então a falha ainda assim deixava
#       `forge.yaml` mutado, a mesma classe de defeito da #130 (escrever no consumidor quando
#       deveria só recusar).
#   [12] mutação — mover a checagem de `.forge/FORGE.md` de volta para SÓ dentro de `reconcile()`
#       (removendo a checagem adiantada no galho principal) restaura os dois defeitos: [10] volta
#       a divergir (`ENOENT` em vez da mensagem amigável nos modos default/`--adapter all`) e [11]
#       volta a gravar `forge.yaml` na falha do `--set`. Controle/recontrole por `cmp -s`.
#   [13] positivo + mutação — achado de correção MEDIUM-3: `preToolUseWiring(root)` usa SÓ a raiz
#       explícita recebida — nunca o `ROOT`/`FORGE_YAML` de módulo de quem importou. Cenário:
#       duas fixtures com `handoff.auto` diferente (A=true, B=false); importa a lib a partir do
#       cwd/`ROOT` de B (sem `--root`) e chama `preToolUseWiring(A)`; o resultado tem que bater
#       byte a byte com o `.claude/settings.json` REAL de A (que tem `SessionStart`/`SessionEnd`),
#       nunca com o de B. Mutação: trocar `join(root, '.forge', 'forge.yaml')` por `FORGE_YAML`
#       (a constante de módulo) faz a leitura cair no `forge.yaml` de B (o cwd de quem importou)
#       em vez do `root` explícito — o resultado passa a bater com B (sem `SessionStart`/
#       `SessionEnd`), não com A, e o cenário acusa. Controle/recontrole por `cmp -s`.
#
# Todas as mutações mutam uma CÓPIA da lib dentro da fixture temporária, nunca o arquivo
# rastreado em `template/.forge/`, e cada uma é restaurada e reconferida por `cmp -s` antes de
# seguir (LDG-0175/w213: fixture de teste nunca muta arquivo rastreado sem restauração
# garantida). Propriedade PBT: não se aplica — a entrada é binária (importado ou principal) ou uma
# enumeração pequena e exaustiva (raiz A ou raiz B), sem espaço de valores contínuo para gerar.
set -uo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_REL=".forge/scripts/lib/sync-adapters.mjs"
LIB_TEMPLATE="$WS/template/$LIB_REL"   # a lib rastreada (fixtures copiam template/.forge → $dir/.forge)
TMPROOT="${TMPDIR:-/tmp}"
overall_rc=0
CLEANUP_DIRS=()
trap 'rm -rf "${CLEANUP_DIRS[@]}" 2>/dev/null || true' EXIT

track() { CLEANUP_DIRS+=("$1"); }

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

# cenario_import <lib-path> <cwd> — importa a lib (path absoluto, via pathToFileURL — nunca
# interpolado cru num literal JS, LDG do gate: um caminho com espaço ou aspa não pode quebrar a
# sintaxe) a partir do cwd dado; imprime "SURVIVED exports=[...]" ou "CAUGHT <mensagem>".
cenario_import() {
  local lib="$1" cwd="$2"
  ( cd "$cwd" && LIB_PATH="$lib" node --input-type=module -e "
      import { pathToFileURL } from 'node:url';
      try {
        const m = await import(pathToFileURL(process.env.LIB_PATH).href);
        console.log('SURVIVED exports=' + JSON.stringify(Object.keys(m).sort()));
      } catch (e) {
        console.log('CAUGHT ' + e.message);
      }
    " )
}

# ── [1] import não muda nenhum arquivo sob .claude/, expõe preToolUseWiring/reconcile, e a
#        leitura pura bate com o settings.json real ────────────────────────────────────────────
echo "[1] importar o módulo não reconcilia o consumidor, expõe preToolUseWiring, e ela bate com o settings.json real"
T1="$(mktemp -d "$TMPROOT/forge-w216-1.XXXXXX")"; track "$T1"
nova_fixture "$T1"
TARGET1="$(marca_pendente "$T1")"
HASH_BEFORE1="$(hash_claude "$T1")"
IMPORT_OUT1="$(cenario_import "$T1/$LIB_REL" "$T1" 2>&1)"
IMPORT_RC1=$?
HASH_AFTER1="$(hash_claude "$T1")"

if [ "$IMPORT_RC1" -ne 0 ]; then
  echo "FAIL [1]: o import lançou exceção (rc=$IMPORT_RC1) — não deveria nem reconciliar nem quebrar: $IMPORT_OUT1"
  overall_rc=1
elif [ "$HASH_BEFORE1" != "$HASH_AFTER1" ]; then
  echo "FAIL [1]: o import mudou o hash de .claude/ ($HASH_BEFORE1 -> $HASH_AFTER1) — reconciliou como efeito colateral"
  overall_rc=1
elif ! grep -q 'preToolUseWiring' <<<"$IMPORT_OUT1"; then
  echo "FAIL [1]: o import não expôs a exportação nomeada 'preToolUseWiring' (a leitura pura que #125/#160 usam) — $IMPORT_OUT1"
  overall_rc=1
elif ! grep -q '\["preToolUseWiring"\]' <<<"$IMPORT_OUT1"; then
  echo "FAIL [1]: o módulo expõe exportações além de 'preToolUseWiring' (achado de correção MEDIUM-4: 'reconcile' não deve mais ser exportada — só o CLI precisa dela) — $IMPORT_OUT1"
  overall_rc=1
else
  WIRING1="$(cd "$T1" && LIB_PATH="$T1/$LIB_REL" ROOT_PATH="$T1" node --input-type=module -e "
    import { pathToFileURL } from 'node:url';
    const m = await import(pathToFileURL(process.env.LIB_PATH).href);
    console.log(JSON.stringify(m.preToolUseWiring(process.env.ROOT_PATH)));
  " 2>&1)"
  SETTINGS_HOOKS1="$(node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).hooks))" "$T1/.claude/settings.json" 2>&1)"
  if [ "$WIRING1" != "$SETTINGS_HOOKS1" ]; then
    echo "FAIL [1]: preToolUseWiring(root) diverge do settings.json real materializado:"
    echo "  preToolUseWiring: $WIRING1"
    echo "  settings.json:    $SETTINGS_HOOKS1"
    overall_rc=1
  else
    echo "OK [1] — hash de .claude/ inalterado ($HASH_AFTER1), exportações presentes, preToolUseWiring == settings.json.hooks"
  fi
fi

# ── [2] invocação direta continua sendo o caminho legítimo ──────────────────────────────────────
echo "[2] invocação direta (sync-adapters.sh) continua reconciliando"
T2="$(mktemp -d "$TMPROOT/forge-w216-2.XXXXXX")"; track "$T2"
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

# ── [3] mutação — remover a condição da guarda reintroduz o efeito colateral no import ──────────
echo "[3] mutação: remover a condição da guarda faz [1] voltar a falhar"
T3="$(mktemp -d "$TMPROOT/forge-w216-3.XXXXXX")"; track "$T3"
nova_fixture "$T3"
LIB3="$T3/$LIB_REL"
BACKUP3="$(mktemp "$TMPROOT/forge-w216-3-backup.XXXXXX")"; track "$BACKUP3"
cp "$LIB3" "$BACKUP3"

perl -pi -e 's/if \(isMainModule\(\)\) \{/if (true) {/' "$LIB3"
if cmp -s "$LIB3" "$BACKUP3"; then
  echo "FAIL [3]: a mutação não alterou nenhum byte da lib — o perl não achou o padrão da guarda"
  overall_rc=1
else
  TARGET3="$(marca_pendente "$T3")"
  HASH_BEFORE3="$(hash_claude "$T3")"
  cenario_import "$LIB3" "$T3" >/dev/null 2>&1
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
  T3B="$(mktemp -d "$TMPROOT/forge-w216-3b.XXXXXX")"; track "$T3B"
  rm -rf "$T3B"
  cp -R "$T3" "$T3B"
  TARGET3B="$(marca_pendente "$T3B")"
  HASH_BEFORE3B="$(hash_claude "$T3B")"
  cenario_import "$T3B/$LIB_REL" "$T3B" >/dev/null 2>&1
  HASH_AFTER3B="$(hash_claude "$T3B")"
  if [ "$HASH_BEFORE3B" != "$HASH_AFTER3B" ]; then
    echo "FAIL [3]: recontrole — com a lib restaurada, o import ainda muda .claude/"
    overall_rc=1
  else
    echo "OK [3] recontrole — lib restaurada byte a byte, import volta a não ter efeito colateral"
  fi
fi

# ── [4] mutação — inverter a condição da guarda desarma a invocação direta ──────────────────────
echo "[4] mutação: inverter a condição da guarda faz [2] voltar a falhar"
T4="$(mktemp -d "$TMPROOT/forge-w216-4.XXXXXX")"; track "$T4"
nova_fixture "$T4"
LIB4="$T4/$LIB_REL"
BACKUP4="$(mktemp "$TMPROOT/forge-w216-4-backup.XXXXXX")"; track "$BACKUP4"
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

# ── [5] import a partir de um cwd SEM .forge/FORGE.md sobrevive ─────────────────────────────────
echo "[5] importar sem .forge/FORGE.md no cwd não mata o processo (regressão #130, achado HIGH-2)"
T5="$(mktemp -d "$TMPROOT/forge-w216-5.XXXXXX")"; track "$T5"
IMPORT_OUT5="$(cenario_import "$LIB_TEMPLATE" "$T5" 2>&1)"
IMPORT_RC5=$?

if [ "$IMPORT_RC5" -ne 0 ]; then
  echo "FAIL [5]: rc=$IMPORT_RC5 — o import matou o processo a partir de um cwd sem .forge/FORGE.md: $IMPORT_OUT5"
  overall_rc=1
elif ! grep -q '^SURVIVED' <<<"$IMPORT_OUT5"; then
  echo "FAIL [5]: nem SURVIVED apareceu (nem CAUGHT seria aceitável — uma leitura pura não deveria nem rejeitar) — $IMPORT_OUT5"
  overall_rc=1
elif ! grep -q 'preToolUseWiring' <<<"$IMPORT_OUT5"; then
  echo "FAIL [5]: import sem .forge/FORGE.md sobreviveu mas não expôs 'preToolUseWiring' — $IMPORT_OUT5"
  overall_rc=1
else
  echo "OK [5] — $IMPORT_OUT5"
fi

# ── [6] mutação — reintroduzir o process.exit de nível de módulo mata o import de novo ──────────
echo "[6] mutação: reintroduzir o process.exit de nível de módulo faz [5] voltar a falhar"
T6="$(mktemp -d "$TMPROOT/forge-w216-6.XXXXXX")"; track "$T6"
LIB6="$T6/sync-adapters.mjs"
cp "$LIB_TEMPLATE" "$LIB6"
BACKUP6="$(mktemp "$TMPROOT/forge-w216-6-backup.XXXXXX")"; track "$BACKUP6"
cp "$LIB6" "$BACKUP6"
CWD6="$T6/cwd-sem-forge"; mkdir -p "$CWD6"

perl -pi -e 's/const ADAPTERS_DIR = join\(FORGE, .adapters.\);/const ADAPTERS_DIR = join(FORGE, "adapters");\nif (!existsSync(join(FORGE, "FORGE.md"))) { console.error("FAIL sem FORGE.md sob " + ROOT); process.exit(1); }/' "$LIB6"
if cmp -s "$LIB6" "$BACKUP6"; then
  echo "FAIL [6]: a mutação não alterou nenhum byte da lib — o perl não achou a linha de âncora (ADAPTERS_DIR)"
  overall_rc=1
else
  IMPORT_OUT6="$(cenario_import "$LIB6" "$CWD6" 2>&1)"
  IMPORT_RC6=$?
  if [ "$IMPORT_RC6" -eq 0 ] && grep -q '^SURVIVED' <<<"$IMPORT_OUT6"; then
    echo "FAIL [6]: com o process.exit de módulo reintroduzido o import AINDA sobreviveu — a mutação não acusa, o cenário [5] não mede a regressão: $IMPORT_OUT6"
    overall_rc=1
  else
    echo "OK [6] — mutação acusa: com o process.exit reintroduzido, o import volta a matar o processo (rc=$IMPORT_RC6, saída: '${IMPORT_OUT6:-<vazia>}')"
  fi
fi

cp "$BACKUP6" "$LIB6"
if ! cmp -s "$LIB6" "$BACKUP6"; then
  echo "FAIL [6]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  IMPORT_OUT6B="$(cenario_import "$LIB6" "$CWD6" 2>&1)"
  IMPORT_RC6B=$?
  if [ "$IMPORT_RC6B" -ne 0 ] || ! grep -q '^SURVIVED' <<<"$IMPORT_OUT6B"; then
    echo "FAIL [6]: recontrole — com a lib restaurada, o import ainda não sobrevive: rc=$IMPORT_RC6B $IMPORT_OUT6B"
    overall_rc=1
  else
    echo "OK [6] recontrole — lib restaurada byte a byte, import volta a sobreviver"
  fi
fi

# ── [7] invocação legítima a partir de um caminho com ESPAÇO continua reconciliando ─────────────
echo "[7] invocação direta a partir de um diretório com espaço no caminho continua reconciliando"
T7BASE="$(mktemp -d "$TMPROOT/forge-w216-7.XXXXXX")"; track "$T7BASE"
T7="$T7BASE/com espaco"
mkdir -p "$T7"
nova_fixture "$T7"
TARGET7="$(marca_pendente "$T7")"
HASH_BEFORE7="$(hash_claude "$T7")"
DIRECT_OUT7="$(bash "$T7/.forge/scripts/sync-adapters.sh" 2>&1)"
HASH_AFTER7="$(hash_claude "$T7")"

if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT7"; then
  echo "FAIL [7]: invocação a partir de caminho com espaço não reconciliou: $DIRECT_OUT7"
  overall_rc=1
elif [ "$HASH_BEFORE7" = "$HASH_AFTER7" ]; then
  echo "FAIL [7]: invocação a partir de caminho com espaço não sobrescreveu a edição pendente"
  overall_rc=1
else
  echo "OK [7] — reconcilia normalmente mesmo com espaço no caminho"
fi

# ── [8] invocação legítima via SYMLINK para o .mjs continua reconciliando ───────────────────────
echo "[8] invocação via symlink para o .mjs continua reconciliando (realpathSync nos dois lados)"
T8="$(mktemp -d "$TMPROOT/forge-w216-8.XXXXXX")"; track "$T8"
nova_fixture "$T8"
TARGET8="$(marca_pendente "$T8")"
HASH_BEFORE8="$(hash_claude "$T8")"
LINK8="$T8/entry-via-symlink.mjs"
ln -s "$T8/$LIB_REL" "$LINK8"
DIRECT_OUT8="$(cd "$T8" && node "$LINK8" --root "$T8" 2>&1)"
HASH_AFTER8="$(hash_claude "$T8")"

if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT8"; then
  echo "FAIL [8]: invocação via symlink não reconciliou: $DIRECT_OUT8"
  overall_rc=1
elif [ "$HASH_BEFORE8" = "$HASH_AFTER8" ]; then
  echo "FAIL [8]: invocação via symlink não sobrescreveu a edição pendente"
  overall_rc=1
else
  echo "OK [8] — reconcilia normalmente mesmo invocado via symlink"
fi

# ── [9] mutação — a alternativa descartada (comparação crua de URL) quebra [7] e [8] em ────────
#        QUALQUER SO, não só sob o symlink /tmp→/private/tmp do macOS ───────────────────────────
echo "[9] mutação: comparação crua de import.meta.url (alternativa descartada) quebra espaço e symlink"

echo "  [9a] sub-caso espaço no caminho"
T9ABASE="$(mktemp -d "$TMPROOT/forge-w216-9a.XXXXXX")"; track "$T9ABASE"
T9A="$T9ABASE/com espaco"
mkdir -p "$T9A"
nova_fixture "$T9A"
LIB9A="$T9A/$LIB_REL"
BACKUP9A="$(mktemp "$TMPROOT/forge-w216-9a-backup.XXXXXX")"; track "$BACKUP9A"
cp "$LIB9A" "$BACKUP9A"

perl -pi -e "s/return realpathSync\(process.argv\[1\]\) === realpathSync\(fileURLToPath\(import.meta.url\)\);/return import.meta.url === 'file:\/\/' + process.argv[1];/" "$LIB9A"
if cmp -s "$LIB9A" "$BACKUP9A"; then
  echo "FAIL [9a]: a mutação não alterou nenhum byte da lib — o perl não achou o corpo de isMainModule()"
  overall_rc=1
else
  TARGET9A="$(marca_pendente "$T9A")"
  DIRECT_OUT9A="$(bash "$T9A/.forge/scripts/sync-adapters.sh" 2>&1)"
  if grep -q 'OK reconcile complete' <<<"$DIRECT_OUT9A"; then
    echo "FAIL [9a]: com a comparação crua, a invocação legítima sob caminho com espaço AINDA reconciliou — a mutação não acusa: $DIRECT_OUT9A"
    overall_rc=1
  else
    echo "OK [9a] — mutação acusa: comparação crua quebra a invocação legítima sob caminho com espaço (saída: '${DIRECT_OUT9A:-<vazia>}')"
  fi
fi
cp "$BACKUP9A" "$LIB9A"
if ! cmp -s "$LIB9A" "$BACKUP9A"; then
  echo "FAIL [9a]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  DIRECT_OUT9AB="$(bash "$T9A/.forge/scripts/sync-adapters.sh" 2>&1)"
  if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT9AB"; then
    echo "FAIL [9a]: recontrole — com a lib restaurada, a invocação sob espaço ainda não reconcilia: $DIRECT_OUT9AB"
    overall_rc=1
  else
    echo "OK [9a] recontrole — lib restaurada byte a byte, invocação sob espaço volta a reconciliar"
  fi
fi

echo "  [9b] sub-caso invocação via symlink"
T9B="$(mktemp -d "$TMPROOT/forge-w216-9b.XXXXXX")"; track "$T9B"
nova_fixture "$T9B"
LIB9B="$T9B/$LIB_REL"
BACKUP9B="$(mktemp "$TMPROOT/forge-w216-9b-backup.XXXXXX")"; track "$BACKUP9B"
cp "$LIB9B" "$BACKUP9B"

perl -pi -e "s/return realpathSync\(process.argv\[1\]\) === realpathSync\(fileURLToPath\(import.meta.url\)\);/return import.meta.url === 'file:\/\/' + process.argv[1];/" "$LIB9B"
if cmp -s "$LIB9B" "$BACKUP9B"; then
  echo "FAIL [9b]: a mutação não alterou nenhum byte da lib — o perl não achou o corpo de isMainModule()"
  overall_rc=1
else
  TARGET9B="$(marca_pendente "$T9B")"
  LINK9B="$T9B/entry-via-symlink.mjs"
  ln -s "$LIB9B" "$LINK9B"
  DIRECT_OUT9B="$(cd "$T9B" && node "$LINK9B" --root "$T9B" 2>&1)"
  if grep -q 'OK reconcile complete' <<<"$DIRECT_OUT9B"; then
    echo "FAIL [9b]: com a comparação crua, a invocação legítima via symlink AINDA reconciliou — a mutação não acusa: $DIRECT_OUT9B"
    overall_rc=1
  else
    echo "OK [9b] — mutação acusa: comparação crua quebra a invocação legítima via symlink (saída: '${DIRECT_OUT9B:-<vazia>}')"
  fi
fi
cp "$BACKUP9B" "$LIB9B"
if ! cmp -s "$LIB9B" "$BACKUP9B"; then
  echo "FAIL [9b]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  DIRECT_OUT9BB="$(cd "$T9B" && node "$LINK9B" --root "$T9B" 2>&1)"
  if ! grep -q 'OK reconcile complete' <<<"$DIRECT_OUT9BB"; then
    echo "FAIL [9b]: recontrole — com a lib restaurada, a invocação via symlink ainda não reconcilia: $DIRECT_OUT9BB"
    overall_rc=1
  else
    echo "OK [9b] recontrole — lib restaurada byte a byte, invocação via symlink volta a reconciliar"
  fi
fi

# ── [10] mensagem/ordem de erro do CLI idênticas nos três modos de invocação (MEDIUM-1) ─────────
echo "[10] mensagem de 'sem FORGE.md' é idêntica em --set / --adapter all / default (achado de correção MEDIUM-1)"
T10="$(mktemp -d "$TMPROOT/forge-w216-10.XXXXXX")"; track "$T10"   # dir totalmente vazio, sem .forge
EXPECT10="no .forge/FORGE.md under $T10 — run /forge:init first"

OUT10_DEFAULT="$(node "$LIB_TEMPLATE" --root "$T10" 2>&1)"; RC10_DEFAULT=$?
OUT10_ALL="$(node "$LIB_TEMPLATE" --root "$T10" --adapter all 2>&1)"; RC10_ALL=$?
OUT10_SET="$(node "$LIB_TEMPLATE" --root "$T10" --set claude 2>&1)"; RC10_SET=$?

fail10=0
for par in "default:$RC10_DEFAULT:$OUT10_DEFAULT" "adapter-all:$RC10_ALL:$OUT10_ALL" "set:$RC10_SET:$OUT10_SET"; do
  nome="${par%%:*}"; resto="${par#*:}"; rc="${resto%%:*}"; out="${resto#*:}"
  if [ "$rc" -eq 0 ]; then
    echo "FAIL [10]: modo '$nome' saiu rc=0 num root vazio — deveria recusar"
    fail10=1
  elif [ "FAIL ($EXPECT10)" != "$out" ]; then
    echo "FAIL [10]: modo '$nome' produziu mensagem diferente da esperada"
    echo "  esperado: FAIL ($EXPECT10)"
    echo "  obtido:   $out"
    fail10=1
  fi
done
if [ "$fail10" -eq 0 ]; then
  echo "OK [10] — os três modos produzem a mesma mensagem/ordem: FAIL ($EXPECT10)"
else
  overall_rc=1
fi

# ── [11] --set falho por falta de FORGE.md não grava forge.yaml (MEDIUM-2) ──────────────────────
echo "[11] --set que falha por falta de .forge/FORGE.md não grava forge.yaml (achado de correção MEDIUM-2)"
T11="$(mktemp -d "$TMPROOT/forge-w216-11.XXXXXX")"; track "$T11"
mkdir -p "$T11/.forge"
cp "$WS/template/.forge/forge.yaml" "$T11/.forge/forge.yaml"   # forge.yaml existe, FORGE.md não
SHA_BEFORE11="$(shasum -a 256 "$T11/.forge/forge.yaml" | cut -d' ' -f1)"
OUT11="$(node "$LIB_TEMPLATE" --root "$T11" --set claude,cursor 2>&1)"; RC11=$?
SHA_AFTER11="$(shasum -a 256 "$T11/.forge/forge.yaml" | cut -d' ' -f1)"

if [ "$RC11" -eq 0 ]; then
  echo "FAIL [11]: --set saiu rc=0 sem .forge/FORGE.md — deveria recusar: $OUT11"
  overall_rc=1
elif [ "$SHA_BEFORE11" != "$SHA_AFTER11" ]; then
  echo "FAIL [11]: forge.yaml mudou de sha ($SHA_BEFORE11 -> $SHA_AFTER11) na falha do --set — a escrita rodou antes da checagem"
  overall_rc=1
else
  echo "OK [11] — forge.yaml inalterado ($SHA_AFTER11), --set recusou antes de escrever: $OUT11"
fi

# ── [12] mutação — checagem de FORGE.md de volta para só dentro de reconcile() ──────────────────
echo "[12] mutação: mover a checagem de FORGE.md de volta para só dentro de reconcile() faz [10]/[11] voltarem a falhar"
LIB12="$(mktemp "$TMPROOT/forge-w216-12-lib.XXXXXX.mjs")"; track "$LIB12"
cp "$LIB_TEMPLATE" "$LIB12"
BACKUP12="$(mktemp "$TMPROOT/forge-w216-12-backup.XXXXXX")"; track "$BACKUP12"
cp "$LIB12" "$BACKUP12"

perl -0777 -pi -e "s/if \(isMainModule\(\)\) \{\n  try \{\n    if \(!existsSync\(join\(FORGE, 'FORGE.md'\)\)\) \{\n      throw new Error\(\`no \.forge\/FORGE\.md under \\\$\{ROOT\} — run \/forge:init first\`\);\n    \}\n/if (isMainModule()) {\n  try {\n/" "$LIB12"
if cmp -s "$LIB12" "$BACKUP12"; then
  echo "FAIL [12]: a mutação não alterou nenhum byte da lib — o perl não achou a checagem adiantada"
  overall_rc=1
else
  T12A="$(mktemp -d "$TMPROOT/forge-w216-12a.XXXXXX")"; track "$T12A"   # vazio, para o modo default
  OUT12A="$(node "$LIB12" --root "$T12A" 2>&1)"

  T12B="$(mktemp -d "$TMPROOT/forge-w216-12b.XXXXXX")"; track "$T12B"
  mkdir -p "$T12B/.forge"
  cp "$WS/template/.forge/forge.yaml" "$T12B/.forge/forge.yaml"
  SHA_BEFORE12B="$(shasum -a 256 "$T12B/.forge/forge.yaml" | cut -d' ' -f1)"
  OUT12B="$(node "$LIB12" --root "$T12B" --set claude,cursor 2>&1)"
  SHA_AFTER12B="$(shasum -a 256 "$T12B/.forge/forge.yaml" | cut -d' ' -f1)"

  if grep -q 'run /forge:init first' <<<"$OUT12A" && [ "$SHA_BEFORE12B" = "$SHA_AFTER12B" ]; then
    echo "FAIL [12]: com a checagem só dentro de reconcile(), [10]/[11] AINDA passariam — a mutação não acusa (default: '$OUT12A'; sha forge.yaml inalterado)"
    overall_rc=1
  else
    echo "OK [12] — mutação acusa: modo default vazou '${OUT12A}' (esperava-se ENOENT, não a mensagem amigável) e/ou forge.yaml mudou de sha ($SHA_BEFORE12B -> $SHA_AFTER12B) na falha do --set"
  fi
fi

cp "$BACKUP12" "$LIB12"
if ! cmp -s "$LIB12" "$BACKUP12"; then
  echo "FAIL [12]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  T12R="$(mktemp -d "$TMPROOT/forge-w216-12r.XXXXXX")"; track "$T12R"
  OUT12R="$(node "$LIB12" --root "$T12R" 2>&1)"
  if [ "$OUT12R" != "FAIL (no .forge/FORGE.md under $T12R — run /forge:init first)" ]; then
    echo "FAIL [12]: recontrole — com a lib restaurada, a mensagem no modo default ainda diverge: $OUT12R"
    overall_rc=1
  else
    echo "OK [12] recontrole — lib restaurada byte a byte, mensagem volta a bater"
  fi
fi

# ── [13] preToolUseWiring(root) usa só a raiz explícita, nunca o ROOT de módulo (MEDIUM-3) ──────
echo "[13] preToolUseWiring(root) usa a raiz explícita recebida, nunca o ROOT/forge.yaml de módulo de quem importou"
T13A="$(mktemp -d "$TMPROOT/forge-w216-13a.XXXXXX")"; track "$T13A"
nova_fixture "$T13A"
perl -0777 -pi -e "s/(handoff:\n(?:.*\n){2}  auto: )false/\${1}true/" "$T13A/.forge/forge.yaml"
grep -q 'auto: true' <(sed -n '/^handoff:/,/^ledger:/p' "$T13A/.forge/forge.yaml") \
  || { echo "FAIL [13]: setup — não consegui ligar handoff.auto:true em T13A"; overall_rc=1; }
bash "$T13A/.forge/scripts/sync-adapters.sh" --adapter all >/dev/null 2>&1   # rematerializa settings.json com SessionStart/SessionEnd

T13B="$(mktemp -d "$TMPROOT/forge-w216-13b.XXXXXX")"; track "$T13B"
nova_fixture "$T13B"   # handoff.auto:false (default do template)

HOOKS_A13="$(node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).hooks))" "$T13A/.claude/settings.json")"
HOOKS_B13="$(node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).hooks))" "$T13B/.claude/settings.json")"
if [ "$HOOKS_A13" = "$HOOKS_B13" ]; then
  echo "FAIL [13]: setup — os hooks materializados de A e B são idênticos, o cenário não consegue diferenciar raiz"
  overall_rc=1
else
  WIRING13="$(cd "$T13B" && LIB_PATH="$T13B/$LIB_REL" ROOT_A="$T13A" node --input-type=module -e "
    import { pathToFileURL } from 'node:url';
    const m = await import(pathToFileURL(process.env.LIB_PATH).href);
    console.log(JSON.stringify(m.preToolUseWiring(process.env.ROOT_A)));
  " 2>&1)"
  if [ "$WIRING13" != "$HOOKS_A13" ]; then
    echo "FAIL [13]: preToolUseWiring(T13A), importado a partir do cwd/ROOT de T13B, não bate com o settings.json REAL de T13A"
    echo "  esperado (A): $HOOKS_A13"
    echo "  obtido:       $WIRING13"
    overall_rc=1
  elif [ "$WIRING13" = "$HOOKS_B13" ]; then
    echo "FAIL [13]: preToolUseWiring(T13A) bateu com B (o cwd/ROOT de módulo de quem importou) em vez de com A (a raiz explícita) — vazou o ROOT do módulo"
    overall_rc=1
  else
    echo "OK [13] — preToolUseWiring(T13A) bate byte a byte com o settings.json real de T13A, mesmo importado a partir do cwd/ROOT de T13B"
  fi
fi

echo "  [13-mut] mutação: trocar o root explícito pelo FORGE_YAML de módulo faz [13] voltar a falhar"
LIB13="$(mktemp "$TMPROOT/forge-w216-13-lib.XXXXXX.mjs")"; track "$LIB13"
cp "$T13B/$LIB_REL" "$LIB13"
BACKUP13="$(mktemp "$TMPROOT/forge-w216-13-backup.XXXXXX")"; track "$BACKUP13"
cp "$LIB13" "$BACKUP13"

perl -pi -e "s/const forgeYaml = join\(root, '\.forge', 'forge\.yaml'\);/const forgeYaml = FORGE_YAML;/" "$LIB13"
if cmp -s "$LIB13" "$BACKUP13"; then
  echo "FAIL [13-mut]: a mutação não alterou nenhum byte da lib — o perl não achou a linha de 'forgeYaml'"
  overall_rc=1
else
  WIRING13M="$(cd "$T13B" && LIB_PATH="$LIB13" ROOT_A="$T13A" node --input-type=module -e "
    import { pathToFileURL } from 'node:url';
    const m = await import(pathToFileURL(process.env.LIB_PATH).href);
    console.log(JSON.stringify(m.preToolUseWiring(process.env.ROOT_A)));
  " 2>&1)"
  if [ "$WIRING13M" = "$HOOKS_A13" ]; then
    echo "FAIL [13-mut]: com o root explícito trocado pelo FORGE_YAML de módulo, o resultado AINDA bate com A — a mutação não acusa: $WIRING13M"
    overall_rc=1
  else
    echo "OK [13-mut] — mutação acusa: com FORGE_YAML de módulo, preToolUseWiring(T13A) passa a ler o forge.yaml de B (cwd de quem importou) em vez da raiz explícita ($WIRING13M)"
  fi
fi

cp "$BACKUP13" "$LIB13"
if ! cmp -s "$LIB13" "$BACKUP13"; then
  echo "FAIL [13-mut]: a restauração da lib mutada não bateu byte a byte com a cópia salva"
  overall_rc=1
else
  WIRING13R="$(cd "$T13B" && LIB_PATH="$LIB13" ROOT_A="$T13A" node --input-type=module -e "
    import { pathToFileURL } from 'node:url';
    const m = await import(pathToFileURL(process.env.LIB_PATH).href);
    console.log(JSON.stringify(m.preToolUseWiring(process.env.ROOT_A)));
  " 2>&1)"
  if [ "$WIRING13R" != "$HOOKS_A13" ]; then
    echo "FAIL [13-mut]: recontrole — com a lib restaurada, preToolUseWiring(T13A) ainda não bate com A: $WIRING13R"
    overall_rc=1
  else
    echo "OK [13-mut] recontrole — lib restaurada byte a byte, preToolUseWiring(T13A) volta a bater com A"
  fi
fi

if [ "$overall_rc" -eq 0 ]; then
  echo "OK"
else
  echo "FAIL"
fi
exit "$overall_rc"
