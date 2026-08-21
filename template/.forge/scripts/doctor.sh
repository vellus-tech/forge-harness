#!/usr/bin/env bash
# doctor.sh — verifica a tooling de diagnóstico (e LSP, informativo) por stack
# presente no repositório. Por padrão apenas REPORTA o que falta; com --install
# tenta instalar os faltantes via o gerenciador de cada stack (opt-in explícito).
#
# Por que existe: as rules de "análise de impacto / LSP" dependem de que o
# DIAGNÓSTICO da stack (compilador / typechecker / linter) esteja instalado —
# esse é o passo que de fato valida uma edição. O LSP server é desejável para
# navegação semântica, mas é secundário. Este script não instala nada sem a
# flag --install e nunca roda automaticamente no init-project.
#
# Uso:
#   bash .forge/scripts/doctor.sh            # só reporta (default)
#   bash .forge/scripts/doctor.sh --install  # reporta e instala faltantes (opt-in)
#
# Saída: código 0 se todos os diagnósticos das stacks detectadas estão OK
#        (no modo report); código 1 se houver diagnóstico faltando.

set -u

INSTALL=0
case "${1:-}" in
  --install) INSTALL=1 ;;
  ""|--report) INSTALL=0 ;;
  -h|--help)
    grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  *) echo "Argumento desconhecido: $1 (use --install ou --report)"; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# ── helpers ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
else GREEN=""; RED=""; YEL=""; DIM=""; RST=""; fi

MISSING_DIAG=0
have() { command -v "$1" >/dev/null 2>&1; }

ok()    { printf "  %s✓%s %s\n" "$GREEN" "$RST" "$1"; }
miss()  { printf "  %s✗%s %s\n" "$RED" "$RST" "$1"; }
info()  { printf "  %s·%s %s\n" "$YEL" "$RST" "$1"; }
hint()  { printf "      %s↳ %s%s\n" "$DIM" "$1" "$RST"; }

# Detecta stacks por marcadores no repo (ignora node_modules/bin/obj/.git).
find_marker() {
  find . \( -path ./node_modules -o -path ./.git -o -name bin -o -name obj -o -path ./dist \) -prune \
       -o -name "$1" -print 2>/dev/null | head -1
}

# ── Forge harness (§19.1) — roda mesmo sem stack detectada ──────────────────
check_harness() {
  [ -d "$ROOT/.forge" ] || return 0
  echo "Forge harness"

  for f in FORGE.md forge.yaml; do
    if [ -f "$ROOT/.forge/$f" ]; then ok "harness: .forge/$f"
    else miss "harness: .forge/$f ausente"; MISSING_DIAG=1; fi
  done

  if [ -f "$ROOT/AGENTS.md" ]; then
    if head -1 "$ROOT/AGENTS.md" | grep -q 'Generated from .forge/FORGE.md'; then
      ok "harness: AGENTS.md é projeção gerada do FORGE.md"
    else
      info "harness: AGENTS.md sem header de arquivo gerado (rode .forge/scripts/sync-adapters.sh)"
    fi
  else
    miss "harness: AGENTS.md ausente (rode .forge/scripts/sync-adapters.sh)"; MISSING_DIAG=1
  fi

  # root instruction symlinks are owned by their adapter — checked only when the adapter is
  # active (CLAUDE.md↔claude, QWEN.md↔qwen, GEMINI.md↔gemini). An existing link whose adapter
  # is inactive is a stale prune leftover (drift).
  active_adapters="$(awk '/^  adapters:/{g=1;next} g&&/^    - /{print $2;next} g{exit}' "$ROOT/.forge/forge.yaml" 2>/dev/null)"
  adapter_active() { printf '%s\n' "$active_adapters" | grep -qx "$1"; }
  check_link() {  # $1=adapter $2=linkfile
    if adapter_active "$1"; then
      if [ -L "$ROOT/$2" ] && [ "$(readlink "$ROOT/$2")" = "AGENTS.md" ]; then
        ok "harness: $2 -> AGENTS.md (symlink)"
      elif [ -f "$ROOT/$2" ] && head -1 "$ROOT/$2" | grep -q 'Generated from .forge/FORGE.md'; then
        ok "harness: $2 (cópia materializada gerada)"
      else
        miss "harness: $2 não resolve para AGENTS.md"; MISSING_DIAG=1
      fi
    elif [ -e "$ROOT/$2" ] || [ -L "$ROOT/$2" ]; then
      miss "harness: $2 órfão (adapter $1 inativo — rode sync-adapters --adapter all)"; MISSING_DIAG=1
    fi
  }
  check_link claude CLAUDE.md
  check_link qwen QWEN.md
  check_link gemini GEMINI.md

  # the leak check guards MIGRATED CONTENT (agents/rules/skills + the 8 legacy commands);
  # the machinery (adapters/, scripts/, hooks/) and the harness meta-commands legitimately name
  # the generated .claude/ dir, so they are excluded. USER DATA dirs are also excluded: their
  # content is authored by the user (spec text may quote the generated dir; deploy files under
  # worktrees may carry the app's own PROJECT-style tokens) and is not the canonical harness source.
  USER_DATA='/(specs|worktrees|product|evals|custom)/'
  leaks="$(grep -rl '\.claude/' "$ROOT/.forge" 2>/dev/null | grep -vE "/(adapters|scripts|hooks)/|/commands/harness/|$USER_DATA" | wc -l | tr -d ' ')"
  if [ "$leaks" -eq 0 ]; then ok "harness: fonte canônica sem refs .claude/"
  else miss "harness: $leaks arquivo(s) da fonte canônica com refs .claude/"; MISSING_DIAG=1; fi

  orphans="$(grep -rl '<PROJECT_[A-Z_]*>' "$ROOT/.forge" 2>/dev/null | grep -vE "/templates/|$USER_DATA" | wc -l | tr -d ' ')"
  if [ "$orphans" -eq 0 ]; then ok "harness: sem placeholders <PROJECT_*> órfãos"
  else miss "harness: $orphans arquivo(s) com placeholders <PROJECT_*> não preenchidos"; MISSING_DIAG=1; fi

  # Cabeçalho "Generated from" na 1ª linha do artefato gerado.
#
# Era `head -1 "$f" | grep -q 'Generated from'` inline. Sob `pipefail`, `grep -q` sai no primeiro
# casamento e o `head` que ainda escreve leva SIGPIPE: o pipeline devolve 141, a falha é promovida,
# e o `|| drift=$((drift+1))` conta como DRIFT um arquivo que estava correto (issue #49, instância
# 3). Sem pipeline não há SIGPIPE a promover.
_generated_header() { # _generated_header <arquivo>
  [ -f "$1" ] || return 1
  case "$(head -1 "$1" 2>/dev/null)" in
    *"Generated from"*) return 0 ;;
  esac
  return 1
}

locks_found=0
  for lock in "$ROOT"/.forge/adapters/*.lock.yaml; do
    [ -f "$lock" ] || continue
    locks_found=$((locks_found + 1))
    aname="$(basename "$lock" .lock.yaml)"
    drift=0
    while read -r dest hash; do
      [ -n "$dest" ] || continue
      if [ "$hash" = "symlink" ]; then
        { [ -L "$ROOT/$dest" ] || _generated_header "$ROOT/$dest"; } || drift=$((drift + 1))
      elif [ -f "$ROOT/$dest" ]; then
        actual="sha256:$(shasum -a 256 "$ROOT/$dest" | cut -d' ' -f1)"
        [ "$actual" = "$hash" ] || drift=$((drift + 1))
      else
        drift=$((drift + 1))
      fi
    done <<EOF_LOCK
$(awk '/^  - dest: /{d=$3} /^    sha256: /{print d" "$2}' "$lock")
EOF_LOCK
    if [ "$drift" -eq 0 ]; then ok "harness: adapter $aname sem drift (lockfile íntegro)"
    else miss "harness: $drift alvo(s) do adapter $aname com drift (rode .forge/scripts/sync-adapters.sh)"; MISSING_DIAG=1; fi
  done
  if [ "$locks_found" -eq 0 ]; then
    info "harness: nenhum lockfile de adapter (rode .forge/scripts/sync-adapters.sh)"
  fi

  # graph staleness (§25): if a graph exists and tracked graphed files changed
  # since the last build, warn (informational — never load-bearing).
  if [ -f "$ROOT/.forge/graph/graph.json" ]; then
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      changed="$(git -C "$ROOT" status --porcelain 2>/dev/null | sed 's/^...//' || true)"
      stale=0
      while read -r f; do
        [ -n "$f" ] || continue
        grep -q "\"id\": \"$f\"" "$ROOT/.forge/graph/graph.json" 2>/dev/null && stale=$((stale + 1))
      done <<EOF_CHG
$changed
EOF_CHG
      if [ "$stale" -gt 0 ]; then info "harness: grafo possivelmente desatualizado ($stale arquivo(s) grafado(s) mudaram — rode /forge:graph update)"
      else ok "harness: grafo de código atualizado"; fi
    fi
  fi

  # ledger advisory (§ ledger-consultation): informativo, NUNCA load-bearing. Resume o estado e
  # sinaliza itens 'promoted' cujo change de destino sumiu sem baixa (promovido-e-abandonado antes
  # do fechamento automático existir, ou elo quebrado) — candidatos a reabrir/resolver à mão.
  if [ -f "$ROOT/.forge/ledger/ledger.json" ]; then
    orphans="$(node -e '
      const fs=require("fs"), root=process.argv[1];
      const d=JSON.parse(fs.readFileSync(root+"/.forge/ledger/ledger.json","utf8"));
      const active=new Set(); const archived=new Set();
      try{ for(const n of fs.readdirSync(root+"/.forge/specs/active")) active.add(n);}catch{}
      try{ for(const n of fs.readdirSync(root+"/.forge/specs/archived")) archived.add(n.replace(/^\d{4}-\d{2}-\d{2}-/,""));}catch{}
      const orph=(d.entries||[]).filter(e=>e.status==="promoted" && e.links && e.links.promoted_to && !active.has(e.links.promoted_to) && !archived.has(e.links.promoted_to));
      process.stdout.write(orph.map(e=>e.id).join(", "));
    ' "$ROOT" 2>/dev/null || true)"
    if [ -n "$orphans" ]; then info "harness: ledger — item(ns) promoted com change de destino ausente: $orphans (reabra ou resolva via /forge:ledger)"
    else ok "harness: ledger sem itens promovidos órfãos"; fi
  fi

  # liaison advisory (§ liaison-protocol): informativo, NUNCA load-bearing. O estado do canal é
  # fluxo de conversa entre repositórios, não drift do harness — um peer que ainda não sincronizou,
  # uma mensagem em quarentena esperando o thread-open, um ack pendente: nada disso é defeito desta
  # instalação, e reprovar o doctor por isso faria o operador aprender a ignorar o doctor.
  # Divergência e conflito aparecem aqui porque exigem decisão humana, mas com marcador `·`.
  # Mutex de carga pesada (issue #52). Três coisas que só o doctor pode dizer: se o repositório
  # declara `enabled: true` mas o interruptor da MÁQUINA está desligado (o interruptor mora em
  # /tmp e some no reboot — é a mitigação declarada dessa incerteza), se há órfão, e se ainda há
  # lock vivo em caminho LEGADO derivado de TMPDIR, que não serializa com o ancorado.
  if [ -f "$ROOT/.forge/scripts/lib/heavy-mutex.sh" ]; then
    hm_line="$(FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/lib/heavy-mutex.sh" 2>/dev/null; \
               FORGE_ROOT="$ROOT" bash -c '. "$0"; forge_heavy_mutex_status 2>/dev/null | tr "\n" " "' \
               "$ROOT/.forge/scripts/lib/heavy-mutex.sh" 2>/dev/null || true)"
    [ -n "$hm_line" ] && echo "  · harness: HEAVY-MUTEX: $hm_line"
    hm_res="$(awk '/^heavy_mutex:/{f=1;next} f&&/^[a-z]/{f=0} f&&/^[[:space:]]*resource:/{sub(/^[[:space:]]*resource:[[:space:]]*/,"");gsub(/["'"'"']/,"");print;exit}' "$ROOT/.forge/forge.yaml" 2>/dev/null)"
    [ -n "$hm_res" ] || hm_res="forge-heavy-suite"
    if awk '/^heavy_mutex:/{f=1;next} f&&/^[a-z]/{f=0} f&&/^[[:space:]]*enabled:[[:space:]]*true/{print "y";exit}' "$ROOT/.forge/forge.yaml" 2>/dev/null | grep -q y; then
      [ -f "/tmp/$hm_res.q.enabled" ] \
        || echo "  · harness: heavy_mutex habilitado no repo, mas a FILA da máquina está desligada (ligue com: heavy-run.sh queue enable)"
    fi
    # A raiz legada é montada em duas partes de propósito: escrita numa linha só, ela casaria a
    # regra 1 do check-heavy-mutex — que procura quem PRODUZ caminho de lock a partir de variável
    # do chamador — e o gate reprovaria o próprio template. Aqui a intenção é o oposto: DETECTAR
    # o caminho legado para avisar que ele não serializa.
    hm_legroot="${TMPDIR:-/tmp}"
    hm_leg="$hm_legroot/$hm_res".lock
    if [ "$hm_leg" != "/tmp/$hm_res.lock" ] && [ -d "$hm_leg" ]; then
      echo "  ✗ harness: lock LEGADO vivo em $hm_leg — este caminho NÃO serializa com /tmp/$hm_res.lock (recolha com: heavy-run.sh sweep --legacy)"
    fi
  fi

  if [ -d "$ROOT/.forge/liaison" ] && [ -f "$ROOT/.forge/scripts/liaison-ops.sh" ]; then
    liaison_line="$(FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/liaison-ops.sh" status 2>/dev/null || true)"
    if [ -n "$liaison_line" ] && [ "$liaison_line" != "LIAISON: não inicializado" ]; then
      info "harness: ${liaison_line}"
      conflicts="$(find "$ROOT/.forge/liaison" -mindepth 3 -maxdepth 3 -path '*/conflicts/*' -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
      if [ "${conflicts:-0}" -gt 0 ]; then
        info "harness: liaison — $conflicts conflito(s) registrado(s) em conflicts/ (decisão humana; ver /forge:liaison)"
      fi
    fi
  fi

  # changes órfãos (§ lifecycle-reconcile): change implementado/mergeado cujo manifest nunca
  # acompanhou — verified parado sem /forge:archive, ou TASKs 100% com status ainda
  # tasks-ready/implementing. Detector determinista (zero-LLM). Informativo, NUNCA load-bearing
  # (marcador `·`, jamais `✗`/exit 1) — é estado de fluxo do operador, não drift do harness.
  if [ -d "$ROOT/.forge/specs/active" ] && command -v node >/dev/null 2>&1 \
     && [ -f "$ROOT/.forge/scripts/lib/orphan-changes.mjs" ]; then
    orphan_lines="$(node "$ROOT/.forge/scripts/lib/orphan-changes.mjs" "$ROOT" --lines 2>/dev/null || true)"
    if [ -n "$orphan_lines" ]; then
      while IFS="$(printf '\t')" read -r bucket oid ostatus; do
        [ -n "$oid" ] || continue
        if [ "$bucket" = "merged_unarchived" ]; then
          info "harness: change '$oid' ($ostatus) mergeado/verificado sem baixa — /forge:archive (ou /forge:verify)"
        else
          info "harness: change '$oid' com TASKs 100% mas status '$ostatus' — avance (spec-transition.sh $oid implementing/implemented) e /forge:verify"
        fi
      done <<EOF_ORPHAN
$orphan_lines
EOF_ORPHAN
    else
      ok "harness: sem changes órfãos (lifecycle SDD reconciliado)"
    fi
  fi

  # drift de pipeline (§10.4): change verified SEM spec-delta.yaml autorado (ausente ou ainda
  # com placeholders de scaffold/template). A fase verify passou a gerar o esqueleto e autorar
  # os payloads — verified sem delta é retrabalho garantido na sessão de archive. Informativo
  # (`·`) como os demais checks de estado de fluxo do operador — o enforcement duro fica no
  # pré-flight do archive (validate-archive recusa placeholders).
  if [ -d "$ROOT/.forge/specs/active" ]; then
    for chdir in "$ROOT"/.forge/specs/active/*/; do
      [ -f "$chdir/manifest.yaml" ] || continue
      chstatus="$(awk -F': ' '$1=="status"{print $2; exit}' "$chdir/manifest.yaml")"
      [ "$chstatus" = "verified" ] || continue
      chid="$(basename "$chdir")"
      if [ ! -f "$chdir/spec-delta.yaml" ]; then
        info "harness: drift — change '$chid' verified sem spec-delta.yaml (gere na fase verify: /forge:verify §2.5, ou autore à mão antes do /forge:archive)"
      # cópia bash de SCAFFOLD_MARKERS_RE (canônico: lib/scaffold-markers.mjs) — manter em sincronia
      elif grep -qE '<scaffold:|<capability-kebab>|REQ-XXX-' "$chdir/spec-delta.yaml"; then
        info "harness: drift — change '$chid' verified com spec-delta.yaml ainda em placeholder (preencha os payloads — /forge:verify §2.5; o archive recusa scaffold)"
      fi
    done
  fi

  # red-first (rule testing/regression-red-first.md): change type:bugfix ativo cuja evidência
  # de Red ainda não está observed/waived. Advisory puro, igual ao bloco do ledger acima —
  # NUNCA seta MISSING_DIAG (o enforcement real e bloqueante é o validate-spec.mjs na
  # transição para verified, e o check-red-first.sh no pré-flight do archive).
  if [ -d "$ROOT/.forge/specs/active" ] && command -v node >/dev/null 2>&1 \
     && [ -f "$ROOT/.forge/scripts/lib/check-red-first.mjs" ]; then
    red_pending=""
    for chdir in "$ROOT"/.forge/specs/active/*/; do
      [ -f "$chdir/manifest.yaml" ] || continue
      chtype="$(awk -F': ' '$1=="type"{print $2; exit}' "$chdir/manifest.yaml")"
      [ "$chtype" = "bugfix" ] || continue
      chid="$(basename "$chdir")"
      st="$(FORGE_ROOT="$ROOT" node "$ROOT/.forge/scripts/lib/check-red-first.mjs" status "$chdir" 2>/dev/null || echo "")"
      case "$st" in
        OK*) ;;
        "") ;;
        *) red_pending="${red_pending:+$red_pending, }$chid ($st)" ;;
      esac
    done
    if [ -n "$red_pending" ]; then
      info "harness: red-first — evidência pendente: $red_pending"
      hint "grave a observação (/forge:red record) ou dispense (check-red-first.sh waive <id> --reason <r>)"
    else
      ok "harness: red-first sem evidência pendente"
    fi
  fi

  # core.hooksPath — config LOCAL e não versionada: some num clone novo, some num runner de CI, e
  # some numa máquina nova. Um valor errado desativa TODOS os hooks do Forge em silêncio, e a única
  # evidência disso é o commit proibido passando. Precisa ser ABSOLUTO e apontar para os hooks do
  # CHECKOUT PRINCIPAL: um valor relativo é resolvido por cada worktree contra a PRÓPRIA árvore,
  # que carrega a cópia antiga dos hooks daquela branch — hook novo, mergeado, não bloqueia nada
  # onde o trabalho acontece.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    hp_common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    case "$hp_common" in
      /*) hp_main="$(dirname "$hp_common")" ;;
      *)  hp_main="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")" ;;
    esac
    hp_want="$hp_main/.forge/hooks/git"
    hp_cur="$(git config --get core.hooksPath 2>/dev/null || true)"
    if [ "$hp_cur" = "$hp_want" ]; then
      ok "harness: core.hooksPath -> hooks do tronco (absoluto)"
    elif [ -z "$hp_cur" ]; then
      # Sem hooks instalados não há o que apontar; com hooks instalados e ninguém apontando, o
      # harness está inerte e isso é defeito.
      if [ -d "$hp_want" ]; then
        miss "harness: core.hooksPath não configurado — os hooks em $hp_want existem e nenhum deles roda"
        hint "corrija com: npx forge-harness update   (ou git config core.hooksPath '$hp_want')"
        MISSING_DIAG=1
      else
        info "harness: core.hooksPath não configurado (nenhum hook do Forge instalado neste checkout)"
      fi
    elif [ ! -d "$hp_cur" ]; then
      miss "harness: core.hooksPath aponta para '$hp_cur', que não existe — nenhum hook roda"
      hint "corrija com: npx forge-harness update   (ou git config core.hooksPath '$hp_want')"
      MISSING_DIAG=1
    elif [ "$hp_cur" = ".forge/hooks/git" ]; then
      miss "harness: core.hooksPath relativo ('.forge/hooks/git') — cada worktree resolve na própria árvore e roda a cópia antiga dos hooks"
      hint "corrija com: npx forge-harness update   (grava o caminho absoluto do tronco)"
      MISSING_DIAG=1
    else
      info "harness: core.hooksPath customizado ('$hp_cur') — os hooks do Forge não estão ativos"
      hint "encadeie .forge/hooks/git/* no seu hook customizado se quiser os gates do Forge"
    fi

    # Divergência de maquinaria por worktree. Maquinaria versionada dentro da árvore não se
    # propaga sozinha: um script, uma rule ou um schema corrigidos no tronco continuam sendo a
    # versão antiga em todo worktree ativo, e quem trabalha ali recebe verde de um gate que não
    # está rodando. Medido em axis-go-cloud: cinco de oito worktrees com 86 a 103 arquivos
    # divergentes. Informativo, nunca reprova — sincronizar é decisão de quem tem o contexto da
    # branch, e um worktree legitimamente à frente do tronco também aparece aqui.
    wt_head="$(git -C "$hp_main" rev-parse HEAD 2>/dev/null || true)"
    if [ -n "$wt_head" ]; then
      git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}' | while IFS= read -r wt; do
        [ -n "$wt" ] || continue
        [ "$wt" = "$hp_main" ] && continue
        wt_sha="$(git -C "$wt" rev-parse HEAD 2>/dev/null || true)"
        [ -n "$wt_sha" ] || continue
        n="$(git -C "$hp_main" diff --name-only "$wt_sha" "$wt_head" -- \
               .forge/scripts .forge/rules .forge/schemas .forge/templates .forge/hooks .forge/agents 2>/dev/null | wc -l | tr -d ' ')"
        [ "${n:-0}" -gt 0 ] || continue
        ahead="$(git -C "$hp_main" rev-list --count "$wt_head..$wt_sha" 2>/dev/null || echo '?')"
        printf "  %s·%s %s\n" "$YEL" "$RST" "harness: worktree $(basename "$wt") com $n arquivo(s) de maquinaria divergentes do tronco ($ahead commit(s) à frente)"
      done
    fi
  fi

  # plugin /forge:* instalado no Claude Code (best-effort; puramente informativo — NUNCA
  # contribui para MISSING_DIAG/exit 1). Sintoma real que motivou o check: usuário colando o
  # CORPO dos comandos como texto porque /forge:* silenciosamente não existia (plugin nunca
  # instalado, ou desabilitado) — e isso é estado GLOBAL do Claude Code do operador, não do
  # projeto, então não pode reprovar doctor/CI (a mesma máquina roda doctor contra fixtures de
  # teste que nada têm a ver com o plugin global instalado).
  if have claude; then
    plugin_ok=0
    if claude plugin list 2>/dev/null | grep -qi 'forge'; then
      plugin_ok=1
    elif [ -d "$HOME/.claude/plugins" ] && grep -rlq '"forge@' "$HOME/.claude/plugins" 2>/dev/null; then
      plugin_ok=1
    elif [ -f "$HOME/.claude/settings.json" ] && grep -q '"forge@' "$HOME/.claude/settings.json" 2>/dev/null; then
      plugin_ok=1
    fi
    if [ "$plugin_ok" -eq 1 ]; then
      ok "harness: plugin /forge:* instalado no Claude Code"
    else
      info "harness: plugin /forge:* não detectado no Claude Code (verificação global, best-effort)"
      hint "instale/repare com: npx forge-harness install-plugin"
    fi
  else
    info "harness: CLI 'claude' não encontrada — check de plugin /forge:* pulado (best-effort)"
  fi
  echo
}
check_harness

DETECTED=""

[ -n "$(find_marker '*.sln')$(find_marker '*.csproj')" ] && DETECTED="$DETECTED dotnet"
{ [ -f package.json ] || [ -f tsconfig.json ] || [ -n "$(find_marker tsconfig.json)" ]; } && DETECTED="$DETECTED node"
{ [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; } && DETECTED="$DETECTED python"
[ -n "$(find_marker 'pom.xml')$(find_marker '*.java')" ] && DETECTED="$DETECTED java"
[ -n "$(find_marker 'build.gradle')$(find_marker 'build.gradle.kts')" ] && DETECTED="$DETECTED kotlin"

if [ -z "$DETECTED" ]; then
  echo "Nenhuma stack reconhecida no repositório (.NET / Node-TS / Python / Kotlin)."
  if [ "$MISSING_DIAG" -eq 1 ]; then
    echo "${RED}Problemas no harness Forge detectados (ver acima).${RST}"
    exit 1
  fi
  echo "Nada a verificar."
  exit 0
fi

echo "Stacks detectadas:${DETECTED}"
echo "Modo: $( [ "$INSTALL" -eq 1 ] && echo 'reportar + instalar (--install)' || echo 'somente reportar' )"
echo

# Capability packs são sugestão explícita, nunca ativação automática. A ativação é uma decisão
# de arquitetura registrada no forge.yaml e os packs só orientam a área onde são aplicáveis.
suggest_pack() {
  local pack="$1"
  if grep -Eq "^[[:space:]]*active:.*${pack}" "$ROOT/.forge/forge.yaml" 2>/dev/null; then
    ok "capability pack ativo: $pack"
  elif [ -f "$ROOT/.forge/capabilities/$pack/PROFILE.md" ]; then
    info "capability pack sugerido: $pack (opt-in)"
    hint "registre em .forge/forge.yaml: capabilities.active: [$pack]"
  fi
}
for stack in $DETECTED; do
  case "$stack" in
    dotnet) suggest_pack backend-dotnet-relational ;;
    node) suggest_pack backend-node-postgres ;;
    java) suggest_pack backend-java-relational ;;
    python) suggest_pack backend-python-relational ;;
  esac
done
echo

# try_install <descrição> <comando-de-instalação...>
try_install() {
  local desc="$1"; shift
  if [ "$INSTALL" -eq 0 ]; then
    hint "instalar: $*"
    return 1
  fi
  echo "      ${DIM}instalando ($desc): $*${RST}"
  if "$@"; then ok "instalado: $desc"; return 0; else miss "falha ao instalar: $desc"; return 1; fi
}

# ── .NET ─────────────────────────────────────────────────────────────────────
check_dotnet() {
  echo ".NET"
  if have dotnet; then
    ok "diagnóstico: dotnet build / dotnet format ($(dotnet --version 2>/dev/null))"
  else
    miss "diagnóstico: dotnet SDK ausente (load-bearing — compilação/format)"
    MISSING_DIAG=1
    hint "instale o .NET SDK: https://dotnet.microsoft.com/download (ou: brew install --cask dotnet-sdk)"
  fi
  # LSP (opcional, informativo)
  if have csharp-ls || have omnisharp; then ok "lsp: csharp-ls/omnisharp presente"
  else info "lsp: csharp-ls/OmniSharp ausente (opcional — VS Code C# Dev Kit já provê)"
       try_install "csharp-ls" dotnet tool install -g csharp-ls || true
  fi
}

# ── Node / TypeScript ─────────────────────────────────────────────────────────
check_node() {
  echo "Node / TypeScript"
  # tsc: preferir o local do projeto; aceitar global
  if npx --no-install tsc --version >/dev/null 2>&1 || have tsc; then
    ok "diagnóstico: tsc (typescript) disponível"
  else
    miss "diagnóstico: tsc (typescript) ausente (load-bearing — typecheck)"
    MISSING_DIAG=1
    try_install "typescript" npm install -g typescript || true
  fi
  if npx --no-install eslint --version >/dev/null 2>&1 || have eslint; then
    ok "diagnóstico: eslint disponível"
  else
    info "diagnóstico: eslint ausente (recomendado)"
    try_install "eslint" npm install -g eslint || true
  fi
  if have typescript-language-server; then ok "lsp: typescript-language-server presente"
  else info "lsp: typescript-language-server ausente (opcional)"
       try_install "typescript-language-server" npm install -g typescript-language-server || true
  fi
}

# ── Python ────────────────────────────────────────────────────────────────────
check_python() {
  echo "Python"
  if have pyright || have mypy; then
    ok "diagnóstico: $(have pyright && echo pyright || echo mypy) disponível"
  else
    miss "diagnóstico: pyright/mypy ausente (load-bearing — typecheck)"
    MISSING_DIAG=1
    if have pipx; then try_install "pyright" pipx install pyright || true
    else hint "instale pipx e: pipx install pyright (ou npm install -g pyright)"; fi
  fi
  if have ruff; then ok "diagnóstico: ruff disponível"
  else info "diagnóstico: ruff ausente (recomendado)"
       if have pipx; then try_install "ruff" pipx install ruff || true; else hint "pipx install ruff"; fi
  fi
  # pyright já serve como LSP; python-lsp-server é alternativa
  if have pyright || have pylsp; then ok "lsp: pyright/pylsp presente"
  else info "lsp: pyright/python-lsp-server ausente (opcional)"; fi
}

# ── Java ──────────────────────────────────────────────────────────────────────
check_java() {
  echo "Java"
  if have java && { have mvn || [ -x ./mvnw ] || have gradle || [ -x ./gradlew ]; }; then
    ok "diagnóstico: Java + build tool disponíveis"
  else
    miss "diagnóstico: Java ou Maven/Gradle ausente (load-bearing — build/test)"
    MISSING_DIAG=1
    hint "instale JDK LTS e use mvnw/gradlew do projeto quando disponíveis"
  fi
  if have java-language-server || have jdtls; then ok "lsp: java-language-server/jdtls presente"
  else info "lsp: java-language-server/jdtls ausente (opcional)"; fi
}

# ── Kotlin / JVM ───────────────────────────────────────────────────────────────
check_kotlin() {
  echo "Kotlin / JVM"
  if [ -x ./gradlew ] || have gradle; then
    ok "diagnóstico: gradle ($( [ -x ./gradlew ] && echo './gradlew' || echo 'gradle' ) compileKotlin)"
  else
    miss "diagnóstico: gradle/gradlew ausente (load-bearing — compileKotlin)"
    MISSING_DIAG=1
    hint "use o wrapper ./gradlew do projeto, ou: brew install gradle"
  fi
  if have ktlint || have detekt; then ok "diagnóstico: ktlint/detekt presente"
  else info "diagnóstico: ktlint/detekt ausente (recomendado)"
       if command -v brew >/dev/null 2>&1; then try_install "ktlint" brew install ktlint || true
       else hint "brew install ktlint (ou via gradle plugin)"; fi
  fi
  if have kotlin-language-server; then ok "lsp: kotlin-language-server presente"
  else info "lsp: kotlin-language-server ausente (opcional)"
       if command -v brew >/dev/null 2>&1; then try_install "kotlin-language-server" brew install kotlin-language-server || true
       else hint "brew install kotlin-language-server"; fi
  fi
}

for stack in $DETECTED; do
  case "$stack" in
    dotnet) check_dotnet ;;
    node)   check_node ;;
    python) check_python ;;
    java)   check_java ;;
    kotlin) check_kotlin ;;
  esac
  echo
done

if [ "$MISSING_DIAG" -eq 1 ] && [ "$INSTALL" -eq 0 ]; then
  echo "${RED}Diagnóstico(s) load-bearing ausente(s).${RST} Rode com --install ou instale manualmente (ver dicas acima)."
  exit 1
fi

echo "${GREEN}OK${RST} — diagnósticos das stacks detectadas disponíveis."
exit 0
