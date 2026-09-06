#!/usr/bin/env bash
# ledger-ops.sh — operações deterministas no ledger durável de projeto (.forge/ledger/ledger.json).
# Store NÃO-BLOQUEANTE de trabalho conhecido que sobrevive entre changes (roadmap, dívida técnica,
# bugs conhecidos, follow-ups, ideias). Toda mutação re-renderiza LEDGER.md. Ver schema em
# .forge/schemas/ledger.schema.json e rule ledger-consultation.md.
#
# Uso:
#   ledger-ops.sh add     --type <t> --title "<txt>" [--detail "<txt>"] [--severity S] [--priority P]
#                         [--status ST] [--origin O] [--change <id>] [--ref R] [--adr A] [--capability C]
#   ledger-ops.sh update  <LDG-NNNN> [--status ST] [--priority P] [--severity S] [--title "<txt>"] [--detail "<txt>"]
#   ledger-ops.sh resolve <LDG-NNNN> --note "<txt>" [--status resolved|wont-fix]   # default: resolved
#   ledger-ops.sh promote <LDG-NNNN> --to <change-id>
#   ledger-ops.sh harvest <change-id> --origin close|archive   # colhe deferrals/findings antes do mv
#   ledger-ops.sh render                                        # regenera LEDGER.md
#   ledger-ops.sh status                                        # one-line (para /forge:status)
#   ledger-ops.sh list    [--status S] [--type T] [--top N] [--by-priority]
#
# Determinístico: created_at = data do commit HEAD (não wall clock); harvest é idempotente (dedup_key)
# e best-effort (NUNCA falha o caller). Ver deferral-ops.sh / handoff-gen.sh para os idiomas.
#
# resolved_at (issue #78): 'add --status resolved' e 'update --status resolved' são RECUSADOS de
# propósito — são as duas portas que quem quer marcar estado natural digita primeiro ("quero mudar
# o status" -> update; "estou registrando algo que já acabou" -> add), e as duas deixavam
# resolved_at nulo em silêncio porque só o 'resolve' o carimbava. Medido: 45/143 entradas resolvidas
# sem resolved_at num consumidor, crescendo entre medições (39/135 -> 42/138 -> 45/143); 11/59 no
# próprio harness. A alternativa cogitada — carimbar resolved_at também em add/update — foi
# descartada porque manteria DUAS fontes de verdade para o mesmo carimbo (drift já provou não ser
# hipotético) e deixaria 'resolved' sem exigir motivo (o 'resolve' já exige --note; add/update não
# pedem justificativa nenhuma para encerrar algo). Recusar e apontar para 'resolve' fecha a porta
# errada em vez de tentar consertar as duas entradas por ela. 'wont-fix' tem o mesmo defeito na
# prática — hoje só nasce via 'update --status wont-fix', sem carimbo e sem nota — então entra na
# mesma recusa; 'resolve' passa a aceitar '--status wont-fix' como a porta certa para os dois
# desfechos terminais. 'promoted' NÃO tem esse problema: o item promovido ainda não foi resolvido,
# está sob rastreio de um change ativo (ver ledger-consultation.md) — carimbar resolved_at nele
# seria afirmar algo falso. Ele só ganha resolved_at de fato quando o change que o promoveu chega a
# archive/close-delivered-externally, e aí passa pelo 'resolve' como qualquer outro.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Disciplina de parsing (issue #103): flag desconhecida REPROVA e valor vazio REPROVA. Delegação
# em alvo ausente é erro, nunca silêncio — o mesmo idioma que os hooks já aplicam aos check-*.sh:
# se a lib sumiu, o script não segue rodando sem as guardas que ele afirma ter.
if [ -f "$SCRIPT_DIR/lib/arg-guards.sh" ]; then
  # shellcheck source=lib/arg-guards.sh
  . "$SCRIPT_DIR/lib/arg-guards.sh"
else
  echo "FAIL: ledger-ops: '$SCRIPT_DIR/lib/arg-guards.sh' ausente — as guardas de flag desconhecida e de valor vazio são parte do contrato deste script; rodar sem elas reinstala a escrita silenciosa que a issue #103 fechou." >&2
  exit 1
fi
_reject_unknown() { forge_reject_unknown "$@"; }
_require_value() { forge_require_value "$@"; }

# ROOT é o CHECKOUT PRINCIPAL, nunca o worktree de onde o script foi chamado. O ledger é artefato
# durável de PROJETO, não de branch: resolvido por `--show-toplevel`, um registro feito de dentro
# de um worktree nasce no ledger.json daquela branch, e toda branch que toca o ledger passa a
# colidir por construção no merge. Medido em axis-go-cloud (cinco reconciliações num único dia) e
# em axis-fare-validator (dez entradas presas numa branch de feature, duas delas normas de
# processo, invisíveis para o resto do repositório até o PR mergear).
#
# `--git-common-dir` devolve o `.git` compartilhado por TODOS os worktrees; o diretório que o
# contém é o tronco. `--path-format=absolute` é necessário porque, no próprio checkout principal,
# `--git-common-dir` devolveria `.git` relativo — e `dirname .git` daria `.`, que é justamente o
# worktree corrente que se quer evitar. O mesmo idioma já é usado em hooks/git/pre-commit.
# Resolução do checkout principal e o aviso de divergência vivem em lib/forge-root.sh — UM sítio,
# consumido pelos quatro scripts que antes carregavam este corpo copiado (LDG-0068). Delegação em
# alvo ausente é erro: sem a lib, o script não segue resolvendo ROOT por conta própria.
if [ -f "$SCRIPT_DIR/lib/forge-root.sh" ]; then
  # shellcheck source=lib/forge-root.sh
  . "$SCRIPT_DIR/lib/forge-root.sh"
else
  echo "FAIL: $SCRIPT_DIR/lib/forge-root.sh ausente — é a resolução única do checkout principal; sem ela o script gravaria estado durável num lugar que ninguém declarou." >&2
  exit 1
fi
ROOT="$(forge_resolve_root)"
LEDGER_DIR="$ROOT/.forge/ledger"
LF="$LEDGER_DIR/ledger.json"
TPL="$(cd "$SCRIPT_DIR/.." && pwd)/templates/ledger/LEDGER.md"
OUT="$LEDGER_DIR/LEDGER.md"

cmd="${1:-}"; shift || true
[ -n "$cmd" ] || { echo "Usage: ledger-ops.sh add|update|resolve|promote|harvest|render|status|list [args...]" >&2; exit 1; }

_git_date() { git -C "$ROOT" log -1 --format=%cI 2>/dev/null || echo ""; }
# _require_git_date — busca a data e RECUSA no caller se vier vazia (fora de git, ou git sem
# nenhum commit ainda). NUNCA chamar `_git_date` diretamente dentro de `"$(...)"` aninhado num
# comando maior (ex.: argumento de `node - ... "$(_git_date)"`): um `exit` disparado ali dentro só
# mata o subshell da substituição, o valor vazio segue para o comando de fora, e a recusa nunca
# acontece — foi exatamente assim que 'resolve' (a porta que esta issue corrigiu) carimbava
# resolved_at="" com rc=0 sob FORGE_ROOT apontando para um diretório sem commit algum. Por isso
# esta função grava o resultado numa variável no shell PRINCIPAL antes de decidir. Fecha fechado
# em vez de cair para wall clock em silêncio, porque o cabeçalho promete "created_at = data do
# commit HEAD, não wall clock" — silenciosamente trocar a fonte quebraria essa promessa sem avisar
# ninguém, e diretório sem commit é raro e trivial de sair (um commit resolve).
_require_git_date() {
  local d
  d="$(_git_date)"
  if [ -z "$d" ]; then
    echo "FAIL: ledger-ops: sem data de commit HEAD em '$ROOT' — fora de um repositório git, ou repositório git sem nenhum commit ainda. O ledger não carimba por relógio de parede (contradiria 'created_at = data do commit HEAD, não wall clock'). Faça um commit no projeto (mesmo 'git commit --allow-empty -m init') e tente de novo." >&2
    exit 1
  fi
  GIT_DATE_NOW="$d"
}
_write_json() { local f="$1"; local tmp; tmp="$(mktemp "${f}.XXXXXX")"; printf '%s\n' "$2" > "$tmp"; mv "$tmp" "$f"; }
_init_ledger() { mkdir -p "$LEDGER_DIR"; [ -f "$LF" ] || _write_json "$LF" '{"entries":[]}'; }
_render() {
  [ -f "$TPL" ] || { echo "WARN: template ausente ($TPL) — LEDGER.md não regenerado" >&2; return 0; }
  LEDGER_ROOT="$ROOT" LEDGER_JSON="$LF" LEDGER_TPL="$TPL" LEDGER_OUT="$OUT" \
    node "$SCRIPT_DIR/lib/ledger-render.mjs"
}

# LDG-0068: as portas que ESCREVEM anunciam quando o ROOT resolvido difere do repositório de
# trabalho de quem invocou. `render`, `status` e `list` só leem e ficam de fora — aviso em porta de
# leitura é ruído que treina o operador a ignorar a linha quando ela importa.
case "$cmd" in
  add|update|resolve|promote|harvest)
    forge_warn_root_divergence "$ROOT" "ledger" "ledger-ops" ;;
esac

case "$cmd" in

add)
  type=""; title=""; detail=""; severity=""; priority=""; status="open"; origin="manual"; change=""; ref=""; adr=""; capability=""
  ADD_FLAGS="--type --title --detail --severity --priority --status --origin --change --ref --adr --capability"
  while [ $# -gt 0 ]; do case "$1" in
    --type) _require_value "add" --type "${2-}"; type="$2"; shift 2 ;;
    --title) _require_value "add" --title "${2-}"; title="$2"; shift 2 ;;
    --detail) _require_value "add" --detail "${2-}"; detail="$2"; shift 2 ;;
    --severity) _require_value "add" --severity "${2-}"; severity="$2"; shift 2 ;;
    --priority) _require_value "add" --priority "${2-}"; priority="$2"; shift 2 ;;
    --status) _require_value "add" --status "${2-}"; status="$2"; shift 2 ;;
    --origin) _require_value "add" --origin "${2-}"; origin="$2"; shift 2 ;;
    --change) _require_value "add" --change "${2-}"; change="$2"; shift 2 ;;
    --ref) _require_value "add" --ref "${2-}"; ref="$2"; shift 2 ;;
    --adr) _require_value "add" --adr "${2-}"; adr="$2"; shift 2 ;;
    --capability) _require_value "add" --capability "${2-}"; capability="$2"; shift 2 ;;
    *) _reject_unknown "add" "$ADD_FLAGS" "$1" ;;
  esac; done
  [ -n "$type" ] || { echo "FAIL: --type obrigatório (roadmap|tech-debt|known-bug|follow-up|feature-idea)" >&2; exit 1; }
  [ -n "$title" ] || { echo "FAIL: --title obrigatório" >&2; exit 1; }
  case "$status" in
    resolved|wont-fix)
      echo "FAIL: ledger-ops: 'add --status $status' não carimba resolved_at (issue #78) — registre com 'add' (nasce 'open') e feche com:" >&2
      echo "  ledger-ops.sh resolve <LDG-NNNN> --note \"<motivo>\"$([ "$status" = wont-fix ] && echo " --status wont-fix")" >&2
      exit 1
      ;;
  esac
  _require_git_date
  _init_ledger
  result="$(node - "$LF" "$type" "$title" "$detail" "$severity" "$priority" "$status" "$origin" "$change" "$ref" "$adr" "$capability" "$GIT_DATE_NOW" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, type, title, detail, severity, priority, status, origin, change, ref, adr, capability, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
if (!Array.isArray(data.entries)) data.entries = [];
const max = data.entries.reduce((m, e) => { const n = parseInt((e.id || '').replace('LDG-', ''), 10); return Number.isFinite(n) && n > m ? n : m; }, 0);
const id = 'LDG-' + String(max + 1).padStart(4, '0');
const dedup = (change && ref) ? `${change}:${ref}` : `manual:${id}`;
data.entries.push({
  id, type, title,
  detail: detail || '',
  severity: severity || null,
  priority: priority || null,
  status,
  source: { change_id: change || null, origin, ref: ref || null },
  links: { adr: adr ? [adr] : [], capability: capability ? [capability] : [], change: change ? [change] : [], promoted_to: null },
  created_at: now, updated_at: null, resolved_at: null,
  dedup_key: dedup,
});
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  new_id="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log(d.entries[d.entries.length-1].id)")"
  echo "OK add — $new_id registrado ($type)"
  # Entrada sem --detail nasce como título sem conteúdo, que é a forma de item que envelhece pior:
  # daqui a dois meses ninguém reconstrói o que ela queria dizer. AVISA, não reprova — reprovar
  # quebraria todo consumidor com script que já chama `add` sem `--detail`.
  [ -n "$detail" ] || echo "WARN: ledger-ops: $new_id nasceu SEM CONTEÚDO (nenhum --detail) — título sem detalhe é a forma de item que envelhece pior. Complete com: ledger-ops.sh update $new_id --detail \"<o que é, como medir, o que fecha>\"" >&2
  ;;

update)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  n_status=""; n_priority=""; n_severity=""; n_title=""; n_detail=""; n_flags=0
  UPDATE_FLAGS="--status --priority --severity --title --detail"
  while [ $# -gt 0 ]; do case "$1" in
    --status) _require_value "update" --status "${2-}"; n_status="$2"; n_flags=$((n_flags + 1)); shift 2 ;;
    --priority) _require_value "update" --priority "${2-}"; n_priority="$2"; n_flags=$((n_flags + 1)); shift 2 ;;
    --severity) _require_value "update" --severity "${2-}"; n_severity="$2"; n_flags=$((n_flags + 1)); shift 2 ;;
    --title) _require_value "update" --title "${2-}"; n_title="$2"; n_flags=$((n_flags + 1)); shift 2 ;;
    --detail) _require_value "update" --detail "${2-}"; n_detail="$2"; n_flags=$((n_flags + 1)); shift 2 ;;
    *) _reject_unknown "update" "$UPDATE_FLAGS" "$1" ;;
  esac; done
  [ "$n_flags" -gt 0 ] || { echo "FAIL: ledger-ops: 'update $id' sem flag alguma não tem o que gravar — o único efeito seria avançar 'updated_at', o que faz a entrada parecer recente sem carregar informação nova. Flags aceitas em 'update': $UPDATE_FLAGS" >&2; exit 1; }
  case "$n_status" in
    resolved|wont-fix)
      echo "FAIL: ledger-ops: 'update --status $n_status' não carimba resolved_at (issue #78) — use:" >&2
      echo "  ledger-ops.sh resolve $id --note \"<motivo>\"$([ "$n_status" = wont-fix ] && echo " --status wont-fix")" >&2
      exit 1
      ;;
  esac
  _require_git_date
  _init_ledger
  set +e
  result="$(node - "$LF" "$id" "$n_status" "$n_priority" "$n_severity" "$n_title" "$n_detail" "$GIT_DATE_NOW" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, st, pr, sv, ti, de, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
// Assinatura de CONTEÚDO antes e depois: `updated_at` deliberadamente fora dela. Um update cujo
// único efeito é mexer no carimbo faz a entrada parecer recente sem carregar informação nova, e
// era indistinguível de um update que gravou de fato — os dois imprimiam `OK`.
const sig = () => JSON.stringify([e.title, e.detail, e.status, e.priority, e.severity]);
const before = sig();
if (st) e.status = st;
if (pr) e.priority = pr;
if (sv) e.severity = sv;
if (ti) e.title = ti;
if (de) e.detail = de;
if (sig() === before) { console.error('NOCHANGE'); process.exit(3); }
e.updated_at = now;
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"; node_rc=$?
  set -e
  if [ "$node_rc" -eq 3 ]; then
    echo "FAIL: ledger-ops: 'update $id' não alterou nenhum campo — os valores passados já são os que a entrada carrega. Nada foi gravado (nem 'updated_at'): um update sem efeito devolvendo 'OK' é a forma pela qual um commit anuncia conteúdo que o ledger não tem." >&2
    exit 1
  fi
  [ "$node_rc" -eq 0 ] || exit "$node_rc"
  _write_json "$LF" "$result"
  _render
  echo "OK update — $id atualizado"
  ;;

resolve)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  note=""; new_status="resolved"
  RESOLVE_FLAGS="--note --status"
  while [ $# -gt 0 ]; do case "$1" in
    --note) _require_value "resolve" --note "${2-}"; note="$2"; shift 2 ;;
    --status) _require_value "resolve" --status "${2-}"; new_status="$2"; shift 2 ;;
    *) _reject_unknown "resolve" "$RESOLVE_FLAGS" "$1" ;;
  esac; done
  [ -n "$note" ] || { echo "FAIL: --note obrigatório" >&2; exit 1; }
  case "$new_status" in
    resolved|wont-fix) : ;;
    *) echo "FAIL: --status inválido para 'resolve' ('$new_status') — use 'resolved' (padrão) ou 'wont-fix'" >&2; exit 1 ;;
  esac
  _require_git_date
  _init_ledger
  result="$(node - "$LF" "$id" "$note" "$new_status" "$GIT_DATE_NOW" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, note, newStatus, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
e.status = newStatus;
e.resolved_at = now;
e.updated_at = now;
const label = newStatus === 'wont-fix' ? 'Wont-fix' : 'Resolvido';
e.detail = (e.detail ? e.detail + ' — ' : '') + label + ': ' + note;
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  echo "OK resolve — $id marcado como $new_status"
  ;;

promote)
  id="${1:-}"; shift || true
  [ -n "$id" ] || { echo "FAIL: LDG-id obrigatório" >&2; exit 1; }
  to=""
  while [ $# -gt 0 ]; do case "$1" in
    --to) _require_value "promote" --to "${2-}"; to="$2"; shift 2 ;;
    *) _reject_unknown "promote" "--to" "$1" ;;
  esac; done
  [ -n "$to" ] || { echo "FAIL: --to <change-id> obrigatório" >&2; exit 1; }
  _require_git_date
  _init_ledger
  result="$(node - "$LF" "$id" "$to" "$GIT_DATE_NOW" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, id, to, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
const e = (data.entries || []).find((x) => x.id === id);
if (!e) { console.error('entrada ' + id + ' não encontrada'); process.exit(1); }
e.status = 'promoted';
e.updated_at = now;
if (!e.links) e.links = { adr: [], capability: [], change: [], promoted_to: null };
e.links.promoted_to = to;
if (!Array.isArray(e.links.change)) e.links.change = [];
if (!e.links.change.includes(to)) e.links.change.push(to);
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  echo "OK promote — $id -> $to (status: promoted)"
  ;;

harvest)
  change_id="${1:-}"; shift || true
  [ -n "$change_id" ] || { echo "WARN: harvest sem change-id — nada colhido" >&2; exit 0; }
  origin="close"
  while [ $# -gt 0 ]; do case "$1" in
    --origin) _require_value "harvest" --origin "${2-}"; origin="$2"; shift 2 ;;
    *) _reject_unknown "harvest" "--origin" "$1" "harvest é best-effort quanto ao CONTEÚDO (change ausente devolve 0 e rc 0), nunca quanto ao USO: flag desconhecida é erro de quem chama, e engoli-la publicaria a colheita sob a origem errada." ;;
  esac; done
  spec_dir="$ROOT/.forge/specs/active/$change_id"
  # best-effort: sem pasta do change, não há o que colher — nunca falha o caller (close/archive).
  [ -d "$spec_dir" ] || { echo "OK harvest $change_id — 0 nova(s) (change não encontrado)"; exit 0; }
  now="$(_git_date)"
  # harvest NUNCA falha o caller (close/archive dependem disso) — mas gravar created_at="" seria a
  # MESMA classe de falha que esta issue existe para eliminar. Sem data de commit HEAD, degrada
  # para "0 nova(s)" honesto sobre a causa, em vez de recusar (quebraria o contrato) ou carimbar em
  # branco (reintroduziria o defeito).
  [ -n "$now" ] || { echo "OK harvest $change_id — 0 nova(s) (sem data de commit HEAD em '$ROOT' — repositório git sem nenhum commit ainda)"; exit 0; }
  _init_ledger
  before="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log((d.entries||[]).length)")"
  result="$(node - "$LF" "$change_id" "$origin" "$spec_dir" "$now" <<'NODEEOF'
const { readFileSync, existsSync } = require('fs');
const { join } = require('path');
const [, , lf, changeId, origin, specDir, now] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
if (!Array.isArray(data.entries)) data.entries = [];
const seen = new Set(data.entries.map((e) => e.dedup_key).filter(Boolean));
let max = data.entries.reduce((m, e) => { const n = parseInt((e.id || '').replace('LDG-', ''), 10); return Number.isFinite(n) && n > m ? n : m; }, 0);

const readText = (p) => { try { return readFileSync(p, 'utf8'); } catch { return ''; } };
const candidates = [];

// (1) Deferrals — JSON estruturado, o caminho mais confiável.
try {
  const dj = JSON.parse(readText(join(specDir, 'deferrals.json')) || '{}');
  for (const d of (dj.deferrals || [])) {
    if (d.status === 'open') candidates.push({ type: 'follow-up', title: d.description || d.reason || d.id, detail: d.reason || '', severity: null, ref: d.id });
    else if (d.status === 'wont-fix') candidates.push({ type: 'tech-debt', title: d.description || d.reason || d.id, detail: d.reason || '', severity: null, ref: d.id });
    // resolved/tested: tratados dentro do change — não colhe.
  }
} catch { /* best-effort */ }

// (2) analysis.md — findings MEDIUM/LOW da tabela pipe (BLOCKER/HIGH são gate-resolvidos antes).
const analysis = readText(join(specDir, 'analysis.md'));
if (analysis) {
  for (const line of analysis.split('\n')) {
    if (!line.trim().startsWith('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    const sevIdx = cells.findIndex((c) => /^(MEDIUM|LOW)$/.test(c));
    if (sevIdx < 0) continue;
    const severity = cells[sevIdx];
    const idCell = cells.slice(1, sevIdx).find((c) => c && !/^-+$/.test(c)) || '';
    const rest = cells.slice(sevIdx + 1).filter((c) => c && !/^-+$/.test(c));
    const title = (rest.join(' — ') || idCell || 'finding').slice(0, 200);
    const ref = idCell || `analysis-L${analysis.split('\n').indexOf(line) + 1}`;
    candidates.push({ type: 'tech-debt', title, detail: '', severity, ref });
  }
}

// (3) verification.md — follow-up EXPLICITAMENTE marcado. Antes (LDG-0140), qualquer bullet sob
// um heading que casasse /desvios|ressalvas|observa/i virava entrada, sem distinguir uma ressalva
// ABERTA de uma linha que apenas NARRA algo já concluído: foi assim que LDG-0111..LDG-0114
// nasceram 100% duplicadas de itens já resolvidos, para o operador do `close` desfazer à mão —
// o oposto do "não-bloqueante" que o harvest promete. É a mesma classe de LDG-0062 (heurística
// de texto sem entender semântica), e a saída é a mesma daquele item: pedir que o autor MARQUE,
// em vez de adivinhar. Duas portas de marcação, nenhuma inferida:
//   - bullet prefixado por `PENDENTE:` sob qualquer heading de ressalva; ou
//   - qualquer bullet sob um heading dedicado `Follow-ups abertos`.
// Mais um dedupe barato: bullet que cita um `LDG-00NN` entre crases já tem registro próprio.
const verification = readText(join(specDir, 'verification.md'));
if (verification) {
  const lines = verification.split('\n');
  let mode = 'none', n = 0;
  for (const line of lines) {
    if (/^#{1,6}\s/.test(line)) {
      if (/follow-?ups?\s+abertos/i.test(line)) mode = 'dedicated';
      else if (/desvios|ressalvas|observa/i.test(line)) mode = 'loose';
      else mode = 'none';
      continue;
    }
    if (mode === 'none' || !/^\s*[-*]\s+/.test(line)) continue;
    let title = line.replace(/^\s*[-*]\s+/, '').trim();
    const marked = /^(\*\*|__)?PENDENTE(\*\*|__)?\s*:/i.test(title);
    if (mode === 'loose' && !marked) continue;
    if (/`LDG-\d{4}`/.test(title)) continue;
    title = title.replace(/^(\*\*|__)?PENDENTE(\*\*|__)?\s*:\s*/i, '').trim().slice(0, 200);
    if (title) candidates.push({ type: 'follow-up', title, detail: '', severity: null, ref: `verify-${++n}` });
  }
}

for (const c of candidates) {
  const dedup = `${changeId}:${c.ref}`;
  if (seen.has(dedup)) continue;
  seen.add(dedup);
  max += 1;
  const id = 'LDG-' + String(max).padStart(4, '0');
  data.entries.push({
    id, type: c.type, title: c.title, detail: c.detail || '',
    severity: c.severity || null, priority: null, status: 'open',
    source: { change_id: changeId, origin, ref: c.ref },
    links: { adr: [], capability: [], change: [changeId], promoted_to: null },
    created_at: now, updated_at: null, resolved_at: null, dedup_key: dedup,
  });
}
console.log(JSON.stringify(data, null, 2));
NODEEOF
)"
  _write_json "$LF" "$result"
  _render
  after="$(node -e "const d=JSON.parse(require('fs').readFileSync('$LF','utf8'));console.log((d.entries||[]).length)")"
  echo "OK harvest $change_id ($origin) — $((after - before)) nova(s) entrada(s) no ledger"
  ;;

render)
  _init_ledger; _render; echo "OK $OUT"
  ;;

status)
  _init_ledger
  node - "$LF" <<'NODEEOF'
const { readFileSync } = require('fs');
const data = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const CLOSED = new Set(['resolved', 'wont-fix', 'promoted']);
const active = (data.entries || []).filter((e) => !CLOSED.has(e.status));
if (!active.length) { console.log('LEDGER: vazio'); process.exit(0); }
const by = {};
for (const e of active) by[e.type] = (by[e.type] || 0) + 1;
const hi = active.filter((e) => e.severity === 'BLOCKER' || e.severity === 'HIGH' || e.priority === 'P0' || e.priority === 'P1').length;
const parts = Object.keys(by).sort().map((t) => `${t} ${by[t]}`).join(' · ');
console.log(`LEDGER: ${active.length} ativo(s)${hi ? ` (${hi} alta prioridade)` : ''} · ${parts}`);
NODEEOF
  ;;

list)
  f_status=""; f_type=""; top=""; by_priority=""
  LIST_FLAGS="--status --type --top --by-priority"
  while [ $# -gt 0 ]; do case "$1" in
    --status) _require_value "list" --status "${2-}"; f_status="$2"; shift 2 ;;
    --type) _require_value "list" --type "${2-}"; f_type="$2"; shift 2 ;;
    --top) _require_value "list" --top "${2-}"; top="$2"; shift 2 ;;
    --by-priority) by_priority="1"; shift ;;
    *) _reject_unknown "list" "$LIST_FLAGS" "$1" ;;
  esac; done
  _init_ledger
  node - "$LF" "$f_status" "$f_type" "$top" "$by_priority" <<'NODEEOF'
const { readFileSync } = require('fs');
const [, , lf, fStatus, fType, topRaw, byPriority] = process.argv;
const data = JSON.parse(readFileSync(lf, 'utf8'));
let items = data.entries || [];
if (fStatus) items = items.filter((e) => e.status === fStatus);
if (fType) items = items.filter((e) => e.type === fType);
const PR = { P0: 0, P1: 1, P2: 2, P3: 3 };
const SV = { BLOCKER: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
const rank = (m, v) => (v != null && m[v] != null ? m[v] : 99);
if (byPriority) items = items.slice().sort((a, b) => (rank(PR, a.priority) - rank(PR, b.priority)) || (rank(SV, a.severity) - rank(SV, b.severity)) || a.id.localeCompare(b.id));
const top = parseInt(topRaw, 10);
if (Number.isFinite(top) && top > 0) items = items.slice(0, top);
if (!items.length) { console.log('(nenhuma entrada)'); process.exit(0); }
for (const e of items) {
  const tag = [e.priority, e.severity].filter(Boolean).join('/');
  console.log(`${e.id} [${e.type}/${e.status}]${tag ? ' (' + tag + ')' : ''} — ${e.title}`);
}
NODEEOF
  ;;

*)
  echo "FAIL: comando desconhecido '$cmd'" >&2; exit 1
  ;;
esac
