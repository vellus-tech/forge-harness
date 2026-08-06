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
ROOT="${FORGE_ROOT:-$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)}"
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
  process.stdout.write(out.join('\n'));
})();
NODEEOF
)"

if [ -z "$pending" ]; then
  echo "OK liaison-acks — nenhum ack pendente deste repositório"
  exit 0
fi

n="$(printf '%s\n' "$pending" | grep -c .)"
if [ "$mode" = "block" ]; then
  echo "FAIL liaison-acks — $n mensagem(ns) exigem ack deste repositório (enforce: block):" >&2
  printf '%s\n' "$pending" | sed 's/^/  /' >&2
  echo "  Reconheça com: liaison-ops.sh ack <canal> <msg_id>" >&2
  echo "  Se a decisão é NÃO adotar, use --reason wont-adopt: acka e registra a dívida no ledger," >&2
  echo "  porque recusa registrada é informação e recusa silenciosa é o drift que o canal combate." >&2
  exit 1
fi

echo "WARN liaison-acks — $n mensagem(ns) exigem ack deste repositório (enforce: warn, não bloqueia):"
printf '%s\n' "$pending" | sed 's/^/  /'
exit 0
