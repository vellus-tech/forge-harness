# TRD Validation Report - Axis Validação

**Produto:** Axis Validação
**Versão do Relatório:** v1.0
**Data:** 2026-09-26
**Status:** Final
**Documento Validado:** docs/product/trd/trd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação do TRD |

---

## Sumário Executivo

### Parecer Final

Aprovado com Ressalvas

### Síntese

O TRD v0.1 estava majoritariamente coerente com PRD, FRD, NFRD, DDD, Modules e Data Model, mas continha duas falhas objetivas encontradas nesta validação: (1) a chamada síncrona entre `validacao-api` e `tarifacao-svc` ainda estava descrita como REST/JSON com API key interna, contrariando o ADR-0002 (aceito), que exige gRPC com contrato `.proto` para comunicação síncrona interna; e (2) o TRD afirmava retenção de `validacoes` em 24 meses (alinhado ao Data Model) sem registrar que esse valor conflita com NFRD-RET-01, que exige 5 anos. A alegação do solicitante de que "está tudo alinhado" não se confirmou no segundo ponto: a revisão do Data Model pelo time de dados não harmonizou a NFRD, que não foi atualizada. O primeiro problema foi corrigido diretamente no TRD por ser derivado de um ADR aceito. O segundo é um conflito entre dois documentos de entrada — nenhum dos quais este agente tem escopo para alterar — e foi registrado como ponto a validar, sem escolha de lado.

### Ajustes Aplicados Diretamente no TRD

- ADJ-TRD-001: Realinhamento da API síncrona `validacao-api` → `tarifacao-svc` de REST/JSON com API key para gRPC com contrato `.proto` e mTLS, na tabela de APIs (seção 8) e no diagrama Mermaid (seção 19), conforme ADR-0002.
- ADJ-TRD-002: Seção 10 (Arquitetura de Dados) passou a nomear explicitamente o conflito de retenção de `validacoes` entre NFRD-RET-01 (5 anos) e Data Model (24 meses), em vez de afirmar 24 meses como decidido.
- ADJ-TRD-003: Seção 22 (Pontos a Validar) e Controle de Versão (nova linha v0.2) atualizados para registrar os dois ajustes acima e o ponto pendente.

### Principais Riscos Remanescentes

- Decisão de retenção de `validacoes` pendente pode chegar ao comitê de segunda sem posição técnica fechada, atrasando a arquitetura de dados de liquidacao/tarifacao se essas áreas dependerem do prazo final.
- Se o comitê decidir 5 anos (NFRD), o expurgo mensal automático do Data Model e o dimensionamento de `validacao_db` precisam ser revistos — não avaliados neste TRD por dependerem da decisão.

### Principais Recomendações

- Levar o conflito NFRD-RET-01 x Data Model ao comitê de arquitetura de segunda como pauta explícita, com decisão de stakeholder (produto, compliance, time de dados).
- Após a decisão, disparar nova validação do TRD para fechar VAL-TRD-01 e permitir parecer Aprovado.
- Confirmar com a equipe de tarifacao-svc a definição do pacote/versionamento do contrato `.proto` (`tarifas.v1`) antes do início da sprint 14.

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| TRD | docs/product/trd/trd.md | Encontrado |
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| ADRs | docs/product/adr/ (0001-0004) | Encontrado |
| DDD | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Context Map | docs/product/ddd/context-map/ | Não Encontrado |
| Modules | docs/product/modules/README.md | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Glossário | docs/product/glossary/ | Não Encontrado |

---

## 2. Baseline Técnico Esperado

| Código | Item Esperado | Fonte | Deve Aparecer no TRD? | Status |
|---|---|---|---|---|
| BASE-TRD-001 | Comunicação síncrona interna em gRPC com contrato `.proto` | ADR-0002 | Sim | Corrigido |
| BASE-TRD-002 | Banco por bounded context, sem escrita cruzada | ADR-0001 | Sim | Coberto |
| BASE-TRD-003 | Tokenização do PAN no gateway, ambiente fora do CDE | ADR-0003 | Sim | Coberto |
| BASE-TRD-004 | RabbitMQ como broker de eventos, DLQ por consumidor, idempotência por `event_id` | ADR-0004 | Sim | Coberto |
| BASE-TRD-005 | Retenção de `validacoes` definida sem ambiguidade | NFRD-RET-01, Data Model | Sim | Não Coberto (conflito) |

---

## 3. Validação da Estrutura do TRD

| Seção | Presente? | Status | Ação Aplicada |
|---|---|---|---|
| Introdução | Sim | OK | — |
| Objetivo do Documento | Sim | OK | — |
| Referências | Sim | OK | — |
| Consolidação Técnica dos Insumos | Sim | OK | — |
| Visão Técnica da Solução | Sim | OK | — |
| Estilo Arquitetural | Sim | OK | — |
| Módulos e Deployables | Sim | OK | — |
| Arquitetura de APIs | Sim | Corrigido | Protocolo/autenticação realinhados ao ADR-0002 |
| Arquitetura de Eventos e Mensageria | Sim | OK | — |
| Arquitetura de Dados | Sim | Corrigido | Conflito de retenção explicitado |
| Arquitetura de Integração | Sim | OK | — |
| Segurança Técnica | Sim | OK | — |
| Compliance e Privacidade | Sim | OK | — |
| Observabilidade | Sim | OK | — |
| Resiliência, Performance e Escalabilidade | Sim | Revisar | Timeout de 150 ms na chamada síncrona não foi revisto para o novo protocolo gRPC; ver VAL-TRD-01 abaixo não se aplica — registrar como achado (FIND-TRD-001) |
| Ambientes, Deploy e Configuração | Sim | OK | — |
| CI/CD e Qualidade Técnica | Sim | OK | — |
| Operação e Suporte | Sim | OK | — |
| Diagramas Técnicos | Sim | Corrigido | Rótulo do diagrama realinhado a gRPC |
| Matriz de Rastreabilidade | Sim | OK | — |
| Riscos Técnicos | Sim | OK | — |
| Pontos a Validar | Sim | Corrigido | VAL-TRD-01 adicionado |
| Anexos | Sim | OK | — |

---

## 4. Cobertura PRD → TRD

| Item PRD | Descrição | Seção TRD | Status | Ação |
|---|---|---|---|---|
| PRD-01 | Validação de embarque em <1s percebido | 5, 7, 15 | Coberto | — |
| PRD-02 | Compensação diária D+1 entre operadoras | 9, 11 | Coberto | — |
| PRD-03 | Extrato de viagens no app | 8 | Coberto | — |
| Restrição PCI DSS 4.0.1 (PAN fora da Axis) | 12, 13 | Coberto | — |
| Restrição integração temporal 60 min | 5 (implícito via FRD-TAR-01) | Parcial | Ponto a Validar: TRD não detalha tecnicamente a janela de 60 min (cache, TTL); recomenda-se detalhamento em nova revisão, não crítico para o comitê de segunda |

---

## 5. Cobertura FRD → TRD

| Item FRD | Descrição | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| FRD-VAL-01 | Registrar validação e publicar evento | Seções 5, 7, 9 (`ValidacaoRegistrada.v1`) | Coberto | — |
| FRD-TAR-01 | Calcular tarifa com integração temporal | Seções 7, 8 (chamada síncrona) | Coberto | Protocolo corrigido para gRPC (ADJ-TRD-001) |
| FRD-LIQ-01 | Consolidar e gerar arquivo D+1 | Seções 9, 11 | Coberto | — |
| FRD-EXT-01 | Expor extrato ao app | Seção 8 (`GET /v1/extrato`) | Coberto | — |

---

## 6. Cobertura NFRD → TRD

| Item NFRD | Categoria | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| NFRD-OBS-01 | Observabilidade | Seção 14 (logs, correlation_id, RED, alerta p99) | Coberto | — |
| NFRD-OBS-02 | Observabilidade | Seção 14 (liveness/readiness) | Coberto | — |
| NFRD-SEC-01 | Segurança | Seções 12, 13 (token apenas, PAN nunca recebido) | Coberto | — |
| NFRD-RET-01 | Retenção | Seção 10 | Não Coberto / Conflito | Registrado como VAL-TRD-01; TRD não pode afirmar 5 anos nem 24 meses sem decisão |

---

## 7. Validação ADR → TRD

| ADR | Decisão | TRD Alinhado? | Status | Ação |
|---|---|---|---|---|
| ADR-0001 | Banco por bounded context, sem escrita cruzada | Sim | OK | — |
| ADR-0002 | gRPC interno com `.proto`, REST/fila na borda externa | Não (antes da correção) | Corrigido | ADJ-TRD-001: API interna migrada de REST/JSON para gRPC |
| ADR-0003 | Tokenização do PAN no gateway, Axis fora do CDE | Sim | OK | — |
| ADR-0004 | RabbitMQ, DLQ por consumidor, idempotência por `event_id` | Sim | OK | — |

---

## 8. Validação DDD / Modules → TRD

| Item | Tipo | Fonte | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|---|
| Validação | Bounded Context (Core) | DDD | Seções 5, 7 | Coberto | — |
| Tarifação | Bounded Context (Core) | DDD | Seções 5, 7 | Coberto | — |
| Liquidação | Bounded Context (Supporting) | DDD | Seções 7, 9, 11 | Coberto | — |
| `ValidacaoRegistrada.v1` | Evento (Published Language) | DDD/Modules | Seção 9, produtor validacao-api, consumidores tarifacao-svc e liquidacao-worker | Coberto | — |
| `TarifaCalculada.v1` | Evento (Published Language) | DDD/Modules | Seção 9 | Coberto | — |
| Chamada síncrona validacao-api → tarifacao-svc | Integração interna | Modules | Seção 8 | Coberto | Protocolo corrigido (ADJ-TRD-001) |

---

## 9. Validação da Arquitetura Técnica

| Critério | Status | Problema | Ação |
|---|---|---|---|
| Coesão | OK | — | — |
| Acoplamento | Corrigido | Acoplamento síncrono via REST/API key contrariava padrão gRPC do ADR-0002 | Realinhado (ADJ-TRD-001) |
| Evolução | OK | — | — |
| Resiliência | OK | — | — |
| Segurança | OK | — | — |
| Observabilidade | OK | — | — |
| Compliance | Revisar | Retenção de dado pessoal (`validacoes`) indefinida entre 24 meses e 5 anos | Registrado em VAL-TRD-01 |
| Deploy | OK | — | — |
| Operação | OK | — | — |

---

## 10. Validação de APIs

| API | Produtor | Consumidor | Problema | Status | Ação |
|---|---|---|---|---|---|
| `tarifas.v1.TarifaService/Calcular` | tarifacao-svc | validacao-api | Estava como REST/JSON com API key, contrariando ADR-0002 | Corrigido | ADJ-TRD-001 |
| `GET /v1/extrato` | validacao-api | App do passageiro | — | OK | — |

---

## 11. Validação de Eventos e Mensageria

| Evento | Produtor | Consumidores | Problema | Status | Ação |
|---|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | — | OK | — |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | — | OK | — |

---

## 12. Validação da Arquitetura de Dados

| Item | Problema | Status | Ação |
|---|---|---|---|
| Retenção de `validacoes` | NFRD-RET-01 (5 anos) conflita com Data Model (24 meses, expurgo mensal, revisão 2026-09-18) | Ponto a Validar | Registrado como VAL-TRD-01; TRD passou a citar o conflito em vez de afirmar um valor |
| Ownership por contexto | Nenhum | OK | — |

---

## 13. Validação de Segurança, Privacidade e Compliance

| Área | Problema | Status | Ação |
|---|---|---|---|
| Segurança | Autenticação da API interna estava com API key, não mTLS | Corrigido | ADJ-TRD-001 alinhou à seção 12 (mTLS) |
| Privacidade | — | OK | — |
| Compliance | Retenção do dado pessoal `validacoes` indefinida | Ponto a Validar | VAL-TRD-01 |

---

## 14. Validação de Observabilidade e Operação

| Item | Problema | Status | Ação |
|---|---|---|---|
| Logs | — | OK | — |
| Métricas | — | OK | — |
| Traces | Não há tracing distribuído explícito além de `correlation_id` | Ponto a Validar (não bloqueante) | Não corrigido — não há insumo suficiente para prescrever ferramenta de tracing |
| Health Checks | — | OK | — |
| Alertas | — | OK | — |
| Runbooks | Não há runbook detalhado, apenas plantão comercial | Ponto a Validar (não bloqueante) | Não corrigido — fora do escopo desta rodada, não citado no pedido do usuário |

---

## 15. Validação de Resiliência, Performance e Escalabilidade

| Item | Problema | Status | Ação |
|---|---|---|---|
| Performance | Timeout de 150 ms foi definido para a chamada REST original; não há confirmação de que o mesmo valor é adequado para gRPC | Achado (não corrigido) | FIND-TRD-001 — ajuste de timeout por protocolo é decisão de engenharia, não derivável apenas dos insumos documentais |
| Escalabilidade | — | OK | — |
| Resiliência | — | OK | — |
| Idempotência | Consumidores de eventos idempotentes por `event_id` (ADR-0004); chamada gRPC síncrona não descreve idempotência, mas é leitura (cálculo de tarifa), sem necessidade | OK | — |
| Timeouts e Retries | Retry de eventos definido; não há retry declarado para a chamada síncrona gRPC | Ponto a Validar (não bloqueante) | Não corrigido — decisão de engenharia sobre política de retry síncrono |

---

## 16. Validação dos Diagramas Técnicos

| Diagrama | Presente? | Qualidade | Status | Ação |
|---|---|---|---|---|
| Architecture Overview | Sim (Mermaid único, seção 19) | Parcial | Corrigido | Rótulo da aresta API→TAR corrigido de REST/JSON para gRPC (ADJ-TRD-001) |
| Container Diagram | Não | — | Ponto a Validar | Não corrigido — geração de diagrama C4 completo excede o ajuste incremental seguro |
| Component Diagram | Não | — | Ponto a Validar | Não corrigido |
| Deployment Diagram | Não | — | Ponto a Validar | Não corrigido |
| Data Flow Diagram | Não | — | Ponto a Validar | Não corrigido |
| Event Flow Diagram | Parcial (implícito no flowchart) | Parcial | OK | — |
| Security Boundary Diagram | Não | — | Ponto a Validar | Não corrigido |
| Compliance Flow Diagram | Não | — | Ponto a Validar | Retenção pendente (VAL-TRD-01) torna prematuro desenhar o fluxo de compliance de dados |

---

## 17. Ajustes Aplicados no TRD

| ID | Seção do TRD | Tipo de Ajuste | Descrição do Ajuste | Fonte Utilizada |
|---|---|---|---|---|
| ADJ-TRD-001 | 8. Arquitetura de APIs; 19. Diagramas Técnicos | Correção | Chamada síncrona validacao-api → tarifacao-svc realinhada de REST/JSON + API key para gRPC com contrato `.proto` e mTLS; aresta do diagrama Mermaid atualizada | ADR-0002 |
| ADJ-TRD-002 | 10. Arquitetura de Dados | Conteúdo/Rastreabilidade | Texto passou a nomear o conflito de retenção de `validacoes` entre NFRD-RET-01 e Data Model, em vez de afirmar 24 meses como decidido | NFRD-RET-01, Data Model |
| ADJ-TRD-003 | 22. Pontos a Validar; Controle de Versão | Estrutura/Rastreabilidade | Tabela de Pontos a Validar preenchida com VAL-TRD-01; nova linha v0.2 no Controle de Versão | Consolidação dos ajustes acima |

---

## 18. Achados Não Corrigidos

| ID | Severidade | Seção | Problema | Motivo de não correção | Recomendação |
|---|---|---|---|---|---|
| FIND-TRD-001 | Baixa | 15. Resiliência, Performance e Escalabilidade | Timeout de 150 ms mantido da chamada REST original, sem confirmação de adequação para gRPC | Ajuste de timeout é decisão de engenharia (não é derivável apenas dos insumos documentais) | Engenharia deve revalidar o timeout de 150 ms para o novo protocolo gRPC antes do início da sprint 14 |
| FIND-TRD-002 | Média | 19. Diagramas Técnicos | Ausência de Container/Component/Deployment/Data Flow/Security Boundary diagrams | Gerar esses diagramas do zero excede correção incremental segura e pode introduzir decisões não documentadas | Time de arquitetura deve produzir os diagramas complementares antes de considerar o TRD completo para C4 |
| FIND-TRD-003 | Baixa | 4. PRD, item de integração temporal | TRD não detalha tecnicamente a janela de 60 minutos (cache/TTL) exigida pelo PRD | Insumos não descrevem a implementação técnica da janela; inventar seria extrapolar | Detalhar em próxima revisão do TRD com insumo de engenharia de tarifacao |

---

## 19. Conflitos Arquiteturais

| ID | Fonte A | Fonte B | Conflito | Impacto | Recomendação |
|---|---|---|---|---|---|
| ARCH-CONFLICT-001 | NFRD-RET-01 (Retenção de validações de embarque: 5 anos para auditoria das operadoras) | Data Model (`validacoes`: 24 meses com expurgo mensal automático, revisão do time de dados de 2026-09-18) | Os dois documentos de entrada definem prazos de retenção incompatíveis para a mesma entidade (`validacoes`); a atualização recente do Data Model não harmonizou a NFRD | Bloqueia a decisão final de arquitetura de dados e política de expurgo; decidir um lado sem aval de stakeholder pode violar contrato de auditoria com operadoras (se ficar em 24 meses) ou reter dado pessoal além do necessário sob LGPD (se ficar em 5 anos) | Levar ao comitê de arquitetura de segunda como pauta explícita; decisão de produto + compliance + time de dados; após decidido, atualizar NFRD ou Data Model (fora do escopo deste agente) e então fechar VAL-TRD-01 |

---

## 20. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-TRD-01 | Retenção de `validacoes` indefinida entre 24 meses (Data Model) e 5 anos (NFRD-RET-01) | NFRD-RET-01 vs Data Model | Bloqueia arquitetura de dados/expurgo final; risco de auditoria ou de retenção excessiva de dado pessoal | Decisão de stakeholder no comitê de segunda; ver também ARCH-CONFLICT-001 |
| VAL-TRD-02 | Janela de integração temporal de 60 minutos (PRD) sem detalhamento técnico (cache/TTL) no TRD | PRD-01/PRD-03, FRD-TAR-01 | Baixo — não bloqueia a sprint 14, mas afeta o desenho de tarifacao-svc | Detalhar em revisão futura com insumo de engenharia |

---

## 21. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Seções obrigatórias avaliadas | 23 |
| Seções adicionadas ao TRD | 0 (todas já existiam; 2 seções tiveram conteúdo corrigido) |
| Ajustes aplicados diretamente | 3 |
| Achados críticos | 0 |
| Achados altos | 0 |
| Achados médios | 1 |
| Achados baixos | 2 |
| Pontos a validar | 2 |
| Conflitos arquiteturais | 1 |

---

## 22. Parecer Final

### Classificação

Aprovado com Ressalvas

### Justificativa

O TRD é implementável para a sprint 14, que começa por `validacao-api` — módulo não bloqueado pelo conflito de retenção. Não há achados críticos nem altos, e o único desalinhamento com ADR aprovada (ADR-0002) foi corrigido diretamente. No entanto, há um conflito arquitetural aberto (ARCH-CONFLICT-001: retenção de `validacoes`) que este agente não tem mandato para resolver por conta própria, pois envolve decisão de produto/compliance e afeta diretamente arquitetura de dados e conformidade regulatória. Por isso o parecer não é "Aprovado" — a alegação do solicitante de que os insumos "estão tudo alinhados" não se sustenta neste ponto específico.

### Condições para Aprovação

- Resolver ARCH-CONFLICT-001 / VAL-TRD-01 (retenção de `validacoes`) em decisão de stakeholder no comitê de segunda ou em fórum equivalente.
- Atualizar o documento fonte pertinente (NFRD ou Data Model, conforme a decisão) fora do escopo deste agente, e então submeter o TRD a nova validação para fechar o ponto.
- Confirmar com engenharia o timeout da chamada gRPC (FIND-TRD-001) antes do início da implementação de tarifacao-svc.

### Próximos Passos Recomendados

- Revisar os ajustes aplicados no TRD (ADJ-TRD-001 a 003).
- Validar VAL-TRD-01 e VAL-TRD-02 com arquitetura, produto, compliance e time de dados.
- Resolver ARCH-CONFLICT-001 antes de fechar a arquitetura de dados de `validacoes`.
- Submeter o TRD ajustado para nova validação após a decisão do comitê de segunda.
