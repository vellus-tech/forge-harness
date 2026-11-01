# Entradas obrigatórias do design — add-liaison-native-bridge

Achados da rodada 3 do gate `requirements_reviewed` (APPROVE, 2026-10-30), que o design precisa resolver ou rejeitar com justificativa explícita. Nenhum muda requisito; todos são decisão de design.

## MINOR

1. **REQ-12, ponto do PR.** `/forge:prepare-pr` e `/forge:ship` são instrução em prosa ao modelo, sem script. Definir um detector único de mudanças de contenção (ex.: `liaison-ops.sh native containment [--range <a>..<b>]`) usado por pre-push, doctor e pelos dois comandos, com gate de texto conferindo que `prepare-pr.md` e `ship.md` (template e plugin) o invocam, e fixture medindo o detector.
2. **REQ-05, nome igual entre subagente e sessão.** Medir e fixar com fixture: destino com nome de subagente/colega que também é nome de sessão viva deve ser tratado como destino de sessão.
3. **REQ-07, resolução de nome divergente do Claude Code.** Medir qual destino o Claude Code escolhe quando o nome é único localmente mas existe também em sessão remota/nuvem; se não der para garantir o mesmo resultado, exigir endereço `uds:` sempre que o nome não for único entre os destinos do `ListAgents`.
4. **REQ-02, normalização de caminho na conferência de origem.** `realpath` e `git-common-dir` nos dois lados; fixture com o peer rodando numa worktree do repositório dele.
5. **REQ-06, ponteiro para canal em que o destino não participa e texto livre junto ao ponteiro.** Avisar ou bloquear quando o repositório do destino não é participante do canal do ponteiro; teto de tamanho para o texto que acompanha o ponteiro.
6. **REQ-08, identificação da sessão.** O `SessionEnd` usa o `transcript_path` recebido no stdin; o CLI procura `~/.claude/projects/*/<id>.jsonl` (o slug muda em worktree). Definir a exibição de vários relatórios pendentes.
7. **REQ-05, envio para vários destinos.** Se o `SendMessage` tiver forma de broadcast, incluí-la na medição.
8. **REQ-04, varredura recursiva** de todos os campos string do `tool_input`, inclusive aninhados.
9. **REQ-07, leitura do remote.** Fixar `git remote get-url origin` (aplica `insteadOf`) ou `git config remote.origin.url`, com fixture de dois clones do mesmo repositório.
10. **REQ-10/12, manifest e consumidores existentes.** Acrescentar ao `affected_paths`: `template/.forge/commands/harness/prepare-pr.md`, `plugin/forge/commands/{prepare-pr,ship,doctor}.md` e o schema do cadastro. CHANGELOG e `/forge:upgrade` devem dizer como armar o gancho num consumidor existente (o gancho nasce inativo nele, inclusive em `payments`, o repositório do incidente).

## Notas de convergência (causa raiz já decidida pelo dono: contenção não é fronteira de segurança)

- **Troca de remote sem cadastro.** `self_identity` só existe após o primeiro cadastro; num repositório sem cadastro, `git remote set-url` passa despercebido. Considerar gravar `self_identity` independentemente do cadastro.
- **Ganchos desligados fora da lista fechada.** `disableAllHooks` e sobreposições em `.claude/settings.local.json` ou `~/.claude/settings.json`. Considerar o doctor checar o estado efetivo dos ganchos em todas as camadas de settings.
- **Edição não commitada do cadastro no tronco.** Considerar tratar como efetivo só o cadastro commitado (`git show <ref-do-tronco>:<path>`).
- **`git push --no-verify`** pula o pre-push; o doctor e o PR continuam cobrindo.
- **Envio direto pelo socket.** `CLAUDE_CODE_MESSAGING_TOKEN` e `CLAUDE_CODE_MESSAGING_SOCKET` estão no ambiente do Bash do agente; com eles o agente contorna o gancho de `SendMessage` inteiro (segredo, C2 e C3). A declaração de limite do REQ-09 deve cobrir o gancho de saída inteiro, não só `allowed_workspaces`.
