# DDD Validation Report - Embarque Fácil

**Produto:** Embarque Fácil
**Versão do Relatório:** v1.0
**Data:** 2026-09-28
**Status:** Final
**Artefatos Validados:** Subdomínios, Bounded Contexts, Context Map, Glossário, Data Model, ADRs

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-28 | Validação crítica da modelagem atual frente a duas mudanças solicitadas pelo time de backend (promover Conformidade PCI a Core; mover a tabela `carteira` para o contexto Recarga) |

---

## Sumário Executivo

### Parecer Final

**Reprovado** — não para a modelagem vigente em si, mas para a aplicação das duas mudanças solicitadas. Nenhuma das duas está apoiada pelos insumos (PRD, NFRD, ADR-0002, ADR-0003) e uma delas colide diretamente com uma ADR aceita. Além disso, a validação encontrou um conflito arquitetural pré-existente, independente do pedido, que precisa ser resolvido antes de qualquer alteração de fronteira.

### Síntese

O time de backend pediu duas mudanças e pediu que fossem aplicadas diretamente em `docs/product/ddd/` e `docs/product/data-model/data-model.md`. Nenhuma correção foi aplicada. Conforme §4.2 da definição deste agente, correção direta é vedada quando "a correção exigir decisão de produto", "a correção mudar ownership de dados sem evidência suficiente" ou "a correção alterar ADR aprovada" — as duas mudanças pedidas se enquadram nesses critérios, cada uma por um motivo diferente:

1. **Promover Conformidade PCI de Generic para Core** — a justificativa apresentada ("é exigência regulatória e a auditoria do QSA é o que mais dá trabalho") é exatamente o padrão que a Regra do Passo 3 deste agente bloqueia: *"Compliance sozinho não transforma subdomínio em Core"* e *"Complexidade técnica/operacional sozinha não transforma subdomínio em Core"*. O PRD contradiz a promoção de forma explícita: *"conformidade PCI [é] necessária, mas não diferencia o produto"* (`docs/product/prd/prd.md`, §Diferencial). O NFRD trata PCI como controle técnico contratado de terceiro certificado (NFR-03), não como capacidade de domínio proprietária. Não há, em nenhum insumo, evidência de diferenciação competitiva — critério exigido para Core.
2. **Mover a tabela `carteira` (saldo) para o contexto Recarga** — a justificativa ("é a recarga que mais mexe em saldo") usa frequência de escrita como critério de ownership, o que não é o critério de DDD (o critério é a raiz de agregado que protege a invariante, não quem gera mais eventos de escrita). Os insumos mostram o oposto do que foi pedido: `docs/product/ddd/bounded-contexts/carteira/README.md` define `Carteira` como agregado raiz com `Movimentacao` como entidade interna e `Saldo` como objeto de valor — mover a tabela quebraria essa fronteira de consistência transacional. A ADR-0002 (schema por bounded context, joins proibidos) trata mudança de ownership de schema como decisão arquitetural, não ajuste editorial. E a ADR-0003, aceita em 2026-04-14, já estabeleceu o oposto do que o pedido presume: Recarga **não é** bounded context próprio, é módulo interno do BC Carteira — não existe hoje um "contexto Recarga" com fronteira e ownership próprios para o qual mover a tabela.

### Principais Riscos

- Promover PCI a Core sem evidência de diferenciação distorce prioridade de investimento e sinaliza (incorretamente) que a tokenização de cartão é vantagem competitiva do produto, quando o próprio PRD diz o contrário.
- Mover `carteira` para "contexto Recarga" quebraria a fronteira transacional do agregado `Carteira` (débito de tarifa e crédito de recarga deixariam de ser atômicos com o saldo) e violaria ADR-0002 (um schema por contexto, sem joins cruzados) sem uma ADR nova que justifique a mudança.
- **Conflito arquitetural pré-existente, não introduzido por este pedido:** `docs/product/ddd/ddd-segmentation.md`, `docs/product/ddd/context-map/README.md` e `docs/product/ddd/bounded-contexts/recarga/README.md` ainda tratam Recarga como bounded context confirmado (BC-03) com evento `RecargaConfirmada` como Published Language — mas a ADR-0003 (aceita, posterior) diz que Recarga é módulo interno da Carteira e que `RecargaConfirmada` é interno, não Published Language. Isso é uma inconsistência ativa na documentação, registrada abaixo como Conflito Arquitetural, independente do pedido do time de backend.

### Principais Recomendações

- Não aplicar as duas mudanças como pedido. Se o time de backend quiser reabrir a classificação de PCI ou o ownership do saldo, o caminho é uma decisão de produto/arquitetura registrada em ADR — não um ajuste direto do `ddd-validator`.
- Resolver primeiro o conflito ADR-0003 x artefatos DDD (Recarga como BC pleno vs. módulo interno) antes de discutir para onde a tabela `carteira` iria, porque a resposta depende de qual modelo está valendo.
- Se a dor real é o esforço da auditoria do QSA, tratar como iniciativa operacional/processo (ex.: automação de evidências), não como reclassificação de subdomínio — a classificação Core/Supporting/Generic mede diferenciação de negócio, não esforço operacional.

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| TRD | docs/product/trd/trd.md | Encontrado |
| ADRs | docs/product/adr/ (0001, 0002, 0003) | Encontrado |
| Segmentation | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Subdomínios | docs/product/ddd/subdomains/ | Encontrado |
| Bounded Contexts | docs/product/ddd/bounded-contexts/ | Encontrado |
| Context Map | docs/product/ddd/context-map/README.md | Encontrado |
| Ubiquitous Language | docs/product/glossary/ubiquitous-language.md | Encontrado |
| Modules | docs/product/modules/ | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Diagramas C4 | docs/product/ddd/diagrams/ | Encontrado |

---

## 3. Validação de Subdomínios

| Subdomínio | Classificação Atual | Classificação Recomendada | Status | Justificativa |
|---|---|---|---|---|
| Validação de Embarque | Core | Core | OK | Diferenciação explícita no PRD (tarifação + integração temporal offline). |
| Carteira Digital | Supporting | Supporting | OK | Apoia o core sem ser o diferencial (mantém saldo). |
| Recarga | Supporting | Supporting | OK | Crédito via Pix, sem diferenciação declarada. |
| **Conformidade PCI** | Generic | **Generic (manter)** | **Ponto a Validar** | Mudança pedida para Core não tem evidência de diferenciação competitiva; PRD diz explicitamente o contrário. Compliance e carga operacional de auditoria, isoladamente, não promovem a Core (regra do Passo 3). Recomenda-se manter Generic; se o time discordar, abrir ADR de produto justificando diferenciação, não editar a segmentação diretamente. |
| Notificações | Generic | Generic | OK | Push é commodity. |

---

## 5. Validação de Bounded Contexts

| Bounded Context | Linguagem Própria | Regras Próprias | Ciclo de Vida | Ownership | Integrações | Decisão |
|---|---|---|---|---|---|---|
| Validação | Sim | Sim | Sim | Sim (schema `validacao`) | Sim | OK |
| Carteira | Sim | Sim | Sim | Sim (schema `carteira`: `carteira`, `movimentacao`) | Sim | OK |
| Recarga | Parcial | Parcial | Parcial | Sim (schema `recarga`) — **mas conflita com ADR-0003** | Sim | **Conflito Arquitetural** (ver §15) |
| Notificações | Sim | — | Stateless (read model via evento) | Justificativa de stateless presente | Sim | OK |

---

## 6. Validação do Context Map

| Origem | Destino | Padrão Atual | Padrão Recomendado | Status | Justificativa |
|---|---|---|---|---|---|
| Validação → Carteira | Published Language (`EmbarqueRegistrado` v1) | mantém | OK | — | Consistente com bounded-contexts/carteira/README.md. |
| Recarga → Carteira | Published Language (`RecargaConfirmada` v1) | **Revisar** | Conflito Arquitetural | ADR-0003 diz que `RecargaConfirmada` é evento interno ao BC Carteira (Recarga é módulo interno), não Published Language entre dois BCs. O context-map ainda modela como se Recarga fosse BC externo publicando para Carteira. |
| Carteira → Notificações | Published Language | mantém | OK | — | |
| Provedor Pix (externo) → Recarga | Anti-Corruption Layer | mantém | OK | — | Adequado para modelo externo instável (webhook de PSP). |

---

## 8. Validação de Ownership de Dados

| Dado | Dono Atual | Problema | Status | Recomendação |
|---|---|---|---|---|
| `carteira` (saldo) | Carteira (schema `carteira`) | Pedido de mover para "contexto Recarga" | **Ponto a Validar / Não aplicado** | Manter em Carteira. `Saldo` é objeto de valor do agregado raiz `Carteira` (bounded-contexts/carteira/README.md); mover a tabela quebra a fronteira transacional do agregado e contraria ADR-0002 (um schema por contexto). Além disso, hoje "contexto Recarga" não é um bounded context com ownership próprio segundo ADR-0003 — é módulo interno de Carteira, o que torna o pedido, na prática, "mover a tabela de dentro do próprio contexto que já é dono dela". Critério de frequência de escrita ("é a recarga que mais mexe em saldo") não é critério de DDD para ownership; o critério é qual agregado protege a invariante do saldo. |
| `movimentacao` | Carteira | — | OK | Consistente com o agregado. |
| `recarga` | Recarga (schema `recarga`) | Ownership de schema próprio pressupõe Recarga como BC pleno | **Conflito Arquitetural** | Depende da resolução do conflito ADR-0003 x artefatos DDD (§15). Se Recarga for confirmado como módulo interno, o schema `recarga` deveria estar sob o mesmo domínio transacional de `carteira`, não separado. |

---

## 12. Validação de Rastreabilidade

| Decisão DDD | Evidência | Status | Observação |
|---|---|---|---|
| Conformidade PCI = Generic | PRD §Diferencial, NFRD NFR-03 | OK | Ambos os insumos apontam Generic; pedido de Core carece de evidência. |
| Recarga = Supporting, BC próprio com Published Language | ddd-segmentation.md, context-map, bounded-contexts/recarga/README.md | **Conflito Arquitetural** | Contradiz ADR-0003 (Aceita), que trata Recarga como módulo interno de Carteira, sem deployable próprio e sem Published Language. |
| Ownership de `carteira` em Carteira | data-model.md, bounded-contexts/carteira/README.md, ADR-0002 | OK | Pedido de mover para Recarga não tem evidência nos insumos; contraria ADR-0002 e ADR-0003. |

---

## 13. Achados de Validação

| ID | Severidade | Artefato | Problema | Impacto | Recomendação |
|---|---|---|---|---|---|
| FIND-DDD-001 | Alta | docs/product/ddd/ddd-segmentation.md (§1.2) | Pedido de reclassificar Conformidade PCI de Generic para Core sem evidência de diferenciação competitiva; contraria PRD §Diferencial e a regra "compliance sozinho não transforma subdomínio em Core". | Distorce priorização de investimento e mensagem de produto. | Não aplicar. Manter Generic. Se o time discordar, abrir decisão de produto com evidência de diferenciação real, não só carga de auditoria. |
| FIND-DDD-002 | Crítica | docs/product/data-model/data-model.md | Pedido de mover a tabela `carteira` para o contexto Recarga usando frequência de escrita como critério; quebra a fronteira transacional do agregado `Carteira` e viola ADR-0002 (schema por bounded context). | Ownership de dados inseguro; risco de escrita cruzada entre contextos e perda de atomicidade do saldo. | Não aplicar. Manter `carteira`/`movimentacao` no schema `carteira`, sob ownership do BC Carteira. |
| FIND-DDD-003 | Crítica | docs/product/ddd/context-map/README.md, ddd-segmentation.md (§4.1, BC-03), bounded-contexts/recarga/README.md | Context map e segmentação tratam Recarga como bounded context confirmado com evento `RecargaConfirmada` como Published Language; ADR-0003 (aceita, posterior) diz que Recarga é módulo interno do BC Carteira, sem deployable próprio, e que `RecargaConfirmada` é evento interno. | Context map contradiz ADR aceita — inconsistência estrutural que impede derivar módulos/deployables com segurança a partir da segmentação atual. | Reconciliar os artefatos com a ADR-0003 numa próxima execução do `ddd-architect`, ou abrir ADR revogando/atualizando a ADR-0003 se a intenção for reverter a decisão. Enquanto não resolvido, tratar como Conflito Arquitetural bloqueante para qualquer mudança de ownership envolvendo Carteira/Recarga — inclusive o pedido de mover `carteira` para Recarga, que pressupõe o modelo contrário ao da ADR vigente. |

---

## 14. Ajustes Aplicados

| ID | Artefato | Ajuste | Fonte |
|---|---|---|---|
| — | — | Nenhum ajuste aplicado diretamente. As duas mudanças pedidas exigem decisão de produto/arquitetura (§4.2) e não foram executadas. | — |

---

## 15. Conflitos Arquiteturais

| ID | Fonte A | Fonte B | Conflito | Impacto | Recomendação |
|---|---|---|---|---|---|
| CONF-DDD-001 | ADR-0003 (Aceita, 2026-04-14) — Recarga é módulo interno de Carteira, sem deployable próprio, `RecargaConfirmada` é evento interno | ddd-segmentation.md §4.1 (BC-03 Recarga = "Confirmar"), context-map/README.md (Recarga → Carteira via Published Language), bounded-contexts/recarga/README.md (Recarga como BC com ownership de schema próprio) | Os artefatos de segmentação/context-map/bounded-context ainda modelam Recarga como bounded context pleno; a ADR aceita diz o oposto. | Bloqueia decisão segura sobre para onde qualquer dado relacionado a saldo/recarga deveria ir — inclusive o pedido do time de backend de mover `carteira` para "contexto Recarga", que pressupõe que esse contexto existe como tal. | Reexecutar `ddd-architect` para alinhar os artefatos à ADR-0003, ou registrar nova ADR se a intenção do time for reverter a ADR-0003. Este relatório não decide qual dos dois modelos prevalece — é decisão de arquitetura/produto. |
| CONF-DDD-002 | PRD §Diferencial ("conformidade PCI são necessárias, mas não diferenciam o produto") + NFRD NFR-03 (PCI como controle técnico via provedor certificado) | Pedido do time de backend de promover Conformidade PCI a Core por ser "exigência regulatória" e "o que mais dá trabalho na auditoria do QSA" | O pedido usa critério de esforço operacional/compliance, que o PRD e a regra de classificação do Passo 3 excluem explicitamente como base suficiente para Core. | Se aplicado, a classificação deixaria de refletir a estratégia declarada em PRD. | Não promover a Core sem nova evidência de diferenciação. Se a dor é o esforço de auditoria, tratar como melhoria operacional (ex.: automação de evidências PCI DSS 4.0.1), não reclassificação de subdomínio. |

---

## 16. Pontos a Validar

| Código | Ponto | Impacto | Recomendação |
|---|---|---|---|
| VAL-DDD-01 | Time de backend quer promover Conformidade PCI de Generic para Core, justificando por ser exigência regulatória e pela carga de trabalho da auditoria do QSA. **Não aplicado**: exigência regulatória e esforço/complexidade de compliance, isoladamente, não transformam subdomínio em Core (regra do Passo 3 da validação; PRD §Diferencial diz explicitamente que conformidade PCI "não diferencia o produto"). | Prioridade de investimento e narrativa de produto distorcidas se aplicado sem evidência. | Decisão de produto — só reclassificar mediante evidência de diferenciação competitiva real, não compliance/esforço isolado. |
| VAL-DDD-02 | Time de backend quer mover a tabela `carteira` (saldo) do bounded context Carteira para o contexto Recarga, justificando por frequência de escrita ("é a recarga que mais mexe em saldo"). **Não aplicado**: frequência de escrita não é critério de ownership em DDD (o critério é o agregado que protege a invariante); `carteira` é dado interno do agregado raiz Carteira (bounded-contexts/carteira/README.md) e a mudança violaria ADR-0002 (um schema por bounded context, joins proibidos). | Fronteira transacional do agregado Carteira; ownership de dados; risco de escrita cruzada entre contextos. | Decisão de arquitetura — depende primeiro da resolução do VAL-DDD-03/CONF-DDD-001 (o que é "contexto Recarga" hoje, segundo a ADR-0003 vigente), e não deve seguir o critério de frequência de escrita. |
| VAL-DDD-03 | Conflito entre ADR-0003 e os demais artefatos DDD sobre a natureza de Recarga (BC pleno vs. módulo interno). | Toda decisão futura de ownership envolvendo Carteira/Recarga. | Reexecutar `ddd-architect` para reconciliar, ou abrir nova ADR. |

---

## 17. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Subdomínios avaliados | 5 |
| Bounded contexts avaliados | 4 |
| Relações de context map avaliadas | 4 |
| Módulos avaliados | 0 (fora de escopo deste pedido) |
| Eventos avaliados | 4 |
| Achados críticos | 2 |
| Achados altos | 1 |
| Achados médios | 0 |
| Achados baixos | 0 |
| Ajustes aplicados | 0 |
| Pontos a validar | 3 |

---

## 18. Parecer Final

### Classificação

**Reprovado** para a aplicação das duas mudanças pedidas pelo time de backend, no estado atual dos insumos.

### Justificativa

Nenhuma das duas mudanças pedidas é uma "correção segura, objetiva e derivada dos próprios documentos" (§4.1 da definição deste agente) — pelo contrário, ambas contrariam os insumos existentes (PRD, NFRD, ADR-0002, ADR-0003) e uma delas (mover `carteira`) pressupõe um modelo de Recarga que a ADR-0003 já invalidou. Aplicar qualquer uma delas diretamente em `docs/product/ddd/` ou `docs/product/data-model/data-model.md`, como solicitado, seria uma correção de decisão de produto/arquitetura sem base nos insumos — exatamente o que a regra 4.2 veda. Além disso, a validação encontrou um conflito arquitetural pré-existente (CONF-DDD-001) que precisa ser resolvido antes de se discutir ownership de dados entre Carteira e Recarga.

A modelagem vigente (sem as duas mudanças pedidas) está coerente nos pontos avaliados, exceto pelo conflito ADR-0003 x artefatos DDD já registrado.

### Condições para Aprovação

- Reclassificação de PCI: apresentar evidência de diferenciação competitiva (não compliance/esforço isolado) e registrar em ADR de produto.
- Mudança de ownership de `carteira`: resolver primeiro CONF-DDD-001 (o que é o contexto Recarga hoje) e, só então, avaliar ownership com base no agregado, não em frequência de escrita.

### Próximos Passos

- Não aplicar as duas mudanças pedidas nos artefatos DDD.
- Levar VAL-DDD-01, VAL-DDD-02 e VAL-DDD-03 para decisão humana (produto/arquitetura).
- Reexecutar `ddd-architect` para reconciliar Recarga com a ADR-0003, ou abrir nova ADR revisitando a ADR-0003.
- Reexecutar esta validação após as decisões acima.
