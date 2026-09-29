# Parecer técnico — TRD Axis Validação (baseline sprint 14)

**Objeto:** revisão crítica do TRD (`docs/product/trd/trd.md`) contra PRD v1.2, FRD, NFRD, ADR-0001 a ADR-0004, DDD Segmentation, Modules e Data Model, antes de virar baseline técnico da sprint 14. A engenharia começa pela `validacao-api` na segunda-feira.

**Parecer:** o TRD pode seguir como baseline técnico após as correções abaixo, já aplicadas diretamente no documento (`docs/product/trd/trd.md`, versão v0.2). Nenhuma decisão arquitetural do TRD contradiz os ADRs — a divergência estava em omissões de conteúdo e de rastreabilidade, não em escolhas técnicas erradas. O achado mais relevante para a engenharia que começa pela `validacao-api` na segunda é o item 1: a publicação do evento `ValidacaoRegistrada.v1` era um requisito funcional (FRD-VAL-01) implícito no Modules.md e no DDD, mas ausente da arquitetura de eventos do TRD — sem essa correção, a equipe teria implementado a `validacao-api` sem o publisher do evento que `tarifacao-svc` e `liquidacao-worker` dependem.

## Correções já aplicadas no TRD (v0.2)

1. **Evento `ValidacaoRegistrada.v1` ausente da arquitetura de eventos (seção 9) e do diagrama (seção 19).** O Modules.md e o DDD Segmentation definem que `validacao-api` publica `ValidacaoRegistrada.v1`, consumido por `tarifacao-svc` e `liquidacao-worker`; o FRD-VAL-01 exige explicitamente "publicar o fato para os demais contextos". O TRD v0.1 só descrevia a chamada gRPC síncrona de `validacao-api` para `tarifacao-svc` (para obter a tarifa) e o evento `TarifaCalculada.v1`, mas nunca o evento de origem da cadeia. Adicionado à tabela de eventos, à seção 5 (Visão Técnica) e ao diagrama Mermaid.

2. **Retenção de `lotes_compensacao` ausente da seção 10.** O Data Model define retenção de 10 anos para `lotes_compensacao` (distinta dos 5 anos de `validacoes`/`tarifas_aplicadas`); o TRD v0.1 só mencionava a retenção de `validacoes`. Corrigido.

3. **Retenção da DLQ e idempotência dos consumidores ausentes da seção 9.** O ADR-0004 exige DLQ com retenção de 7 dias e consumidores idempotentes por `event_id`; o TRD v0.1 registrava apenas "3 tentativas, DLQ `liquidacao.dlq`", sem esses dois pontos que a engenharia precisa implementar. Adicionado como nota de texto na seção 9.

4. **Seção de Observabilidade inexistente.** NFRD-OBS-01 (logs estruturados + `correlation_id` + métricas RED + alerta de p99) e NFRD-OBS-02 (health checks de liveness/readiness) não tinham nenhuma seção correspondente no TRD v0.1 — o documento pulava da seção 13 direto para a 15. Criada a seção 14 (Observabilidade) com o conteúdo derivado literalmente da NFRD.

5. **Matriz de rastreabilidade incompleta (seção 20).** Faltavam FRD-EXT-01, NFRD-PERF-01, NFRD-OBS-01, NFRD-OBS-02 e NFRD-RET-01 — nenhum dos cinco requisitos aparecia na matriz, embora quatro deles já tivessem cobertura implícita no corpo do documento (seção 8 para o extrato, seção 15 para performance, seção 10 para retenção) e o quinto par (observabilidade) só passou a ter seção própria com o item 4 acima. Matriz completada.

## Pontos que ficam para decisão humana (não arrumados no TRD)

6. **Numeração de seções com lacuna na seção 22** (a numeração salta de 21 para 23; a lacuna na seção 14 já foi preenchida pelo item 4). Não há como saber pelos insumos disponíveis o que a seção 22 deveria conter — pode ser um artefato de template (ex.: "Dependências Externas" ou "Decisões Técnicas Pendentes") que foi removido por engano, ou simplesmente numeração não sequencial intencional. Recomendo confirmar com quem gerou o template do TRD antes de arquivar como baseline; não inventei conteúdo para não introduzir um requisito fantasma.

7. **Orçamento de latência (NFRD-PERF-01) só parcialmente detalhado.** O TRD registra o timeout de 150 ms da chamada `validacao-api` → `tarifacao-svc`, mas não decompõe o restante do orçamento de 300 ms p99 (validação do token no validador embarcado, latência de rede até a `validacao-api`, escrita do evento). Adicionei uma frase ligando o timeout ao orçamento total (NFRD-PERF-01) para deixar a rastreabilidade explícita, mas a decomposição fina do budget é uma decisão de engenharia, não uma correção editorial — sugiro que a equipe da `validacao-api` feche isso no início da sprint 14, já que é o primeiro módulo a entrar em implementação.

8. **Implementação técnica da integração temporal de 60 minutos (PRD/FRD-TAR-01) não está detalhada no TRD** — não há menção a onde o estado da "última validação por token" é mantido (cache, tabela com TTL, etc.) na `tarifacao-svc`. Não é uma contradição entre os insumos, é uma lacuna de design que cabe à equipe de `tarifacao-svc` detalhar; não arrumei porque não há informação nos insumos que permita decidir a estrutura de dados correta.

## Conferência de consistência (sem achados)

- Módulos, deployables e bancos (seção 7) batem com Modules.md e Data Model.
- Protocolos de API (seção 8): gRPC interno com contrato versionado e REST na borda batem com o ADR-0002; nenhum serviço gRPC exposto a terceiros.
- Segurança do PAN (seções 12-13): tokenização no gateway, `card_token` como único dado transitando nos serviços Axis e ambiente fora do CDE batem com o ADR-0003 e com a restrição de PCI DSS do PRD.
- Banco por contexto (seção 6, ADR-0001) e broker de eventos (ADR-0004) citados corretamente como decisões arquiteturais.

---
Preparado para anexar ao ticket do comitê de arquitetura — baseline técnico da sprint 14, Axis Validação.
