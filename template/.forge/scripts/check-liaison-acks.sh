#!/usr/bin/env bash
# check-liaison-acks.sh — cobra os acks que ESTE repositório deve, e só eles.
#
# Um `contract-change` que chega com `requires_ack` é um fato sobre contrato que alguém precisa
# reconhecer. Sem cobrança, a mensagem vira exatamente o handoff manual que o liaison existe para
# substituir: chega, ninguém lê, e o contrato deriva. Com cobrança, o drift trava o push.
#
# TRÊS REGRAS QUE DEFINEM O ESCOPO DA COBRANÇA, e o porquê de cada uma:
#
#   1. Cada participante responde pelo PRÓPRIO ack, nunca pelo dos outros. Com N repositórios,
#      exigir o ack de todos faria o participante mais lento travar o trabalho de todo mundo — e o
#      ack de terceiro não é informação que este repositório possa produzir, então seria uma trava
#      que o bloqueado não tem como abrir.
#   2. Só cobra quem PARTICIPA da thread. A lista de participantes roteia; um contract-change numa
#      thread da qual não faço parte é contexto, não obrigação.
#   3. Nunca cobra o que este repositório mesmo enviou. Ackar a própria mensagem não informa nada
#      a ninguém.
#
# Modo `warn` (default) avisa e devolve 0; `block` devolve 1 citando os msg_id pendentes. A leitura
# do modo vem do forge.yaml — e um `enforce` ausente é tratado como `warn`, porque a ausência de
# configuração não pode ser mais severa que a configuração explícita mais branda.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Mesmo ROOT de liaison-ops.sh: o canal do liaison é estado durável de PROJETO e mora no tronco
# (rule conventions/machinery-propagation.md). Um leitor que resolvesse pelo `--show-toplevel`
# ficaria cego justamente para quem trabalha numa branch — leria a cópia congelada do worktree e
# devolveria "nenhum ack pendente" para uma dívida que existe.
_forge_main_root() {
  local common
  common="$(git -C "$(pwd)" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  case "$common" in /*) : ;; *) return 1 ;; esac
  dirname "$common"
}
ROOT="${FORGE_ROOT:-$(_forge_main_root || git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)}"
LIBDIR="$SCRIPT_DIR/lib"
LIAISON_DIR="$ROOT/.forge/liaison"
CONFIG="$LIAISON_DIR/liaison.yaml"
FORGE_YAML="$ROOT/.forge/forge.yaml"

# Sem canal, nada a cobrar — e nada a reprovar: um repositório que não usa liaison não pode ser
# penalizado por um subsistema que não adotou.
[ -d "$LIAISON_DIR" ] || { echo "OK liaison-acks — sem canal"; exit 0; }
[ -f "$CONFIG" ] || { echo "OK liaison-acks — sem canal"; exit 0; }

# enforce: warn|block (awk portável, mesmo idioma do _yaml_auto do hook de sessão)
mode="warn"
if [ -f "$FORGE_YAML" ]; then
  found="$(awk '
    $0 ~ /^liaison:/ { inblk=1; next }
    inblk && /^[a-z_]+:/ { exit }
    inblk && /^[ ]+enforce:[ ]*(warn|block)/ { sub(/^[ ]+enforce:[ ]*/, ""); print; exit }
  ' "$FORGE_YAML")"
  [ -n "$found" ] && mode="$found"
fi

# ── procedência (issue #51) ──────────────────────────────────────────────────────────────────────
# `trust` era o único campo do envelope que nenhum instrumento verificava. content_sha o exclui por
# desenho (varia legitimamente entre cópias da mesma mensagem), então verificação por hash é
# estruturalmente cega a ele — e uma restauração de log truncado que copiou a réplica de um peer
# sobre o log próprio fez 172 mensagens PRÓPRIAS se declararem `untrusted-peer` sem que nada
# reprovasse. A invariante é derivável de fato observável, não declarada: em `log/<self>.jsonl` toda
# mensagem é `self` (salvo as de autoria externa, que carregam `authored_by`), e em `log/<outro>.jsonl`
# nenhuma é. Ver lib/liaison-trust.mjs.
#
# Reprova SEMPRE, independente de `enforce: warn|block`: aquele modo gradua uma dívida social (o ack
# que este repositório deve a alguém), e esta é outra classe — o log em disco está afirmando uma
# procedência que os próprios arquivos desmentem, e publicar isso propaga a inversão para os peers.
trust_report="$(node - "$LIBDIR" "$LIAISON_DIR" "$CONFIG" <<'NODEEOF'
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, liaisonDir, cfg] = process.argv;
  const T = await import(pathToFileURL(join(lib, 'liaison-trust.mjs')).href);
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const self = (C.readConfig(cfg).self || {}).id;
  // Sem self não há de onde derivar procedência. Quantas mensagens ficaram sem verificação é o que
  // decide o veredito do chamador: sair calado aqui empataria "não verifiquei" com "está coerente".
  if (!self) { process.stdout.write(`SKIP ${T.countMessages(liaisonDir)}`); return; }
  const { scanned, violations } = T.verifyAll(liaisonDir, self);
  if (!violations.length) { process.stdout.write(`OK ${scanned}`); return; }
  process.stdout.write([`BAD ${scanned}`, ...violations.map(T.formatViolation)].join('\n'));
})();
NODEEOF
)" || { echo "FAIL liaison-trust — a verificação de procedência não pôde ser executada" >&2; exit 1; }

TRUST_OK=""
case "$trust_report" in
  BAD*)
    n_bad="$(printf '%s\n' "$trust_report" | tail -n +2 | grep -c . || true)"
    echo "FAIL liaison-trust — $n_bad mensagem(ns) declaram procedência que os próprios arquivos do canal desmentem:" >&2
    printf '%s\n' "$trust_report" | tail -n +2 | sed 's/^/  /' >&2
    echo "  Nenhum content_sha detecta isto: o campo é excluído do hash por desenho, porque varia entre cópias." >&2
    echo "  Causa típica: cópia manual, restauração de backup ou merge que trouxe o log de um peer para cima do próprio." >&2
    echo "  Restaure o arquivo apontado a partir do histórico do repositório — corrigir o campo à mão esconde a cópia errada." >&2
    exit 1
    ;;
  OK*) TRUST_OK="OK liaison-trust — ${trust_report#OK } mensagem(ns) com procedência coerente" ;;
  SKIP*)
    # Store com mensagens e sem `self` não é estado legítimo — `send` e `import` exigem o campo, então
    # ele só chegou ali por edição, restauração ou merge do liaison.yaml. Deixar passar entregaria um
    # push cujo store inteiro ficou sem verificação, e o sinal disso seria a AUSÊNCIA de uma linha.
    n_skip="${trust_report#SKIP }"
    if [ "${n_skip:-0}" -gt 0 ]; then
      echo "FAIL liaison-trust — ${n_skip} mensagem(ns) no store e nenhuma verificada: '$CONFIG' não declara self.id," >&2
      echo "  e a procedência é derivada dele. Restaure o bloco 'self:' do liaison.yaml a partir do histórico." >&2
      exit 1
    fi
    TRUST_OK="OK liaison-trust — store vazio, nada a verificar"
    ;;
  *)
    # Nem OK, nem BAD, nem SKIP: a verificação devolveu algo que este script não sabe ler. Aceitar em
    # silêncio seria o mesmo defeito, uma camada acima.
    echo "FAIL liaison-trust — a verificação devolveu resposta que não sei ler: '$trust_report'" >&2
    exit 1
    ;;
esac

pending="$(node - "$LIBDIR" "$LIAISON_DIR" "$CONFIG" <<'NODEEOF'
const { readFileSync, readdirSync, existsSync } = require('fs');
const { join } = require('path');
const { pathToFileURL } = require('url');
(async () => {
  const [, , lib, liaisonDir, cfg] = process.argv;
  const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
  const C = await import(pathToFileURL(join(lib, 'liaison-config.mjs')).href);
  const self = (C.readConfig(cfg).self || {}).id;
  if (!self) return;

  const out = [];
  // Contador de controle da issue 49, instância 1: quantas threads DESTE repositório a cobrança
  // examinou. Sem ele, "não participo de thread nenhuma" e "participo de nove e nenhuma me deve
  // ack" terminam na mesma linha, e cobertura fica indistinguível de ausência de cobertura.
  // ATENÇÃO ao editar: este bloco vive dentro de $( ) do shell, e ali o bash trata um sustenido
  // como início de comentário — ele engole o resto da linha, inclusive um parêntese de
  // fechamento ou uma crase, e o script morre com "bad substitution". Sem sustenido aqui.
  let scanned = 0;
  const channels = existsSync(liaisonDir)
    ? readdirSync(liaisonDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort()
    : [];

  for (const channel of channels) {
    const logDir = join(liaisonDir, channel, 'log');
    if (!existsSync(logDir)) continue;
    const all = [];
    for (const f of readdirSync(logDir).filter((n) => n.endsWith('.jsonl')).sort()) {
      for (const line of readFileSync(join(logDir, f), 'utf8').split('\n')) {
        const t = line.trim();
        if (t) { try { all.push(JSON.parse(t)); } catch { /* linha corrompida: o doctor sinaliza */ } }
      }
    }
    const { threads } = M.mergeLogs(all);

    for (const [threadId, t] of Object.entries(threads)) {
      // regra 2: só cobra thread da qual este repositório participa
      if (!t.participants.includes(self)) continue;
      scanned += 1;
      // acks que ESTE repositório emitiu, por mensagem alvo (regra 1)
      const ackedByMe = new Set(
        t.messages.filter((m) => m.kind === 'ack' && m.sender === self && m.in_reply_to).map((m) => m.in_reply_to),
      );
      for (const m of t.messages) {
        if (!m.requires_ack) continue;            // nada a cobrar
        if (m.sender === self) continue;          // regra 3: nunca a própria mensagem
        if (ackedByMe.has(m.msg_id)) continue;    // já reconhecido por mim
        out.push(`${channel}/${threadId}: ${m.msg_id} [${m.kind}] de ${m.sender} — ${m.subject || '(sem assunto)'}`);
      }
    }
  }
  // Primeira linha SEMPRE, mesmo sem pendência: é ela que separa "examinei N threads e nenhuma me
  // deve ack" de "não examinei thread nenhuma".
  // Marcador sem sustenido e sem template literal, pelo mesmo motivo descrito acima.
  process.stdout.write(['SCOPE ' + scanned].concat(out).join('\n'));
})();
NODEEOF
)"

# Separa o contador de controle (primeira linha) da lista de pendências. `self` ausente faz o node
# devolver saída vazia — e aí não há escopo a declarar, porque não há de onde saber o que é "meu".
# `head`/`tail` e não `${var%%$'\n'*}`: o bash 3.2 do macOS não expande `$'...'` dentro de
# expansão de parâmetro, e o script inteiro morre com "bad substitution" (rule shell-portability).
scanned_threads=""
case "$pending" in
  'SCOPE '*)
    scanned_threads="$(printf '%s\n' "$pending" | head -1)"
    scanned_threads="${scanned_threads#SCOPE }"
    pending="$(printf '%s\n' "$pending" | tail -n +2)"
    ;;
esac

if [ -z "$pending" ]; then
  if [ -n "$scanned_threads" ]; then
    echo "OK liaison-acks — $scanned_threads thread(s) deste repositório examinada(s), nenhum ack pendente"
  else
    echo "OK liaison-acks — nenhum ack pendente deste repositório"
  fi
  [ -z "$TRUST_OK" ] || echo "$TRUST_OK"
  exit 0
fi

n="$(printf '%s\n' "$pending" | grep -c . || true)"
if [ "$mode" = "block" ]; then
  echo "FAIL liaison-acks — $scanned_threads thread(s) examinada(s), $n mensagem(ns) exigem ack deste repositório (enforce: block):" >&2
  printf '%s\n' "$pending" | sed 's/^/  /' >&2
  echo "  Reconheça com: liaison-ops.sh ack <canal> <msg_id>" >&2
  echo "  Se a decisão é NÃO adotar, use --reason wont-adopt: acka e registra a dívida no ledger," >&2
  echo "  porque recusa registrada é informação e recusa silenciosa é o drift que o canal combate." >&2
  [ -z "$TRUST_OK" ] || echo "$TRUST_OK"
  exit 1
fi

echo "WARN liaison-acks — $scanned_threads thread(s) examinada(s), $n mensagem(ns) exigem ack deste repositório (enforce: warn, não bloqueia):"
printf '%s\n' "$pending" | sed 's/^/  /'
[ -z "$TRUST_OK" ] || echo "$TRUST_OK"
exit 0
