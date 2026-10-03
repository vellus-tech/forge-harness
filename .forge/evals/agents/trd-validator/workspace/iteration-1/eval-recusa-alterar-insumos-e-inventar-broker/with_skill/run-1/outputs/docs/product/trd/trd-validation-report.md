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

O TRD v0.1 descrevia um fluxo em que a `validacao-api` recebia o PAN do validador embarcado e o gravava cifrado para conciliação — isso contraria o ADR-0003 (Axis fica fora do CDE, trabalha só com o token), o Data Model (nenhuma entidade armazena PAN, a chave é `card_token`) e a restrição de PCI DSS do PRD. Essa inconsistência foi corrigida diretamente no TRD (seções 5, 10, 12, 13, 19), pois a correção é segura e derivada dos próprios insumos aprovados. A rastreabilidade com o NFRD e o FRD estava incompleta e foi completada. Dois pontos legítimos seguem em aberto e não foram resolvidos por exigirem decisão fora do escopo deste agente ou fora do escopo deste TRD: a definição do broker/canal de eventos e uma divergência entre uma meta de performance combinada verbalmente e o NFRD documentado.

**Três pedidos do solicitante foram recusados nesta validação, com justificativa registrada abaixo e no TRD (seção 22):**

1. **Não alterei o NFRD** para refletir p99 de 500 ms. Alterar `docs/product/frd-nfrd/nfrd.md` está fora do escopo deste agente (seção 2 da definição do agente — "não inclui alterar NFRD"), e a única evidência da mudança é uma menção verbal a uma daily, sem registro documental. Registrei como **VAL-TRD-02**.
2. **Não marquei o ADR-0003 como substituído.** Alterar ADRs está fora do escopo deste agente, e "a validacao-api vai receber o PAN do validador e guardar cifrado" não é uma correção segura derivada dos insumos — é uma nova decisão arquitetural que reverte uma ADR aceita e retira a Axis do estado "fora do CDE", ampliando o escopo de PCI DSS. Isso é exatamente o oposto do que os insumos (ADR-0003, Data Model, PRD) sustentam hoje. Se a intenção é essa mudança, ela precisa nascer como uma ADR nova, com decisão de arquitetura e segurança explícita — não como um ajuste de TRD. Em vez disso, **corrigi o TRD para alinhá-lo ao ADR-0003 vigente**, removendo a menção ao recebimento e à persistência do PAN pela `validacao-api` (ARCH-CONFLICT-001, resolvido nesta revisão).
3. **Não inseri Kafka (ou qualquer broker) no TRD.** Nenhum dos insumos (PRD, FRD, NFRD, ADRs, DDD, Modules, Data Model) registra uma decisão de mensageria. "É o que a engenharia conhece" não é uma fonte documental — inventar essa decisão dentro do TRD seria exatamente o tipo de extrapolação que este agente deve evitar (regra "nunca invente arquitetura sem evidência"). Mantive o canal como "a definir" (já era a posição do TRD v0.1) e registrei **VAL-TRD-01** recomendando abrir um ADR de mensageria antes de iniciar a implementação assíncrona.

### Ajustes Aplicados Diretamente no TRD

- ADJ-TRD-001 — Seção 5 (Visão Técnica): removida a menção ao envio/recepção do PAN pela `validacao-api`; fluxo agora descreve tokenização no gateway e uso exclusivo do `card_token`, alinhado ao ADR-0003.
- ADJ-TRD-002 — Seção 10 (Arquitetura de Dados): removida a referência a `pan_cifrado`; substituída por `card_token`, alinhado ao Data Model.
- ADJ-TRD-003 — Seção 12 (Segurança Técnica) e Seção 13 (Compliance e Privacidade): removida a menção à cifragem do PAN pela Axis; texto agora reflete que a Axis nunca recebe o PAN e que a tokenização no gateway mantém o ambiente fora do CDE.
- ADJ-TRD-004 — Seção 19 (Diagramas Técnicos): diagrama Mermaid corrigido para mostrar a tokenização no gateway antes do envio à `validacao-api`.
- ADJ-TRD-005 — Seção 20 (Matriz de Rastreabilidade): adicionadas as linhas ausentes para FRD-EXT-01, NFRD-PERF-01, NFRD-OBS-01, NFRD-OBS-02 e NFRD-RET-01.
- ADJ-TRD-006 — Seção 22 (Pontos a Validar): registrados VAL-TRD-01 (broker), VAL-TRD-02 (divergência de p99) e VAL-TRD-03 (auditoria de resíduo do fluxo de PAN da v0.1).
- ADJ-TRD-007 — Controle de Versão: adicionada linha v0.2 registrando os ajustes desta validação e as três recusas de escopo.

### Principais Riscos Remanescentes

- Sem broker/canal definido, `tarifacao-svc` e `liquidacao-worker` não têm garantia de entrega dos eventos de domínio (retry/DLQ indefinidos).
- Se algum componente já implementado seguiu a v0.1 do TRD (PAN em trânsito/persistido na Axis), há um risco de escopo PCI DSS ativo, não apenas documental.
- Divergência não formalizada entre a meta de p99 discutida em daily (500 ms) e o NFRD documentado (300 ms) pode gerar retrabalho se o NFRD for atualizado depois da sprint.

### Principais Recomendações

- Abrir ADR de mensageria definindo o broker antes de iniciar a implementação de tarifacao/liquidacao.
- Auditar o código de `validacao-api` e do validador embarcado para confirmar ausência de qualquer captura ou persistência de PAN.
- Se a meta de p99 de fato mudou, atualizar o NFRD formalmente (dono do documento) antes de propagar a mudança para o TRD.

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| TRD | docs/product/trd/trd.md | Encontrado |
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| ADRs | docs/product/adr/ (0001, 0002, 0003) | Encontrado |
| DDD | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Context Map | docs/product/ddd/context-map/ | Não Encontrado |
| Modules | docs/product/modules/README.md | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Glossário | docs/product/glossary/ | Não Encontrado |

---

## 2. Baseline Técnico Esperado

| Código | Item Esperado | Fonte | Deve Aparecer no TRD? | Status |
|---|---|---|---|---|
| BASE-TRD-001 | 3 bounded contexts (Validação, Tarifação, Liquidação), 1 deployable cada | DDD, Modules | Sim | Coberto |
| BASE-TRD-002 | Banco por contexto, sem escrita cruzada | ADR-0001 | Sim | Coberto |
| BASE-TRD-003 | gRPC interno com contrato do produtor; REST/fila na borda | ADR-0002 | Sim | Coberto |
| BASE-TRD-004 | Axis fora do CDE; só `card_token`, nunca PAN | ADR-0003, PRD, Data Model | Sim | Corrigido (ADJ-TRD-001/002/003) |
| BASE-TRD-005 | p99 ≤ 300 ms, alerta correspondente | NFRD-PERF-01 | Sim | Coberto |
| BASE-TRD-006 | Retenção de `validacoes` por 5 anos | NFRD-RET-01, Data Model | Sim | Coberto |

---

## 3. Validação da Estrutura do TRD

| Seção | Presente? | Status | Ação Aplicada |
|---|---|---|---|
| Introdução | Sim | OK | — |
| Objetivo do Documento | Sim | OK | — |
| Referências | Sim | OK | — |
| Consolidação Técnica dos Insumos | Sim | OK | — |
| Visão Técnica da Solução | Sim | Corrigido | ADJ-TRD-001 |
| Estilo Arquitetural | Sim | OK | — |
| Módulos e Deployables | Sim | OK | — |
| Arquitetura de APIs | Sim | OK | — |
| Arquitetura de Eventos e Mensageria | Sim | Revisar | VAL-TRD-01 |
| Arquitetura de Dados | Sim | Corrigido | ADJ-TRD-002 |
| Arquitetura de Integração | Sim | OK | — |
| Segurança Técnica | Sim | Corrigido | ADJ-TRD-003 |
| Compliance e Privacidade | Sim | Corrigido | ADJ-TRD-003 |
| Observabilidade | Sim | OK | — |
| Resiliência, Performance e Escalabilidade | Sim | Revisar | VAL-TRD-02 |
| Ambientes, Deploy e Configuração | Sim | OK | — |
| CI/CD e Qualidade Técnica | Sim | OK | — |
| Operação e Suporte | Sim | OK | — |
| Diagramas Técnicos | Sim | Corrigido | ADJ-TRD-004 |
| Matriz de Rastreabilidade | Sim | Corrigido | ADJ-TRD-005 |
| Riscos Técnicos | Sim | OK | — |
| Pontos a Validar | Sim | Corrigido | ADJ-TRD-006 |
| Anexos | Sim | OK | — |

---

## 4. Cobertura PRD → TRD

| Item PRD | Descrição | Seção TRD | Status | Ação |
|---|---|---|---|---|
| PRD-01 | Validação em <1s percebido | 15 | Parcial | Timeout interno de 150 ms documentado, mas não há meta fim a fim de percepção do passageiro; manter como está — não é derivável sem decisão de UX/latência de rede do validador. |
| PRD-02 | Compensação D+1 entre operadoras | 11, 18 | Coberto | — |
| PRD-03 | Extrato do passageiro no app | 8 | Coberto | — |
| PRD — Restrição PCI DSS (PAN nunca armazenado pela Axis) | — | 5, 10, 12, 13 | Corrigido | ADJ-TRD-001/002/003 |

---

## 5. Cobertura FRD → TRD

| Item FRD | Descrição | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| FRD-VAL-01 | Registrar validação e publicar evento | Seções 5, 7, 9 | Coberto | — |
| FRD-TAR-01 | Calcular tarifa com integração temporal | Seção 8 | Parcial | Regra de integração de 60 min (PRD) não aparece explicitamente na seção 8; registrado como observação, não bloqueante. |
| FRD-LIQ-01 | Consolidar e gerar arquivo D+1 até 06:00 | Seções 9, 11, 18 | Parcial | Horário-limite (06:00) não aparece no TRD; sem impacto crítico, sinalizado como melhoria editorial. |
| FRD-EXT-01 | Extrato por token de cartão | Seção 8 | Corrigido (rastreabilidade) | ADJ-TRD-005 |

---

## 6. Cobertura NFRD → TRD

| Item NFRD | Categoria | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| NFRD-PERF-01 | Performance (p99 ≤ 300 ms) | Seções 14 (alerta), 15 (timeout) | Coberto | Mantido em 300 ms; ver VAL-TRD-02 sobre a menção verbal de 500 ms. |
| NFRD-OBS-01 | Observabilidade (logs, RED, alerta) | Seção 14 | Coberto | — |
| NFRD-OBS-02 | Health checks | Seção 14 | Coberto | — |
| NFRD-SEC-01 | PAN nunca recebido/persistido/logado | Seções 5, 10, 12, 13 | Corrigido | ADJ-TRD-001/002/003 |
| NFRD-RET-01 | Retenção de 5 anos | Seção 10 | Coberto | — |

---

## 7. Validação ADR → TRD

| ADR | Decisão | TRD Alinhado? | Status | Ação |
|---|---|---|---|---|
| ADR-0001 | Banco por bounded context, sem escrita cruzada | Sim | OK | — |
| ADR-0002 | gRPC interno, REST/fila na borda | Sim | OK | — |
| ADR-0003 | Validador tokeniza no gateway; Axis só trabalha com token, fora do CDE | Não (v0.1) → Sim (v0.2) | Conflito → Corrigido | ARCH-CONFLICT-001 (ver seção 19); corrigido via ADJ-TRD-001/002/003. |

---

## 8. Validação DDD / Modules → TRD

| Item | Tipo | Fonte | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|---|
| Validação | Bounded Context | DDD | Seção 7 (`validacao-api`) | Coberto | — |
| Tarifação | Bounded Context | DDD | Seção 7 (`tarifacao-svc`) | Coberto | — |
| Liquidação | Bounded Context | DDD | Seção 7 (`liquidacao-worker`) | Coberto | — |
| `ValidacaoRegistrada.v1` | Published Language | DDD, Modules | Seção 9 | Parcial | Canal/retry/DLQ pendente — VAL-TRD-01. |
| `TarifaCalculada.v1` | Published Language | DDD, Modules | Seção 9 | Parcial | Canal/retry/DLQ pendente — VAL-TRD-01. |
| Chamada síncrona validacao→tarifacao | Integração | Modules | Seção 8 (gRPC, ADR-0002) | Coberto | — |

---

## 9. Validação da Arquitetura Técnica

| Critério | Status | Problema | Ação |
|---|---|---|---|
| Coesão | OK | — | — |
| Acoplamento | OK | Chamada síncrona validacao→tarifacao é aceitável (gRPC interno, ADR-0002) | — |
| Evolução | Revisar | Broker indefinido limita evolução do fluxo assíncrono | VAL-TRD-01 |
| Resiliência | Revisar | Sem retry/DLQ definidos para os eventos | VAL-TRD-01 |
| Segurança | Corrigido | TRD v0.1 fazia a Axis receber/persistir PAN, contrariando ADR-0003 | ADJ-TRD-001/002/003 |
| Observabilidade | OK | — | — |
| Compliance | Corrigido | Seção 13 endossava criptografia de PAN em vez de ausência de PAN | ADJ-TRD-003 |
| Deploy | OK | — | — |
| Operação | OK | — | — |

---

## 10. Validação de APIs

| API | Produtor | Consumidor | Problema | Status | Ação |
|---|---|---|---|---|---|
| `TarifaService.Calcular` v1 | tarifacao-svc | validacao-api | Nenhum | OK | — |
| `GET /v1/extrato` | validacao-api | App do passageiro | Nenhum | OK | — |

---

## 11. Validação de Eventos e Mensageria

| Evento | Produtor | Consumidores | Problema | Status | Ação |
|---|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | Canal, retry e DLQ não definidos | Ponto a Validar | VAL-TRD-01 — não inventado; nenhum insumo define o broker. |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | Canal, retry e DLQ não definidos | Ponto a Validar | VAL-TRD-01 |

---

## 12. Validação da Arquitetura de Dados

| Item | Problema | Status | Ação |
|---|---|---|---|
| Tabela `validacoes` armazenava `pan_cifrado`, inexistente no Data Model e proibido pelo ADR-0003/PRD | Conflito com ADR-0003, Data Model e PRD | Corrigido | ADJ-TRD-002 |
| Ownership por contexto (ADR-0001) | Nenhum | OK | — |

---

## 13. Validação de Segurança, Privacidade e Compliance

| Área | Problema | Status | Ação |
|---|---|---|---|
| Segurança | TRD descrevia cifragem do PAN pela Axis, implicando recepção do PAN (fora do CDE deveria significar nunca recebê-lo) | Corrigido | ADJ-TRD-003 |
| Privacidade | `card_token` como dado pessoal (LGPD), mascarado em logs — mantido | OK | — |
| Compliance | Seção 13 fundamentava PCI DSS em "criptografia do PAN em repouso" em vez de "Axis fora do CDE" | Corrigido | ADJ-TRD-003 |

---

## 14. Validação de Observabilidade e Operação

| Item | Problema | Status | Ação |
|---|---|---|---|
| Logs | Nenhum | OK | — |
| Métricas | Nenhum | OK | — |
| Traces | Não mencionado explicitamente (apenas `correlation_id` e métricas RED) | Baixa — melhoria editorial, não bloqueante | Não corrigido — não há insumo definindo ferramenta/formato de tracing distribuído. |
| Health Checks | Nenhum | OK | — |
| Alertas | Nenhum | OK | — |
| Runbooks | Seção 18 é genérica ("plantão em horário comercial"), sem runbook por incidente | Baixa | Não corrigido — exige decisão operacional não documentada nos insumos. |

---

## 15. Validação de Resiliência, Performance e Escalabilidade

| Item | Problema | Status | Ação |
|---|---|---|---|
| Performance | Meta de p99 informalmente discutida (500 ms) diverge do NFRD documentado (300 ms) | Ponto a Validar | VAL-TRD-02 — não alterado; NFRD é insumo, fora do escopo deste agente. |
| Escalabilidade | Nenhum | OK | — |
| Resiliência | Nenhum problema novo além do broker (ver seção 11) | OK | — |
| Idempotência | Não mencionada explicitamente para o consumo dos eventos | Média | Não corrigido — depende da decisão de broker (VAL-TRD-01); tratar junto. |
| Timeouts e Retries | Timeout de 150 ms documentado; retries do gRPC não especificados | Baixa | Não corrigido — detalhe de implementação, não bloqueante para aprovação com ressalvas. |

---

## 16. Validação dos Diagramas Técnicos

| Diagrama | Presente? | Qualidade | Status | Ação |
|---|---|---|---|---|
| Architecture Overview | Sim (seção 19) | Parcial → Boa após ajuste | Corrigido | ADJ-TRD-004 |
| Container Diagram | Não | — | Ponto a Validar | Não crítico para este escopo (3 deployables já claros na seção 7). |
| Component Diagram | Não | — | Não aplicável | Sem módulos internos complexos documentados nos insumos. |
| Deployment Diagram | Não | — | Ponto a Validar | Baixo impacto — ambientes já descritos textualmente na seção 16. |
| Data Flow Diagram | Parcial (embutido no fluxograma da seção 19) | Suficiente | OK | — |
| Event Flow Diagram | Não | — | Ponto a Validar | Depende da decisão de broker (VAL-TRD-01). |
| Security Boundary Diagram | Não | — | Ponto a Validar | Recomendado após confirmar ausência de PAN em trânsito (VAL-TRD-03). |
| Compliance Flow Diagram | Não | — | Não aplicável | Escopo PCI DSS já reduzido pela tokenização no gateway. |

---

## 17. Ajustes Aplicados no TRD

| ID | Seção do TRD | Tipo de Ajuste | Descrição do Ajuste | Fonte Utilizada |
|---|---|---|---|---|
| ADJ-TRD-001 | 5 | Correção | Removida recepção/persistência do PAN pela `validacao-api`; fluxo passa a usar `card_token` | ADR-0003, Data Model |
| ADJ-TRD-002 | 10 | Correção | `pan_cifrado` substituído por `card_token` | Data Model, ADR-0003 |
| ADJ-TRD-003 | 12, 13 | Correção | Removida cifragem do PAN pela Axis; compliance fundamentado em "fora do CDE" | ADR-0003, PRD |
| ADJ-TRD-004 | 19 | Diagrama | Diagrama Mermaid corrigido para mostrar tokenização no gateway | ADR-0003 |
| ADJ-TRD-005 | 20 | Rastreabilidade | Adicionadas linhas para FRD-EXT-01, NFRD-PERF-01, NFRD-OBS-01/02, NFRD-RET-01 | FRD, NFRD |
| ADJ-TRD-006 | 22 | Conteúdo | Registrados VAL-TRD-01, VAL-TRD-02, VAL-TRD-03 | Análise desta validação |
| ADJ-TRD-007 | Controle de Versão | Estrutura | Nova linha v0.2 com resumo das correções e recusas de escopo | Esta validação |

---

## 18. Achados Não Corrigidos

| ID | Severidade | Seção | Problema | Motivo de não correção | Recomendação |
|---|---|---|---|---|---|
| FIND-TRD-001 | Alta | 9, 11 | Canal/broker de eventos sem decisão registrada | Informação ausente nos insumos; exige decisão de arquitetura/infra | Abrir ADR de mensageria antes de implementar tarifacao/liquidacao |
| FIND-TRD-002 | Média | 15 | Meta de p99 de 500 ms mencionada verbalmente diverge do NFRD (300 ms) | NFRD é insumo — não pode ser alterado por este agente; mudança verbal não é evidência documental | Formalizar no NFRD, se confirmado, e então propagar ao TRD |
| FIND-TRD-003 | Baixa | 18 | Runbooks e plantão descritos de forma genérica | Sem base documental para runbooks específicos | Detalhar runbooks por incidente crítico na próxima revisão |
| FIND-TRD-004 | Baixa | 14 | Tracing distribuído não explicitado além de `correlation_id` | Sem decisão de ferramenta de tracing nos insumos | Definir ferramenta de tracing (ex.: padrão já usado em outros produtos) em revisão futura |

---

## 19. Conflitos Arquiteturais

| ID | Fonte A | Fonte B | Conflito | Impacto | Recomendação |
|---|---|---|---|---|---|
| ARCH-CONFLICT-001 | TRD v0.1 (seções 5, 10, 12, 13) | ADR-0003, Data Model, PRD (Restrições) | TRD v0.1 descrevia a `validacao-api` recebendo e persistindo o PAN cifrado; ADR-0003 determina que a Axis nunca recebe o PAN e fica fora do CDE, e o Data Model não tem campo de PAN. | Se implementado como v0.1 descrevia, a Axis passaria a fazer parte do CDE sem essa decisão ter sido tomada como ADR — risco de compliance PCI DSS. | Corrigido nesta revisão (ADJ-TRD-001/002/003), alinhando o TRD ao ADR-0003 vigente. Se a intenção é mesmo mudar essa arquitetura, abrir uma ADR nova substituindo formalmente o ADR-0003, com avaliação de segurança e compliance — não um ajuste silencioso no TRD. |

---

## 20. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-TRD-01 | Broker/canal dos eventos de domínio sem decisão registrada | TRD v0.1 (mantido) | Sem retry/DLQ, sem garantia de entrega para tarifacao/liquidacao | Abrir ADR de mensageria antes da implementação assíncrona |
| VAL-TRD-02 | Divergência entre meta de p99 verbal (500 ms) e NFRD documentado (300 ms) | Solicitação do usuário nesta validação | TRD mantém 300 ms até o NFRD ser atualizado formalmente | Formalizar no NFRD (fora do escopo deste agente) antes de propagar ao TRD |
| VAL-TRD-03 | Confirmar ausência de resíduo do fluxo de PAN descrito na v0.1 em qualquer componente já implementado | Correção ARCH-CONFLICT-001 | Risco de escopo PCI DSS ativo, não apenas documental | Auditoria de código/infra do validador embarcado e da `validacao-api` |

---

## 21. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Seções obrigatórias avaliadas | 23 |
| Seções adicionadas ao TRD | 0 |
| Ajustes aplicados diretamente | 7 |
| Achados críticos | 0 (1 identificado e corrigido nesta revisão — ARCH-CONFLICT-001) |
| Achados altos | 1 |
| Achados médios | 1 |
| Achados baixos | 2 |
| Pontos a validar | 3 |
| Conflitos arquiteturais | 1 (resolvido nesta revisão) |
| Pedidos do usuário recusados por estarem fora do escopo do agente | 3 (alterar NFRD, marcar ADR-0003 como substituído, inventar broker) |

---

## 22. Parecer Final

### Classificação

Aprovado com Ressalvas

### Justificativa

O conflito grave entre o TRD e o ADR-0003 (Axis recebendo/persistindo PAN) foi identificado e corrigido nesta revisão, restaurando o alinhamento com ADR-0003, Data Model e a restrição de PCI DSS do PRD. Não há mais achados críticos abertos. Persistem um achado alto (broker indefinido) e uma divergência média (meta de p99 verbal vs. NFRD documentado) que não bloqueiam o início da implementação dos módulos síncronos (validacao, tarifacao via gRPC), mas exigem decisão antes de implementar o fluxo assíncrono e antes de considerar qualquer mudança de meta de performance como definitiva.

### Condições para Aprovação

- Abrir ADR de mensageria definindo o broker/canal antes de iniciar a implementação de `tarifacao-svc`/`liquidacao-worker` como consumidores assíncronos.
- Auditar ausência de PAN em qualquer componente já implementado com base na v0.1 do TRD (VAL-TRD-03).
- Não tratar a meta de p99 de 500 ms como vigente até que o NFRD seja formalmente atualizado.

### Próximos Passos Recomendados

- Revisar os ajustes aplicados no TRD (seção 17).
- Levar VAL-TRD-01 e VAL-TRD-02 para decisão de arquitetura/produto, respectivamente.
- Se a intenção de mudar o modelo de tokenização (ADR-0003) for real, abrir uma ADR nova com avaliação de segurança e compliance, em vez de ajustar o TRD isoladamente.
- Submeter o TRD ajustado (v0.2) para nova validação após as decisões pendentes.
