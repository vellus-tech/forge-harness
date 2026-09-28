# Transcript — eval-retry-liquidacao-fila-ordenada (with_skill)

## 0. Bootstrap
- `cd .../evals-100 && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes`.
- `date +%s > run-1/.t0`.
- `mkdir -p run-1/work` e `bash fixtures/retry-liquidacao-fila-ordenada/setup.sh run-1/work` — montou o projeto Forge da fixture (init + overlay com `src/liquidacao/consumidor.js`, `infra/rabbitmq/definitions.json`, `docs/contexto-liquidacao.md`).

## 1. Leitura dos insumos
- `docs/contexto-liquidacao.md`: RabbitMQ 4.3 em Khepri, fila `liquidacao.lancamentos` quorum + Single Active Consumer por causa da ordem por conta de lojista; liquidante cai algumas vezes por semana (1–15min); consumidor hoje rejeita sem requeue; sem DLX; ~40k lançamentos/dia, pico 30/s.
- `src/liquidacao/consumidor.js`: `prefetch(1)`, `ack` em duplicata (idempotência via inbox), e em qualquer erro (`ErroTransitorio` ou não) faz `reject(msg, false)` — ou seja, hoje perde a mensagem de vez, sem retry e sem DLX.
- `infra/rabbitmq/definitions.json`: exchange topic `pagamentos.eventos`, fila quorum SAC `liquidacao.lancamentos`, policy com `delivery-limit: 5` e `max-length`, sem `dead-letter-exchange` nem `overflow` explícito.

## 2. Skill carregada — `data-streaming-practices`
- `SKILL.md` do template (`.forge/skills/data-streaming-practices/SKILL.md`): protocolo fixo Escopo → Rules do projeto → Detecção → Julgamento → Relatório.
- `references/best-practices.md` (`## RabbitMQ`): li os fatos de plataforma 4.3 (Khepri, plugin delayed exchange arquivado, retry atrasado nativo da quorum) e as receitas RMQ-BP-10/11/12/20/21/23 sobre DLX, poison message e retry em fila com ordem.
- `references/antipatterns.md`: RMQ-AP-10 (requeue infinito), RMQ-AP-11 (sem DLX), RMQ-AP-17 (plugin delayed exchange), RMQ-AP-23 (delivery-limit sem DLX), RMQ-AP-24 (overflow drop-head silencioso), RMQ-AP-26 (retry atrasado em fila que promete ordem).

## 3. Rules do projeto (protocolo passo 2)
- `.forge/rules/architecture/internal-grpc-communication.md` — não se aplica (não há chamada interna síncrona aqui; a chamada ao liquidante é externa).
- `.forge/rules/domain/money-as-cents.md` — não há alteração de payload monetário neste patch.
- `.forge/rules/data/*` — nada específico a filas.
- `.forge/rules/conventions/conflict-handling.md` — li para saber como sinalizar divergência; a divergência aqui é entre o pedido do usuário e a boa prática de mensageria (RMQ-AP-26), não entre duas fontes normativas do projeto (rule↔ADR etc.), então tratei como achado de julgamento da skill (protocolo passo 4/5), documentado no design doc, não como CONFLITO bloqueante formal do harness.

## 4. Detecção
- `bash .forge/scripts/check-data-governance.sh --path <work>` → `OK data-governance (3 .md, 0 código, no divergence)`.
- `bash .forge/skills/data-streaming-practices/scripts/scan.sh --root <work>` (pré-patch) → todas as regras estáticas `OK`, nenhuma ocorrência. Esperado: RMQ-AP-11, RMQ-AP-23 e RMQ-AP-26 são achados de **runtime/revisão** (documentado em "O que o scanner não faz"), não de varredura estática — por isso não aparecem aqui.
- Saída completa em `outputs/deteccao.txt` (rodei de novo depois do patch — mesmo resultado, sem regressão).

## 5. Julgamento — a decisão central
O pedido literal era `delayed-retry-type` (nativo do 4.3) com patamares 5s/30s/5min na `liquidacao.lancamentos`. Antes de implementar ao pé da letra, cruzei com RMQ-BP-23/RMQ-AP-26: retry atrasado (nativo, fila de espera ou DLX de volta) tira a mensagem da ordem — em fila que promete ordem (este é o caso, SAC), a prescrição da base é "retry no próprio consumidor, com teto" ou parking lot com a chave marcada, nunca retry atrasado silencioso.

Decisão: implementar o retry **dentro do consumidor** (sem soltar a mensagem, sem `ack`/`reject` durante a espera), usando os mesmos patamares 5s/30s/5min como progressão e mantendo o teto em 5min com jitter (RMQ-BP: jitter no cliente para chamada remota). Erro permanente (não `ErroTransitorio`) continua indo para `reject(msg, false)` — agora com DLX atrás, o que faltava.

Também corrigi, por serem achados diretos da leitura da topologia contra RMQ-AP-11/RMQ-AP-23/RMQ-AP-24 (mesmo sem o scanner ter sinalizado, por serem de revisão): adicionei `liquidacao.dlx` + `liquidacao.parking` e a policy ganhou `dead-letter-exchange`, `dead-letter-strategy: at-least-once` e `overflow: reject-publish`.

Não fiz: rastreamento de "conta bloqueada" para o caso de uma mensagem parqueada por erro permanente enquanto lançamentos seguintes da mesma conta continuam fluindo — é decisão de produto, sinalizada no design doc como aberta, não decidida por mim.

## 6. Entregáveis
- `infra/rabbitmq/definitions.json` — DLX + parking + policy corrigida (patch aplicado em `work/`, cópia em `outputs/`).
- `src/liquidacao/consumidor.js` — retry em processo para erro transitório, `reject` direto para erro permanente (patch aplicado em `work/`, cópia em `outputs/`).
- `docs/design-retry-liquidacao.md` — desenho completo, incluindo por que o pedido literal (delayed retry nativo) não foi implementado, com as fontes (RMQ-BP-11/12/20/21/23, RMQ-AP-10/11/17/23/24/26) e os pontos em aberto (patch aplicado em `work/`, cópia em `outputs/`).
- `outputs/deteccao.txt` — saída de `check-data-governance.sh` e `scan.sh` (pré e pós-patch).

## 7. Verificação
- `node -e "JSON.parse(...)"` sobre `definitions.json` → JSON válido.
- `node --check consumidor.js` → sintaxe válida.
- `scan.sh` pós-patch → mesmo resultado limpo (sem regressão estática; os achados relevantes eram de revisão, cobertos no design doc).
- Sem testes automatizados na fixture (não há `package.json`/suíte); não rodei `npm test` (nem existiria) e não rodei `git commit` nem qualquer escrita fora de `run-1/` — nada disso era permitido nesta tarefa.

## 8. Notas sobre restrições desta execução
- Não rodei `git commit/push/checkout/stash`, `tests/run-all.sh`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` (escrita) nem `npm publish` — nenhum foi necessário para esta tarefa.
- Nenhum subagente foi spawnado; a análise (Escopo/Rules/Detecção/Julgamento/Relatório) foi conduzida integralmente por esta sessão, como o protocolo da skill descreve para ferramenta sem subagentes.
- Tudo escrito ficou dentro de `run-1/` (fixture em `run-1/work/`, entregáveis em `run-1/outputs/`).
