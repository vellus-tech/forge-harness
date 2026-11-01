# Medição (c) — registro de sessões `~/.claude/sessions/<pid>.json`

Medido em 2026-10-30 (máquina do dono, 14 sessões locais vivas) para o resolvedor de destino do REQ-07 e a conferência de origem do REQ-02. Complementa a medição anterior registrada nos requirements (campos `pid`, `sessionId`, `cwd`, `name`, `nameSource`, `messagingSocketPath`, `kind`, `status`, `version`; nomes não únicos; Remote Control e nuvem sem arquivo local).

## Método

Um script `node` leu só os arquivos `*.json` do diretório (os `*.key` foram listados pelo nome, com o sufixo hex, e nunca abertos) e imprimiu agregados: conjunto de chaves por arquivo, contagem por valor dos campos categóricos, padrão do socket com o pid mascarado, nomes repetidos, e vivacidade de cada `pid` por `process.kill(pid, 0)`. Valores de `sessionId`, `cwd` e nomes de sessões de terceiros não foram gravados aqui.

## Resultados

- 14 arquivos `<pid>.json`, cada um com um `<pid>.<64 hex>.key` ao lado (não aberto).
- Todos legíveis como JSON; todos os `pid` vivos no momento da medição (nenhum registro órfão).
- Chaves presentes em todos: `pid`, `sessionId`, `cwd`, `startedAt`, `procStart`, `version`, `peerProtocol`, `peerFeatures`, `kind`, `entrypoint`, `pidDomain`, `messagingSocketPath`, `name`, `nameSince`, `status`, `updatedAt`, `statusUpdatedAt`, `bridgeSessionId`. Variáveis: `nameSource` (ausente em 1 registro, de `kind: bg`), `asksForConvertedSkills`, `jobId`, `parkedJobId`.
- `kind`: `interactive` (13), `bg` (1). `status`: `idle`, `busy`, `shell`. `nameSource`: `user` (12), `derived` (1), ausente (1). `entrypoint`: `cli`. `pidDomain`: `darwin`. `peerProtocol`: `1`. `peerFeatures`: `["notify_idle","reply_across_default_dirs","artifact_yield"]` em todos.
- Versões coexistindo: 2.1.310 (12), 2.1.311 (1), 2.1.314 (1). O formato é o mesmo nas três.
- `messagingSocketPath` é sempre `/tmp/cc-socks/<pid>.sock` (14 de 14 com o próprio `pid`). `/tmp` é link simbólico para `private/tmp` no macOS (`ls -ld /tmp`), e o `from` de uma mensagem recebida usa a forma `/tmp/...` (medição b).
- `procStart` é string de data (`Sun Oct 99 99:99:99 9999` com dígitos mascarados), útil para distinguir reuso de pid, mas exige `ps` para comparar; o design usa a existência do socket em vez dele.
- Nomes repetidos: `ASSISTENTE` aparece 2 vezes. A sessão do orquestrador (`forge-harness-23`) tem `nameSource: user`, `kind: interactive` e socket com o próprio pid.
- A sessão headless filha da medição (a) apareceu no `ListAgents` como `work-a4` (nome derivado do diretório) e seu `<pid>.json` não existia mais depois do fim do processo: o Claude Code remove o registro na saída normal.
- O ref de 6 hex exibido pelo `ListAgents` não é prefixo de `sessionId`, `bridgeSessionId` nem do sha256 deles ou do socket (medição a): o registro não permite mapear `nome [ref]` a um arquivo.
