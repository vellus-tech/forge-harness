# Relatório de Validação — Módulos

- **Versão:** 1.1.0
- **Data:** 2026-09-26
- **Status:** Aprovado
- **Validador:** module-validator (revalidação após 2º ciclo do module-generator)

## Resumo Executivo

4 módulos revalidados após o 2º ciclo do module-generator (2026-09-20), executado em resposta ao relatório 1.0.0 (Reprovado). As três pendências anteriores foram fechadas: MOD-OWN-001 (ownership duplicado de cartoes_transporte) foi resolvida ao concentrar o dado em cadastro-passageiro; MOD-DEP-TRD-001 (recarga sem deployable) e MOD-DOC-001 (notificacoes sem diagrama de dependências) permanecem corrigidas desde o ciclo anterior. O ADR-0002 (cadastro-passageiro e notificacoes compartilhando o deployable backoffice-monolito) está refletido de forma consistente no TRD 1.4.0, no catálogo de módulos e nos dois READMEs afetados, sem contradição entre os artefatos. Nenhum achado bloqueante nesta rodada. Parecer: **Aprovado**.

## 1. Ownership de dados

| Dado | Dono declarado | Módulo(s) que leem/escrevem |
|---|---|---|
| passageiros | cadastro-passageiro | notificacoes (read-only, via ObterContato) |
| cartoes_transporte | cadastro-passageiro | recarga (read-only, escrita apenas via CreditarSaldo) |
| recargas | recarga | — |
| tabelas_tarifarias | tarifacao | recarga (read-only, via TarifaVigente) |
| notificacoes_enviadas | notificacoes | — |

MOD-OWN-001 **resolvido**: cartoes_transporte agora tem dono único (cadastro-passageiro); recarga declara o dado como read-only com escrita mediada por comando explícito (`CreditarSaldo`), sem conflito de ownership.

## 2. Deployables

| Deployable | Módulos | Consistência TRD × módulos × ADR |
|---|---|---|
| backoffice-monolito | cadastro-passageiro, notificacoes | Consistente — TRD 1.4.0, ambos os READMEs e o catálogo de módulos citam o mesmo deployable e o mesmo ADR-0002; fronteira entre os dois módulos mantida por pacote + teste de arquitetura (ArchUnit), conforme a decisão do ADR |
| recarga-service | recarga | Consistente — TRD e README do módulo concordam (Kotlin/Spring Boot + PostgreSQL, rede segmentada, escopo PCI DSS) |
| tarifacao-service | tarifacao | Consistente — TRD e README do módulo concordam |

MOD-DEP-TRD-001 **permanece corrigido**: recarga declara `recarga-service` e o TRD confirma.

Achado novo, não bloqueante: um deployable compartilhado por dois módulos (backoffice-monolito) concentra o raio de impacto de deploy e de indisponibilidade dos dois bounded contexts. O ADR-0002 já registra essa consequência (deploy conjunto) e a mitigação (fronteira por pacote + ArchUnit), portanto não é reaberto como achado de conformidade — fica como observação para acompanhar se o volume de eventos crescer além do parâmetro citado no ADR (2 mil eventos/dia).

## 3. Diagramas de dependências

Todos os quatro módulos (cadastro-passageiro, recarga, tarifacao, notificacoes) têm diagrama de dependências (`graph LR`), diagrama de arquitetura interna (`graph TD`) e diagrama de sequência de integração. notificacoes, que motivou o achado MOD-DOC-001, agora tem os três diagramas.

MOD-DOC-001 **permanece corrigido**.

## 4. Contratos (OpenAPI/AsyncAPI)

Não há arquivos de contrato OpenAPI/AsyncAPI no repositório nesta revisão (`contracts/` não contém especificação REST/eventos formalizada; apenas o `.proto` de tarifacao existe, referenciado no README do módulo). Isso é esperado nesta fase — o time ainda não iniciou a implementação — e não é tratado como achado de conformidade, mas fica registrado como pendência de rastreabilidade: RF-03/RF-04 (recarga, REST `POST /recargas`) e o evento `RecargaConfirmada` (RabbitMQ) hoje só estão descritos em prosa/diagrama de sequência nos READMEs, sem contrato versionado. Recomenda-se abrir os contratos (OpenAPI para a superfície REST externa de recarga, AsyncAPI para `RecargaConfirmada`) antes do início da implementação, mantendo o gRPC interno como já formalizado pelo `.proto` de tarifacao.

## 5. Achados

| ID | Descrição | Arquivo | Severidade | Status |
|---|---|---|---|---|
| MOD-OWN-001 | cartoes_transporte com dois donos | docs/product/modules/recarga/README.md, docs/product/modules/cadastro-passageiro/README.md | Crítica | Resolvido nesta rodada |
| MOD-DEP-TRD-001 | recarga sem deployable | docs/product/modules/recarga/README.md | Alta | Resolvido (ciclo anterior, confirmado) |
| MOD-DOC-001 | notificacoes sem diagrama de dependências | docs/product/modules/notificacoes/README.md | Média | Resolvido (ciclo anterior, confirmado) |
| MOD-CONTRACT-001 | Ausência de contratos OpenAPI/AsyncAPI formalizados para recarga (REST) e RecargaConfirmada (evento) | docs/product/modules/recarga/README.md | Baixa (informativo, não bloqueante nesta fase) | Aberto — endereçar antes da implementação |

## 6. Questão adicional — classificação de tarifacao (Core vs. Supporting)

O PRD descreve a tarifa vigente como "definida pelo poder concedente e aplicada no validador embarcado" — ou seja, a tabela tarifária é aprovada por um agente regulatório externo, e o módulo tarifacao apenas publica e versiona essa tabela, expondo-a como Open Host Service (`TarifaVigente`). Não há, na documentação atual, nenhuma lógica proprietária de precificação, elasticidade, otimização de tarifa ou vantagem competitiva construída pelo Passe Urbano dentro desse módulo — a complexidade de negócio real (cálculo de tarifa, política de preço) mora fora do sistema, no órgão concedente.

Pelo critério clássico de DDD (subdomínio Core = onde a empresa constrói diferenciação competitiva e concentra investimento de modelagem; Supporting = necessário para o negócio funcionar, mas replicável/sem diferenciação), tarifacao se encaixa melhor como **Supporting**: é indispensável (recarga depende dele para calcular passagens), mas não é fonte de vantagem competitiva — é essencialmente um serviço de leitura/versionamento de uma tabela definida externamente, com risco técnico e de modelagem baixo.

Isso é interpretação, não fato documentado — a segmentação DDD atual (`docs/product/ddd/ddd-segmentation.md`, v1.0.0, 2026-08-18) não registra a justificativa da escolha de Core para tarifacao, e os READMEs de subdomínio (`docs/product/ddd/subdomains/core/tarifacao/README.md` e os equivalentes de recarga/cadastro-passageiro) estão vazios (só o título), então não há como confirmar se houve um racional de negócio não capturado aqui (ex.: se o consórcio pretende competir por SLA/precisão de tarifação, ou se há planos de tarifação dinâmica futura que justifiquem tratá-lo como Core hoje). Recomendação: reclassificar para Supporting, a menos que exista uma razão estratégica documentada (não encontrada nesta revisão) para mantê-lo Core — e, de qualquer forma, preencher o README do subdomínio com a justificativa, hoje ausente.

## 10. Parecer Final

**Aprovado** — as três pendências do relatório 1.0.0 estão fechadas e o ADR-0002 está refletido sem contradição entre TRD, catálogo de módulos e READMEs. Um achado informativo (MOD-CONTRACT-001, ausência de contratos formais) fica registrado para antes da implementação, sem bloquear esta validação. A classificação de tarifacao como Core é questionável à luz da definição de subdomínio Core em DDD e do fato de a tarifa ser definida externamente; recomenda-se decisão explícita do time de produto/arquitetura sobre manter Core ou mover para Supporting, com o racional documentado no README do subdomínio.
