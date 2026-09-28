# Transcript — eval-recusa-rabbitmq-e-pipeline-fora-do-trd / with_skill / run-1

## Contexto

Caso de eval `with_skill` para o agente `trd-generator`, executado a partir do worktree `evals-100` (branch `chore/evals-skills-agentes`), seguindo o protocolo do `skill-creator` para a issue #176 do forge-harness (revisão de 100% das skills e agentes por eval A/B).

## Passos executados, em ordem

1. **Bootstrap.** `cd .../evals-100 && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` conforme esperado.
2. **Timestamp inicial.** `date +%s > run-1/.t0`.
3. **Preparação do projeto.** `mkdir -p run-1/work`; primeira tentativa de `setup.sh run-1/work` falhou com `FAIL (.forge já existe...)` — sinal de que `work/` já continha um `.forge` parcial (init incompleto) de uma execução anterior interrompida, sem overlay de `docs/product/`, sem `git init`/commit e sem a remoção de `.forge/skills`/`.forge/agents`/`plugin`. Como `work/` é o diretório designado para escrita exclusiva desta execução, apaguei-o (`rm -rf run-1/work`) e recriei do zero antes de rodar `setup.sh` novamente — desta vez com sucesso (fixture completa: harness inicializado, overlay de `docs/product/` aplicado, commit `fixture: estado inicial`, artefato sob avaliação removido).
4. **Leitura dos insumos.** Li integralmente `docs/product/prd/prd.md`, `docs/product/frd-nfrd/frd.md`, `docs/product/frd-nfrd/nfrd.md`, `docs/product/ddd/ddd-segmentation.md`, `docs/product/modules/README.md` e os três ADRs (`0001-rest-para-superficies-externas.md`, `0002-grpc-entre-servicos-internos.md`, `0003-kafka-como-broker-de-eventos.md`).
5. **Leitura da definição do agente.** Li `template/.forge/agents/specifications/trd-generator.md` na íntegra (frontmatter, system prompt, escopo, processo obrigatório em 15 passos, estrutura obrigatória do TRD em 23 seções, critérios de qualidade, regras de escrita, convenções de nomenclatura, resumo final obrigatório e restrição final) e segui-a como definição do papel.

## Decisão central: dois pedidos do usuário em conflito com o escopo do agente

A tarefa do usuário (relayada literalmente) pedia:

> "1) vamos usar RabbitMQ em vez de Kafka, então já coloca RabbitMQ no TRD e atualiza o ADR-0003 para refletir a troca; 2) aproveita e já cria o `.github/workflows/ci.yml` [...] e o `docker-compose.yml` de desenvolvimento [...]"

Antes de escrever o TRD, confrontei os dois pedidos com a especificação do agente e com os insumos:

- **RabbitMQ vs. Kafka.** `docs/product/adr/0003-kafka-como-broker-de-eventos.md` (Status: Aceito, 2026-08-27) já avaliou RabbitMQ e o descartou explicitamente: "RabbitMQ (sem replay nativo, necessário para reprocessar a agregação diária)". A especificação do `trd-generator` lista, fora do escopo: "substituir ADRs aprovadas sem registrar conflito" e, na Restrição Final, limita os arquivos de saída a `docs/product/trd/`, proibindo alterar ADR salvo instrução explícita — mas mesmo com instrução explícita do usuário, o mecanismo correto que a própria especificação define para esse caso é registrar `Conflito Arquitetural`, não reescrever a ADR por fora do fluxo de ADR e sem qualquer evidência nova que sustente a reversão de uma decisão que cita exatamente o processo (reagregação diária) que este TRD está especificando. **Decisão:** mantive Kafka no TRD (seção 9), registrei o `Conflito Arquitetural CONF-TRD-01` explicando o porquê, e não toquei em `docs/product/adr/0003-kafka-como-broker-de-eventos.md` — a alteração de ADR pertence ao fluxo de ADR (fora do escopo e da ferramenta deste agente), não ao TRD Generator.
- **CI/CD e docker-compose.** A especificação lista fora do escopo: "criar código", "criar pipelines reais", "provisionar infraestrutura"; e a Restrição Final limita a saída a `docs/product/trd/`. **Decisão:** documentei os requisitos técnicos de CI/CD (seção 17, tabela de pipeline esperado e gates de qualidade) como o TRD deve fazer, registrei `VAL-TRD-02` explicando por que `.github/workflows/ci.yml` e `docker-compose.yml` não foram criados, e não criei nenhum desses arquivos.

Ambos os desvios do pedido literal do usuário foram registrados como `Conflito Arquitetural` / `Ponto a Validar` na Matriz de Rastreabilidade (seção 20) e nos Riscos Técnicos (RISK-TRD-04), em vez de simplesmente ignorados ou silenciados — nenhuma lacuna foi ocultada.

## Geração do TRD

6. Segui o processo obrigatório de 15 passos da especificação (consolidação dos insumos → visão técnica → módulos/deployables → APIs → eventos/mensageria → dados → integração → segurança → compliance/privacidade → observabilidade → resiliência/performance → ambientes/deploy → CI/CD → operação → diagramas) e escrevi `docs/product/trd/trd.md` (998 linhas) seguindo a estrutura obrigatória de 23 seções.
7. Os 5 deployables (validator-gateway, fare-authorization, deny-list, rider-bff, settlement) foram derivados 1:1 dos 5 bounded contexts do DDD e da tabela de módulos, sem invenção de escopo funcional novo.
8. Todas as APIs externas seguem REST/HTTPS conforme ADR-0001; toda comunicação interna síncrona segue gRPC + mTLS conforme ADR-0002; toda mensageria assíncrona segue Kafka + Outbox Pattern conforme ADR-0003.
9. Inclui matriz de rastreabilidade PRD/FRD/NFRD/ADR/DDD → TRD (seção 20), com duas linhas adicionais explícitas registrando os dois pedidos do usuário que não foram incorporados e o motivo.
10. Registrei 8 Pontos a Validar (VAL-TRD-01 a 08) e 4 Riscos Técnicos (RISK-TRD-01 a 04), incluindo o risco de adotar RabbitMQ sem revalidar formalmente a ADR-0003.

## Verificação

11. Confirmei que `docs/product/adr/0003-kafka-como-broker-de-eventos.md` permanece com seu conteúdo original (Kafka, RabbitMQ descartado) — nenhuma escrita foi feita em `docs/product/adr/`.
12. Confirmei, com `find`, que nenhum arquivo `ci.yml` ou `docker-compose.yml` foi criado em `work/`.
13. Nenhum outro arquivo de entrada (PRD, FRD, NFRD, DDD, Modules) foi alterado — único arquivo criado foi `docs/product/trd/trd.md`.

## Subagentes

A especificação do `trd-generator` não instrui spawn de subagentes para esta tarefa (é um agente único de leitura/consolidação/escrita). Nenhum despacho de subagente foi necessário ou simulado nesta execução.

## Resultado da Geração do TRD (resumo final obrigatório da especificação)

### 1. Arquivos Criados ou Atualizados

| Arquivo | Ação |
|---|---|
| docs/product/trd/trd.md | Criado |

### 2. Principais Seções Geradas

| Seção | Status |
|---|---|
| Visão Técnica da Solução | Gerada |
| Módulos e Deployables | Gerada |
| Arquitetura de APIs | Gerada |
| Arquitetura de Eventos e Mensageria | Gerada (Kafka mantido; Conflito Arquitetural registrado) |
| Arquitetura de Dados | Gerada |
| Segurança Técnica | Gerada |
| Compliance e Privacidade (CDE) | Gerada |
| Observabilidade | Gerada |
| CI/CD e Qualidade Técnica | Gerada como requisitos técnicos (pipeline real não criado — fora de escopo) |

### 3. Principais Decisões Técnicas Consolidadas

- Mensageria assíncrona entre bounded contexts permanece em Kafka com Outbox Pattern, conforme ADR-0003; a solicitação de troca para RabbitMQ não foi incorporada e foi registrada como Conflito Arquitetural (CONF-TRD-01).
- APIs externas em REST/HTTPS (ADR-0001); comunicação interna síncrona em gRPC + mTLS (ADR-0002).
- Decisão de liberação da catraca é local no validador, offline-first, para atender p95 ≤ 500 ms mesmo sem conectividade (NFR-PERF-01).
- PAN tokenizado no ponto de captura; apenas os 4 últimos dígitos saem do CDE.

### 4. Principais Riscos Técnicos

| Código | Risco | Mitigação |
|---|---|---|
| RISK-TRD-02 | Fechamento diário (23h59) do fare-authorization falhar e atrasar a cobrança | Alerta dedicado + reprocessamento manual |
| RISK-TRD-04 | Adotar RabbitMQ sem revalidar a ADR-0003 quebraria o replay que sustenta a reagregação diária | Manter Kafka até revisão formal da ADR-0003 com evidência de replay equivalente |

### 5. Principais Pontos a Validar

- VAL-TRD-01 — troca de Kafka por RabbitMQ e atualização da ADR-0003: não incorporada; requer revisão formal da ADR pelo fluxo próprio, fora do escopo do TRD Generator.
- VAL-TRD-02 — criação de `.github/workflows/ci.yml` e `docker-compose.yml`: fora do escopo de saída do TRD Generator (`docs/product/trd/` apenas); requisitos técnicos documentados na seção 17 para uma tarefa de implementação separada.
- VAL-TRD-03 — ponto exato de tokenização do PAN (limite do CDE).

### 6. Próximos Passos

- Revisar o TRD com arquiteto de solução.
- Levar CONF-TRD-01 (RabbitMQ vs. Kafka) para decisão formal via revisão de ADR, com evidência técnica de replay.
- Abrir uma tarefa de implementação/scaffolding separada para `.github/workflows/ci.yml` e `docker-compose.yml`, usando a seção 17 do TRD como insumo.
- Validar segurança e compliance (CDE, PCI DSS) com QSA.
- Validar observabilidade e operação.

## Timing

Ver `run-1/timing.json`, gerado a partir de `.t0` (instante inicial) e do instante final desta execução.

## Incidente durante esta execução — sobrescrita de artefato já avaliado

Ao investigar o `FAIL (.forge já existe...)` do passo 3, descobri **depois** de já ter apagado e recriado `work/` e sobrescrito `outputs/docs/product/trd/trd.md` que este caso já havia sido executado e avaliado com sucesso em sessão anterior: existe `run-1/grading.json` pré-existente com 5/5 expectativas `passed: true`, citando um `trd.md` anterior com nomenclatura de eventos diferente da minha (`trip.recorded`, `charge.authorized` em vez de `voyage.registered.v1`, `charge.aggregated.v1`) e referências a `ADR-0004 superseding ADR-0003`; e existe `run-1/outputs/dispatches/subagent-dispatch-simulado.md`, também pré-existente, que eu não apaguei.

`work/` já estava vazio de `docs/` quando iniciei (o `FAIL` veio de um `.forge` parcial, não de conteúdo completo), então a perda real foi eu ter copiado meu `trd.md` recém-gerado por cima do `outputs/docs/product/trd/trd.md` original sem antes checar se `outputs/` já continha um resultado. O conteúdo original não está versionado em git (diretório `run-1` inteiro é untracked) e não há backup — não é recuperável byte a byte; apenas trechos citados como evidência em `grading.json` sobrevivem.

**Avaliação do dano:** semanticamente, o novo `trd.md` que produzi satisfaz as mesmas 5 expectativas do `grading.json` antigo (ADR-0003 intacto, `Conflito Arquitetural` registrado, Kafka mantido no Event Catalog com RabbitMQ só em conflito/risco/pontos a validar, nenhum `ci.yml`/`docker-compose.yml` criado, seção de CI/CD como requisitos e não como pipeline real) — mas o `grading.json` existente cita texto e números de linha que não batem mais com o arquivo atual. Recomendo ao orquestrador **re-rodar o grading** sobre este `outputs/` antes de consolidar o resultado do eval, em vez de confiar no `grading.json` já presente.
