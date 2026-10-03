# Segmentação DDD — Tarifa Viva

## Controle de Versão
| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-08-25 | Segmentação inicial a partir do FRD v1.2 |
| v1.1 | 2026-09-26 | Reexecução completa (varredura idempotente §4.0) após FRD v1.3 — recarga via Pix (FR-10) incorporada ao subdomínio Card Wallet; demais capacidades e contextos inalterados no conteúdo, apenas verificados contra o filesystem |

## 1. Espaço do problema

### 1.2 Classificação de Subdomínios
| Capacidade | Classificação | Justificativa | Evidências | Pontos a Validar |
|---|---|---|---|---|
| Fare Validation | Core | Decisão de embarque offline com regras próprias | FR-01, FR-02, NFR-01 | |
| Fare Integration | Core | Integração temporal é regra diferenciadora do consórcio | FR-03 | |
| Card Wallet | Supporting | Saldo e recarga do cartão — três canais de recarga (crédito, ponto de venda, Pix) com o mesmo ciclo de vida de saldo | FR-04, FR-05, FR-06, FR-10 | VAL-02 |
| Operator Clearing | Supporting | Repasse diário às operadoras | FR-07, NFR-05 | |
| Notification | Generic | Push commodity via provedor | FR-08, TEC-04 | |
| Identity Access | Generic | Login e MFA | FR-09 | |

## 4. Espaço da solução

### 4.1 Bounded Context Candidates
| Código | Bounded Context | Subdomínio Relacionado | Decisão | Justificativa |
|---|---|---|---|---|
| BC-01 | Fare Validation | Fare Validation, Fare Integration | Confirmar | Linguagem de embarque e integração no mesmo ciclo de vida |
| BC-02 | Card Wallet | Card Wallet | Confirmar | Ownership do saldo e das recargas — inclui o webhook de liquidação Pix (FR-10) como evento externo consumido via Anti-Corruption Layer, sem alterar a fronteira do contexto |
| ~~BC-03~~ | ~~Trip Reporting~~ | ~~—~~ | Removido na v1.0 | Virou read model do Operator Clearing |
| BC-04 | Operator Clearing | Operator Clearing | Confirmar | Arquivo de repasse imutável e ciclo diário próprio |
| BC-05 | Notification | Notification | Consolidar com outro contexto | Sem linguagem própria; adapter do Card Wallet |
| BC-06 | Identity Access | Identity Access | Confirmar | Credenciais e MFA com ownership próprio |

## 11. Pontos a Validar
| Código | Ponto | Motivo | Impacto |
|---|---|---|---|
| VAL-01 | Limite de 5.000 embarques offline | Fornecedor ValidaBus não confirmou | Dimensionamento do lote |
| VAL-02 | Idempotência do webhook de liquidação Pix | FR-10 não especifica se o PSP reenvia o webhook em caso de timeout, nem se há chave de idempotência no payload | Risco de crédito duplicado no saldo — Card Wallet precisa de invariante própria de idempotência por `charge_id` do Pix até o PSP confirmar o contrato |

## 12. Higiene do filesystem (varredura idempotente §4.0)
| Item encontrado | Correspondência na matriz | Ação |
|---|---|---|
| `docs/product/ddd/bounded-contexts/legacy-ticketing/` | Nenhuma — não consta em §4.1 desta nem de versões anteriores da segmentação | Excedente. Rascunho anterior à v1.0 (bilhetagem em papel). Não removido nesta execução (fora do escopo do ddd-architect alterar/apagar artefato sem instrução explícita do usuário) — registrado como ponto a higienizar; recomenda-se decisão humana de arquivar ou apagar |

## 13. Checklist de inventário final

| Tipo | Esperado (segmentation) | Encontrado (filesystem) | Faltando (slugs) |
|---|---|---|---|
| Subdomínios Core | 2 (fare-validation, fare-integration) | 2 | — |
| Subdomínios Supporting | 2 (card-wallet, operator-clearing) | 2 | — |
| Subdomínios Generic | 2 (notification, identity-access) | 2 | — |
| Bounded Contexts (decisão `Confirmar`) | 4 (BC-01 fare-validation, BC-02 card-wallet, BC-04 operator-clearing, BC-06 identity-access) | 4 | — |

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

Itens pulados por decisão explícita da matriz:
- BC-03 (Trip Reporting) — marcado removido na v1.0, pulado conforme regra de varredura.
- BC-05 (Notification) — decisão "Consolidar com outro contexto", não "Confirmar"; não recebe pasta própria em `bounded-contexts/`, apenas README de subdomínio genérico e seção no módulo `card-wallet-ms`.

Excedente reportado: `docs/product/ddd/bounded-contexts/legacy-ticketing/` (ver §12).

## 14. Resultado da Segmentação DDD (resumo executivo)

### 14.1 Subdomínios Identificados
| Subdomínio | Classificação | Justificativa |
|---|---|---|
| Fare Validation | Core | Decisão de embarque offline com regras próprias |
| Fare Integration | Core | Integração temporal diferenciadora do consórcio |
| Card Wallet | Supporting | Saldo e recarga por três canais, agora incluindo Pix (FR-10) |
| Operator Clearing | Supporting | Repasse diário imutável às operadoras |
| Notification | Generic | Push commodity |
| Identity Access | Generic | Login e MFA |

### 14.2 Bounded Contexts Propostos
| Bounded Context | Tipo | Status | Justificativa |
|---|---|---|---|
| Fare Validation | Core Domain | Confirmado | Linguagem, regras e ciclo de vida próprios |
| Card Wallet | Supporting | Confirmado | Ownership do saldo; webhook Pix isolado por ACL sem alterar a fronteira |
| Operator Clearing | Supporting | Confirmado | Arquivo imutável e ciclo diário próprio |
| Identity Access | Generic | Confirmado | Credenciais e MFA com ownership próprio |
| Notification | Generic | Consolidar com Card Wallet | Sem linguagem própria |

### 14.3 Módulos Candidatos
| Módulo | Bounded Context | Deployable Candidato |
|---|---|---|
| Boarding API / Fare Integration Engine | Fare Validation | fare-validation-ms |
| Wallet API / Pix Recharge Engine / Recharge Engine / Card Block Engine | Card Wallet | card-wallet-ms |
| Clearing Engine | Operator Clearing | operator-clearing-ms |
| Auth API | Identity Access | identity-access-ms |

### 14.4 Principais Decisões
- FR-10 (recarga via Pix) foi tratado como um terceiro canal do subdomínio e bounded context Card Wallet já existentes, e não como um novo bounded context — mesma linguagem, mesmo ciclo de vida de saldo, mesmo ownership de dados dos canais de crédito e POS.
- O webhook do PSP Pix foi isolado por Anti-Corruption Layer (`PixPSPAdapter`), traduzido para o evento interno `PixSettlementConfirmed`, seguindo o mesmo padrão já usado para o adquirente de cartão de crédito.
- Apesar do pedido do usuário de gerar "só o que mudou por causa do Pix", a varredura de idempotência (§4.0 desta definição de agente) é obrigatória a cada execução — por isso esta rodada também completou os artefatos estruturais que já deveriam existir desde a v1.0 (subdomínios de Fare Integration, Card Wallet, Operator Clearing, Notification, Identity Access; bounded contexts de Card Wallet, Operator Clearing, Identity Access; Context Map completo; glossário; módulos; diagramas C4; data model), que estavam ausentes do filesystem embora já constassem na matriz da v1.0.

### 14.5 Principais Pontos a Validar
- VAL-01 (herdado da v1.0): limite de 5.000 embarques offline não confirmado pelo fornecedor ValidaBus.
- VAL-02 (novo, v1.1): idempotência do webhook de liquidação Pix não especificada no FRD v1.3 — risco de crédito duplicado.
- Excedente `legacy-ticketing`: recomenda-se decisão humana de arquivar ou remover.

### 14.6 Arquivos Criados ou Atualizados
| Arquivo | Ação |
|---|---|
| `docs/product/ddd/ddd-segmentation.md` | Atualizado (v1.1) |
| `docs/product/ddd/subdomains/core/fare-integration/README.md` | Criado |
| `docs/product/ddd/subdomains/supporting/card-wallet/README.md` | Criado |
| `docs/product/ddd/subdomains/supporting/operator-clearing/README.md` | Criado |
| `docs/product/ddd/subdomains/generic/notification/README.md` | Criado |
| `docs/product/ddd/subdomains/generic/identity-access/README.md` | Criado |
| `docs/product/ddd/bounded-contexts/fare-validation/README.md` | Atualizado (completado, estava stub) |
| `docs/product/ddd/bounded-contexts/card-wallet/README.md` | Criado (inclui Pix) |
| `docs/product/ddd/bounded-contexts/operator-clearing/README.md` | Criado |
| `docs/product/ddd/bounded-contexts/identity-access/README.md` | Criado |
| `docs/product/ddd/context-map/README.md` | Criado |
| `docs/product/ddd/context-map/relations.md` | Criado |
| `docs/product/ddd/context-map/patterns.md` | Criado |
| `docs/product/ddd/context-map/diagram.md` | Criado |
| `docs/product/glossary/ubiquitous-language.md` | Criado (inclui termos Pix) |
| `docs/product/modules/README.md` | Criado |
| `docs/product/modules/fare-validation-ms/README.md` | Criado |
| `docs/product/modules/card-wallet-ms/README.md` | Criado (inclui Pix) |
| `docs/product/modules/operator-clearing-ms/README.md` | Criado |
| `docs/product/modules/identity-access-ms/README.md` | Criado |
| `docs/product/ddd/diagrams/c4-level-1-system-context.md` | Criado |
| `docs/product/ddd/diagrams/c4-level-2-containers.md` | Criado |
| `docs/product/ddd/diagrams/c4-level-3-components.md` | Criado (foco em Card Wallet/Pix) |
| `docs/product/ddd/diagrams/index.html` | Criado |
| `docs/product/data-model/data-model.md` | Criado (inclui `pix_charges`) |
