# Transcript — eval `revisao-mensageria-recarga-rabbitmq` (with_skill, run-1)

## Bootstrap

1. `cd .../evals-100 && pwd && git branch --show-current` — confirmou diretório `.../.forge/worktrees/evals-100` e branch `chore/evals-skills-agentes`, conforme esperado. Prosseguiu.
2. `date +%s > .../run-1/.t0` — instante inicial gravado.
3. `mkdir -p .../run-1/work` e `bash .../fixtures/revisao-mensageria-recarga-rabbitmq/setup.sh .../run-1/work` — projeto fixture materializado em `work/` (AGENTS.md, `.claude/settings.json`, `.forge/` completo com `rules/`, `scripts/`, `constitution.md` etc., mais `src/`, `infra/`, `docs/`).

## Leitura

4. Li `template/.forge/skills/data-streaming-practices/SKILL.md` (protocolo: Escopo → Rules do projeto → Detecção → Julgamento → Relatório) e as referências que ele cita: `template/.forge/skills/data-streaming-practices/references/best-practices.md` (seção `## RabbitMQ` completa: plataforma 4.x, exchanges, quorum, DLX, ack/prefetch, confirms, retry, idempotência/inbox, ordem, streams, operação, migrações) e `references/antipatterns.md` (catálogo RMQ-AP-01 a 28, INB-AP-01/02, SCH-AP-01, tabela `## Escolha de transporte`).
5. Li os arquivos do escopo pedido pelo usuário: `docs/contexto-mensageria.md`, `src/infra/rabbit.js`, `src/recarga/{publicador,consumidor,saldo-repositorio}.js`, `infra/rabbitmq/{definitions.json,enabled_plugins}`.
6. Li as rules do projeto citadas pelo protocolo: `work/.forge/rules/architecture/internal-grpc-communication.md`, `work/.forge/rules/domain/money-as-cents.md`, `work/.forge/rules/data/data-governance.md`. Nenhuma divergência relevante (`CONFLITO`) encontrada — evento assíncrono é exceção explícita da regra gRPC; payload usa inteiro em centavos; sem violação de isolamento multi-tenant no trecho revisado.

## Detecção

7. `bash template/.forge/scripts/check-data-governance.sh --path run-1/work` → `OK data-governance (3 .md, 0 código, no divergence)`. Tentativa anterior sem `--path` correto (usando `--help`) caiu em `FAIL .../universo-vazio` por engano de sintaxe — corrigido na segunda chamada.
8. `bash template/.forge/skills/data-streaming-practices/scripts/scan.sh --root run-1/work` (motor `rg`, universo `codigo iac proto avsc`, 8 arquivos varridos). Saída completa (exit 1, esperado quando há `FOUND`):
   - `FOUND RMQ-AP-03` [aviso] `rabbit.js:7`
   - `FOUND RMQ-AP-06` [alto] `definitions.json:15` (policy `ha-mode: all`)
   - `FOUND RMQ-AP-08` [aviso] `publicador.js:11` (publish sem confirms)
   - `FOUND RMQ-AP-10` [alto] `consumidor.js:24` (`canal.nack(msg)`)
   - `FOUND RMQ-AP-12` [aviso] `publicador.js:11` (publish sem `persistent`)
   - `FOUND RMQ-AP-17` [alto] `enabled_plugins:1` (plugin delayed exchange habilitado)
   - `FOUND INB-AP-02` [aviso] `consumidor.js:10` (`redelivered` como dedupe)
   - Demais 25 regras do catálogo: `OK`, sem ocorrência.

## Julgamento

9. `RMQ-AP-03` julgado falso positivo: `amqp.connect` está no bootstrap, chamado uma vez — é o lugar certo (RMQ-BP-06). Sem correção necessária ali; flagueei separadamente a ausência de handler de `connection.blocked` (RMQ-AP-25, achado manual, o scanner não cobre).
10. `RMQ-AP-08` + `RMQ-AP-12` julgados como a causa mais provável do incidente 1 (recarga que some após reinício de nó): publish sem confirms e sem `persistent: true`, apesar de a fila ser `durable: true` — fila durável só recupera mensagem persistente.
11. `RMQ-AP-10` julgado como causa direta do incidente 2 (fila girando por horas com Postgres fora do ar): `nack(msg)` sem `requeue=false` reenfileira imediatamente; documentei também que `basic.nack` não conta para `delivery-limit` de quorum, então só migrar para quorum não resolveria isso sozinho.
12. `INB-AP-02` julgado real: `redelivered` como prova de duplicata é pista fraca, e descarta mensagem que pode nunca ter tido efeito.
13. Achado manual fora do scanner: `const processados = new Set()` em `consumidor.js` é dedupe em memória (INB-AP-01) — o scanner não pegou por buscar nomes como `processedIds`/`seenMessages` e o código usa `processados` (português). Registrei isso explicitamente como gap do detector, não como ausência de antipattern.
14. Achados manuais em `definitions.json` (fora do alcance de texto do scanner, que audita isso em runtime): nenhuma fila declara `x-queue-type: quorum` (a policy `ha-mode: all` — já achado RMQ-AP-06 — é a HA real em vigor); nenhuma fila tem `max-length`/`overflow` (RMQ-AP-02); nenhuma fila tem `dead-letter-exchange` (RMQ-AP-11/23) — crítico porque, migrando para quorum, o `delivery-limit` default de 20 (RabbitMQ 4.0+) passaria a descartar mensagem em silêncio sem DLX.
15. `RMQ-AP-17` confirmado como violação ativa de intenção: `docs/contexto-mensageria.md` diz textualmente que o time quer usar o plugin delayed exchange (já habilitado) para o retry com espera — exatamente o antipattern.
16. Desenhei o retry com espera em duas fases, sem depender do plugin: pré-4.3 com filas de patamar (TTL de fila + DLX de volta, contando `x-death`), pós-4.3 com `delayed-retry-type: failed` nativo da quorum — condicionando a ativação do nativo à existência prévia da DLX (senão o `delivery-limit` descarta em silêncio).
17. Marquei como fora do escopo revisado, mas relevante: o código que publica a recarga não foi mostrado — se publish e commit da recarga não são atômicos (dual write / OBX-AP-01), é uma terceira via para o incidente 1, a confirmar à parte.

## Entrega

18. Escrevi o diagnóstico completo em `work/docs/revisao-mensageria.md` (não alterei nenhum código-fonte, conforme pedido) e copiei para `outputs/revisao-mensageria.md`.
19. Este `transcript.md` registra os passos, comandos e decisões em ordem.

## Notas de execução do harness (regras da tarefa)

- Não rodei `git commit/push/checkout/stash`, `tests/run-all.sh`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` de escrita, `npm publish` nem qualquer deploy real.
- Não spawnei subagentes; a tarefa não pediu.
- Tamanho final de `work/`: ~5,4 MB (abaixo do limite de 20 MB) — não apaguei.
