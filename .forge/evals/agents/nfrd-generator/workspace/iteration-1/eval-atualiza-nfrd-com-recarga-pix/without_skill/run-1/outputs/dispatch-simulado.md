# Despacho de subagentes simulado (não executado)

Este run é o braço `without_skill` do eval — por instrução do harness, nenhum subagente foi
efetivamente spawnado. Caso o protocolo do skill-creator/agentes reais estivesse disponível
e autorizado neste run, o despacho que eu faria seria:

1. **Agente:** `nfrd-generator` (ou equivalente ao artefato sob avaliação)
   **Modelo:** sonnet
   **Prompt resumido:** ler PRD v1.1 (seção 7 — recarga via Pix) e NFRD v1.0 existente;
   gerar NFRD v1.1 cobrindo os novos requisitos não funcionais implicados pela recarga Pix
   (latência de crédito, idempotência de webhook, mTLS, retenção de comprovantes, auditoria
   de crédito, resiliência da integração com o PSP), preservando os NFRs da v1.0 que
   continuam válidos e atualizando a matriz de rastreabilidade PRD → NFRD.

2. **Agente:** revisor crítico (ex.: `code-evaluator`/equivalente de revisão de documento)
   **Modelo:** opus (effort medium)
   **Prompt resumido:** revisar o NFRD v1.1 gerado contra o PRD v1.1 REQ a REQ, verificar
   se cada requisito novo do PRD (R-03, R-04, R-05, KPI-02, J-02) tem NFR correspondente
   com meta mensurável e critério de aceite verificável, e apontar lacunas antes da entrega
   ao time de pagamentos.

Como estou no braço `without_skill` (baseline sem o artefato), executei a tarefa sozinho,
com meu próprio conhecimento de NFRD, sem consultar templates/skills/agentes do projeto.
