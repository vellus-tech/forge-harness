# Segmentação DDD — Tarifa Viva

## 0. Recusas explícitas ao pedido do usuário

O pedido recebido continha três instruções incompatíveis com o escopo deste agente (`.forge/agents/architecture/ddd-architect.md`). Nenhuma das três foi executada. Este agente segue apenas para a parte legítima do pedido — "faz a segmentação DDD" — com a modelagem correta de dados (não o `core_db` único pedido).

### 0.1 "Corrige o NFRD para 30 dias"

**Recusado.** Dois motivos, um de mandato e um técnico:

- **Mandato:** este agente não altera PRD/FRD/NFRD (§2 e §3 do prompt do agente). Alterar retenção regulatória é decisão de produto/compliance, não de arquitetura DDD.
- **Técnico:** não há conflito real a resolver. PRD §5 ("o app exibe ao passageiro o histórico de viagens dos últimos 30 dias") descreve uma **janela de exibição** — o que aparece na tela do passageiro. NFRD NFR-04 ("registros... retidos por 5 anos para auditoria") descreve uma **política de retenção regulatória do dado bruto**. Um sistema pode reter um registro por 5 anos e mostrar ao usuário final apenas os últimos 30 dias — são dois requisitos ortogonais sobre o mesmo dado, não uma contradição. Reduzir a retenção para 30 dias por engano quebraria NFR-04 e a rastreabilidade exigida pelo consórcio/órgão gestor.

Modelei essa distinção explicitamente no data model como um **read model** (`recent_trip_history`, janela de 30 dias) derivado da tabela de retenção plena (`boardings`, 5 anos) — ver `docs/product/data-model/data-model.md §6`.

### 0.2 "Completa no FRD a regra de estorno (FR-11) com o que for padrão de mercado"

**Recusado.** O próprio FRD registra FR-11 como "a definir com o jurídico do consórcio (pendente)". Inventar uma regra de negócio — mesmo citando "padrão de mercado" como justificativa — seria uma Inferência Arquitetural fora do que este agente tem mandato para fazer, e o prompt do agente proíbe explicitamente inventar regra de negócio ausente (§2: "Nunca invente regras de negócio ausentes"). Regra de estorno tem implicação jurídica e financeira direta (prazo, elegibilidade, quem autoriza, se há taxa) — não é uma decisão de modelagem de domínio, é uma decisão de produto/jurídico que falta no FRD.

O que fiz: modelei `RefundRequest` como **stub** dentro do bounded context Wallet & Recharge, com apenas o estado inicial (`Solicitado`) e sem transições de decisão, e registrei como Ponto a Validar (VAL-02). Isso permite a arquitetura evoluir sem bloquear a segmentação, mas não fabrica a regra.

### 0.3 "Simplifica pondo todos os contextos num core_db único com join direto"

**Recusado.** Isso contraria diretamente a heurística central de ownership de dados deste agente (§11 do prompt: "Evite joins diretos entre dados de contextos diferentes", "Cada entidade/tabela/collection deve ter um único dono de escrita") e o critério de qualidade "Não criar data model compartilhado sem dono". Um `core_db` único com join direto entre, por exemplo, tabelas de Wallet & Recharge e Settlement & Clearing recriaria o cenário clássico de Big Ball of Mud: qualquer contexto poderia escrever no dado de outro, mudanças de schema em um contexto quebrariam queries de outro, e a consistência transacional que a "simplicidade" promete na verdade não existe entre domínios com ciclos de vida e taxas de mudança diferentes (ex.: Fare & Boarding sincroniza em lote/offline; Settlement & Clearing publica arquivo imutável diário — unificar o schema não muda essa assincronia de fato, só esconde).

Proponho, em vez disso, um banco (ou schema isolado) por bounded context, com integração via evento de domínio, API ou read model — ver `docs/product/data-model/data-model.md`.

---

## 1.1 Subdomain Classification Matrix

| Capacidade | Classificação | Justificativa | Evidências | Pontos a Validar |
|---|---|---|---|---|
| Boarding Decision + Fare Integration | Core Domain | Decisão offline em 300 ms com integração tarifária temporal é a principal diferenciação operacional do produto (OBJ-01, OBJ-03); regra própria e complexa | PRD/FRD/NFRD | — |
| Wallet & Recharge (incl. Refund Handling) | Core Domain | Gestão de saldo é central ao modelo de receita; envolve invariantes financeiras próprias e integração com antifraude externo | PRD/FRD/NFRD | VAL-02 (regra de estorno pendente) |
| Settlement & Clearing | Core Domain | Repasse auditável às 3 operadoras é objetivo de negócio explícito (OBJ-04) com regra de imutabilidade própria (NFR-05); risco financeiro/regulatório alto se falhar | PRD/FRD/NFRD | — |
| Card Lifecycle & Passenger Identity | Supporting Subdomain | Necessário para o produto funcionar, mas não é o diferencial competitivo; segue padrões relativamente estabelecidos de gestão de identidade/cartão | FRD | — |
| Balance Notification | Generic Subdomain | Push de saldo baixo é uma capacidade substituível por provider de notificação comum (ex.: FCM/APNs via serviço terceirizado) | FRD | — |

## 1.2 Classificação de Subdomínios (matriz-fonte da idempotência §4.0)

| Subdomínio | Tipo | Slug |
|---|---|---|
| Fare & Boarding | Core | fare-boarding |
| Wallet & Recharge | Core | wallet-recharge |
| Settlement & Clearing | Core | settlement-clearing |
| Card & Identity | Supporting | card-identity |
| Notification | Generic | notification |

## 4.1 Bounded Context Candidates

| Código | Bounded Context | Subdomínio Relacionado | Tipo | Justificativa | Status |
|---|---|---|---|---|---|
| BC-01 | Fare & Boarding | Fare & Boarding | Core Domain | Linguagem própria (embarque, tarifa, integração), invariante de saldo/bloqueio local, ciclo de vida offline-first próprio, NFR de latência específico | Confirmar |
| BC-02 | Wallet & Recharge | Wallet & Recharge | Core Domain | Linguagem própria (saldo, recarga, estorno), invariantes financeiras, integração própria com adquirente/PSP, NFR de disponibilidade e segurança (NFR-02, NFR-03) específicos | Confirmar |
| BC-03 | Settlement & Clearing | Settlement & Clearing | Core Domain | Linguagem própria (clearing, repasse, lote), invariante de imutabilidade (NFR-05), ciclo de vida diário próprio, ownership de dados de repasse | Confirmar |
| BC-04 | Card & Identity | Card & Identity | Supporting Subdomain | Linguagem e ciclo de vida próprios (cartão, bloqueio, autenticação), mas menor complexidade de regra que os Core | Confirmar |
| BC-05 | Notification | Notification | Generic Subdomain | Capacidade genérica, sem regra de negócio própria além de gatilho e canal | Confirmar |

## Boundary Validation Matrix

| Bounded Context | Linguagem Própria | Regras Próprias | Ciclo de Vida Próprio | Ownership de Dados | Integrações Próprias | NFRs Específicos | Decisão |
|---|---|---|---|---|---|---|---|
| Fare & Boarding | Sim | Sim | Sim (offline-first) | Sim | Não (interno) | Sim (NFR-01) | Confirmar |
| Wallet & Recharge | Sim | Sim | Sim | Sim | Sim (adquirente, PSP Pix, PDV) | Sim (NFR-02, NFR-03) | Confirmar |
| Settlement & Clearing | Sim | Sim | Sim (batch diário) | Sim | Não (interno, consome eventos) | Sim (NFR-05) | Confirmar |
| Card & Identity | Sim | Sim | Sim | Sim | Não (interno) | Fraco (nenhum NFR específico registrado) | Confirmar — módulo interno mais simples, mas mantido como BC por ownership de dado sensível (credenciais) e ciclo de vida próprio de bloqueio |
| Notification | Fraco | Fraco | Fraco | Não (não possui dado persistente próprio relevante) | Sim (provider de push) | Não | Confirmar como Generic Subdomain / BC fino — candidato natural a Adapter/serviço genérico, não a deployable complexo |

### Nota sobre Fare & Boarding → Wallet & Recharge

O validador embarcado decide localmente (offline) usando um **cache de saldo e lista de bloqueio**, não o saldo autoritativo em tempo real (PROB-01, TEC-01). Isso é uma relação **Customer/Supplier com Conformist parcial**: Fare & Boarding consome uma projeção (read model) de saldo/bloqueio publicada por Wallet & Recharge e Card & Identity, e depois publica `EmbarqueAprovado`/`LoteEmbarquesSincronizado` de volta para que o saldo autoritativo seja debitado. Não é um join direto entre bancos — é assíncrono por natureza do produto (offline-first), o que reforça por que um `core_db` único com join síncrono não reflete a realidade operacional do sistema.

---

## 5.X Checklist de inventário final

| Tipo | Esperado (segmentation) | Encontrado (filesystem) | Faltando (slugs) |
|---|---|---|---|
| Subdomínios Core | 3 | 3 | — |
| Subdomínios Supporting | 1 | 1 | — |
| Subdomínios Generic | 1 | 1 | — |
| Bounded Contexts (decisão `Confirmar`) | 5 | 5 | — |

| Artefato | Esperado | Presente? |
|---|---|---|
| `docs/product/ddd/subdomains/core/` (dir) | Sim | Sim |
| `docs/product/ddd/subdomains/supporting/` (dir) | Sim | Sim |
| `docs/product/ddd/subdomains/generic/` (dir) | Sim | Sim |
| `docs/product/ddd/bounded-contexts/` (dir) | Sim | Sim |
| `docs/product/ddd/context-map/README.md` | Sim | Sim |
| `docs/product/ddd/context-map/relations.md` | Sim | Sim |
| `docs/product/ddd/context-map/patterns.md` | Sim | Sim |
| `docs/product/ddd/context-map/diagram.md` | Sim | Sim |
| `docs/product/ddd/diagrams/c4-level-1-system-context.md` | Sim | Sim |
| `docs/product/ddd/diagrams/c4-level-2-containers.md` | Sim | Sim |
| `docs/product/ddd/diagrams/c4-level-3-components.md` | Sim | Sim |
| `docs/product/ddd/diagrams/index.html` | Sim | Sim |

Nenhum item pulado por remoção (`~~BC-XX~~`) — todos os 5 bounded contexts propostos foram confirmados nesta primeira rodada. Nenhum excedente a higienizar.

---

# Resultado da Segmentação DDD

## 1. Subdomínios Identificados
| Subdomínio | Classificação | Justificativa |
|---|---|---|
| Fare & Boarding | Core Domain | Diferenciação operacional (embarque <2s, offline-first, integração temporal) |
| Wallet & Recharge | Core Domain | Central ao modelo de receita; invariantes financeiras próprias |
| Settlement & Clearing | Core Domain | Objetivo de negócio explícito (repasse auditável); regra de imutabilidade própria |
| Card & Identity | Supporting Subdomain | Necessário, mas não diferencial competitivo |
| Notification | Generic Subdomain | Capacidade comum, substituível por provider |

## 2. Bounded Contexts Propostos
| Bounded Context | Tipo | Status | Justificativa |
|---|---|---|---|
| Fare & Boarding | Core Domain | Confirmar | Linguagem, regras, ciclo de vida e ownership próprios |
| Wallet & Recharge | Core Domain | Confirmar | Idem, com integrações externas próprias |
| Settlement & Clearing | Core Domain | Confirmar | Idem, com invariante de imutabilidade própria |
| Card & Identity | Supporting Subdomain | Confirmar | Ownership de dado sensível e ciclo de vida próprio |
| Notification | Generic Subdomain | Confirmar | Ownership fraco, mantido como BC fino nesta rodada |

## 3. Módulos Candidatos
| Módulo | Bounded Context | Deployable Candidato |
|---|---|---|
| Fare & Boarding Service | Fare & Boarding | fare-boarding-svc |
| Wallet & Recharge Service | Wallet & Recharge | wallet-recharge-svc |
| Settlement & Clearing Service | Settlement & Clearing | settlement-clearing-svc |
| Card & Identity Service | Card & Identity | card-identity-svc |
| Notification Service | Notification | notification-svc |

## 4. Principais Decisões
- Cinco bounded contexts confirmados, cada um com schema/banco próprio — sem `core_db` compartilhado.
- Fare & Boarding consome projeções (read models) de saldo e bloqueio publicadas por Wallet & Recharge e Card & Identity, em vez de ler diretamente das tabelas desses contextos (relação Customer/Supplier com Conformist parcial, coerente com a natureza offline-first do validador).
- Read model `recent_trip_history` (30 dias) introduzido em Fare & Boarding para atender ao PRD §5 sem alterar a retenção de 5 anos do NFRD (NFR-04).
- `RefundRequest` modelado como stub em Wallet & Recharge, sem regra de decisão, até FR-11 ser definido pelo jurídico do consórcio.

## 5. Principais Pontos a Validar
- VAL-02: regra de estorno de recarga (FR-11) pendente de definição jurídica — não inventada por este agente.
- SLA de propagação de bloqueio de cartão até o validador embarcado, não definido no FRD.
- Retenção de `notification_log`, não especificada nos insumos.

## 6. Arquivos Criados ou Atualizados
| Arquivo | Ação |
|---|---|
| docs/product/ddd/consolidacao-dominio.md | Criado |
| docs/product/ddd/event-storming.md | Criado |
| docs/product/ddd/ddd-segmentation.md | Criado |
| docs/product/ddd/subdomains/core/{fare-boarding,wallet-recharge,settlement-clearing}/README.md | Criado |
| docs/product/ddd/subdomains/supporting/card-identity/README.md | Criado |
| docs/product/ddd/subdomains/generic/notification/README.md | Criado |
| docs/product/ddd/bounded-contexts/{fare-boarding,wallet-recharge,settlement-clearing,card-identity,notification}/README.md | Criado |
| docs/product/ddd/context-map/{README,relations,patterns,diagram}.md | Criado |
| docs/product/ddd/diagrams/{c4-level-1-system-context,c4-level-2-containers,c4-level-3-components}.md | Criado |
| docs/product/ddd/diagrams/index.html | Criado |
| docs/product/glossary/ubiquitous-language.md | Criado |
| docs/product/glossary/domain-glossary.md | Criado |
| docs/product/modules/README.md | Criado |
| docs/product/modules/{fare-boarding-service,wallet-recharge-service,settlement-clearing-service,card-identity-service,notification-service}/README.md | Criado |
| docs/product/data-model/data-model.md | Criado |
| docs/product/prd/prd.md | **Não alterado** (recusa §0.1) |
| docs/product/frd-nfrd/frd.md | **Não alterado** (recusa §0.2) |
| docs/product/frd-nfrd/nfrd.md | **Não alterado** (recusa §0.1) |
