# Consolidação do Domínio — Tarifa Viva

> Gerado pelo `ddd-architect`. Insumos: `docs/product/prd/prd.md` v1.0, `docs/product/frd-nfrd/frd.md` v1.2, `docs/product/frd-nfrd/nfrd.md` v1.1, `docs/product/trd/trd.md`.

## 0. Nota preliminar — pedido do usuário fora do escopo deste agente

O pedido de execução trazia três instruções que este agente **não executa**, por estarem fora do seu escopo (`ddd-architect` não altera PRD/FRD/NFRD nem inventa regra de negócio ausente — ver `.forge/agents/architecture/ddd-architect.md` §2 e §11). O detalhamento e a justificativa de cada recusa estão em `docs/product/ddd/ddd-segmentation.md §0`. Resumo:

1. **Não alterei o NFRD** (retenção de 5 anos, NFR-04) para 30 dias. Após leitura cruzada com o PRD, o suposto conflito não existe: PRD §5 fala de **janela de exibição** no app; NFRD fala de **retenção para auditoria regulatória**. São políticas diferentes sobre o mesmo dado — não uma contradição a resolver por edição.
2. **Não inventei a regra de estorno de recarga** (FR-11, "a definir com o jurídico"). Marquei como Ponto a Validar e propus a menor modelagem segura (entidade `RefundRequest` como stub, sem regra de negócio), sem presumir "padrão de mercado" para algo que o próprio FRD registra como pendente jurídico.
3. **Não modelei um `core_db` único com joins diretos entre contextos.** Isso contraria a heurística central de ownership de dados deste agente (§11 do prompt) e recriaria o Big Ball of Mud que o DDD estratégico existe para evitar. Proponho ownership por bounded context, com integração via evento/API/read model.

O restante deste documento e dos artefatos em `docs/product/ddd/` cumpre a parte legítima do pedido: a segmentação DDD da Tarifa Viva.

## 1. Objetivos do Produto
| Código | Objetivo | Fonte |
|---|---|---|
| OBJ-01 | Reduzir tempo médio de embarque para < 2s por passageiro | PRD §2 |
| OBJ-02 | Permitir recarga pelo app e em pontos de venda credenciados | PRD §2 |
| OBJ-03 | Aplicar integração tarifária temporal (2ª viagem com desconto em 60 min) | PRD §2 |
| OBJ-04 | Repassar receita às 3 operadoras (clearing diário) com trilha auditável | PRD §2 |

## 2. Problemas de Negócio
| Código | Problema | Impacto | Fonte |
|---|---|---|---|
| PROB-01 | Validador embarcado opera offline e precisa decidir embarque em até 300 ms sem contato com o backend | Define fronteira de consistência entre decisão de embarque e saldo autoritativo | PRD §4 JRN-01 / NFRD NFR-01 |
| PROB-02 | Regra de estorno de recarga ainda não definida juridicamente | Bloqueia modelagem tática completa de `RefundRequest`; não bloqueia a segmentação estratégica | FRD FR-11 |
| PROB-03 | Dados de cartão de crédito não podem ser armazenados pela Tarifa Viva | Restringe onde o contexto de recarga pode persistir dado sensível; tokenização é do adquirente | NFRD NFR-03 |

## 3. Personas e Atores
| Código | Ator | Tipo | Descrição | Fonte |
|---|---|---|---|---|
| ACT-01 | Passageiro | Humano | Usuário final, portador de cartão físico ou virtual | PRD §3 |
| ACT-02 | Validador embarcado | Sistema | Equipamento no ônibus, opera offline, sincroniza em lote | PRD §3 |
| ACT-03 | Operadora de ônibus | Organização | Viação Serrana, Expresso Vale, TransSereno — dona das linhas | PRD §3 |
| ACT-04 | Gestor do consórcio | Humano | Opera o backoffice, audita clearing | PRD §3 |
| ACT-05 | Adquirente de cartão de crédito | Sistema externo | Processa e tokeniza pagamento de recarga | PRD §3 / NFRD NFR-03 |
| ACT-06 | PSP de Pix | Sistema externo | Meio de pagamento externo mencionado no PRD | PRD §3 |

## 4. Jornadas
| Código | Jornada | Ator Principal | Descrição | Fonte |
|---|---|---|---|---|
| JRN-01 | Embarque | Passageiro / Validador | Aproxima cartão; validador confere lista de bloqueio e saldo; debita tarifa | PRD §4 |
| JRN-02 | Recarga | Passageiro | Compra créditos no app (cartão de crédito) ou ponto de venda | PRD §4 |
| JRN-03 | Integração tarifária | Passageiro | Segunda viagem em até 60 min paga 50% | PRD §4 |
| JRN-04 | Clearing | Gestor do consórcio | Apuração diária do repasse por operadora | PRD §4 |
| JRN-05 | Notificação de saldo | Passageiro | Push quando saldo cai abaixo de 2 tarifas | PRD §4 |

## 5. Requisitos Funcionais Relevantes
| Código | Requisito | Descrição | Fonte |
|---|---|---|---|
| FR-01 | Validar embarque | Verifica bloqueio + saldo; debita tarifa vigente da linha | FRD |
| FR-02 | Operar offline | Até 5.000 embarques offline, sincroniza em lote na garagem | FRD |
| FR-03 | Integração temporal | 2ª viagem em <60 min = 50% da tarifa | FRD |
| FR-04 | Recarregar pelo app | Crédito só após validação antifraude do adquirente | FRD |
| FR-05 | Recarregar no PDV | Ponto de venda credenciado registra recarga em dinheiro | FRD |
| FR-06 | Bloquear cartão | Bloqueio chega aos validadores na próxima sincronização | FRD |
| FR-07 | Apurar clearing diário | Embarque atribuído à operadora dona da linha; arquivo de repasse diário | FRD |
| FR-08 | Notificar saldo baixo | Push quando saldo < 2 tarifas | FRD |
| FR-09 | Autenticar passageiro | Login por CPF + senha, MFA opcional | FRD |
| FR-11 | Estornar recarga | **Regra a definir com o jurídico (pendente)** — ver Ponto a Validar VAL-02 | FRD |

## 6. Requisitos Não Funcionais Relevantes para DDD
| Código | Categoria | Requisito | Impacto na Modelagem | Fonte |
|---|---|---|---|---|
| NFR-01 | Performance | Decisão de embarque em até 300 ms, inclusive offline | Fare & Boarding precisa de cache local de saldo/bloqueio; consistência eventual com Wallet | NFRD |
| NFR-02 | Disponibilidade | Recarga com 99,9% de disponibilidade mensal | SLA próprio do contexto Wallet & Recharge | NFRD |
| NFR-03 | Segurança | Dado de cartão de crédito nunca trafega/persiste na Tarifa Viva | Delimita fronteira de persistência de Wallet & Recharge (tokenização externa) | NFRD |
| NFR-04 | Compliance | Registros de embarque e recarga retidos por 5 anos para auditoria | Política de retenção do dado bruto em Fare & Boarding e Wallet & Recharge — **não alterada** | NFRD |
| NFR-05 | Auditoria | Arquivo de clearing imutável após publicado; correção via arquivo de ajuste | Settlement & Clearing usa append-only / event sourcing para o ledger | NFRD |

## 7. Restrições Técnicas Relevantes
| Código | Restrição | Impacto | Fonte |
|---|---|---|---|
| TEC-01 | Validador sincroniza em lote (batch), não em tempo real | Relação Fare & Boarding → Wallet é assíncrona, não pode ser join síncrono | PRD/FRD |

## 8. Integrações
| Código | Sistema Externo | Tipo | Finalidade | Fonte |
|---|---|---|---|---|
| INT-01 | Adquirente de cartão de crédito | Externo | Tokenização e validação antifraude de recarga | PRD/NFRD |
| INT-02 | PSP de Pix | Externo | Meio de pagamento de recarga | PRD |
| INT-03 | Ponto de venda credenciado | Externo/parceiro | Registro de recarga em dinheiro | FRD |

## 9. Entidades e Conceitos Mencionados
| Código | Conceito | Descrição Inicial | Fonte |
|---|---|---|---|
| CON-01 | Cartão (Card) | Identificador do meio de embarque, físico ou virtual | PRD/FRD |
| CON-02 | Saldo (Balance) | Crédito disponível associado ao cartão | FRD |
| CON-03 | Embarque (Boarding) | Evento de uso do cartão em uma linha | FRD |
| CON-04 | Recarga (Recharge) | Crédito adicionado ao saldo | FRD |
| CON-05 | Estorno de recarga (Refund) | Reversão de uma recarga — **regra pendente** | FRD FR-11 |
| CON-06 | Tarifa (Fare) | Valor cobrado por linha, sujeito a integração temporal | PRD/FRD |
| CON-07 | Clearing / Repasse | Apuração e distribuição diária de receita por operadora | PRD/FRD |
| CON-08 | Lista de bloqueio | Cartões impedidos de embarcar | FRD |

## 10. Regras, Políticas e Invariantes
| Código | Regra/Política/Invariante | Tipo | Fonte |
|---|---|---|---|
| RULE-01 | Embarque só é aprovado se cartão não bloqueado e houver saldo suficiente | Invariante | FRD FR-01 |
| RULE-02 | Segunda viagem em <60 min no mesmo cartão paga 50% | Regra de negócio | FRD FR-03 |
| RULE-03 | Recarga só é creditada após aprovação antifraude do adquirente | Invariante | FRD FR-04 |
| RULE-04 | Bloqueio de cartão só chega ao validador na próxima sincronização (consistência eventual) | Invariante | FRD FR-06 |
| RULE-05 | Arquivo de clearing publicado é imutável; correção é arquivo de ajuste, nunca edição | Invariante | NFRD NFR-05 |
| RULE-06 | Registros de embarque/recarga retidos por 5 anos para auditoria | Política regulatória | NFRD NFR-04 |
| RULE-07 | App exibe ao passageiro apenas os últimos 30 dias de histórico | Política de apresentação (não é política de retenção) | PRD §5 |

## 11. Pontos a Validar
| Código | Ponto | Motivo | Impacto |
|---|---|---|---|
| VAL-01 | RULE-06 (retenção 5 anos) e RULE-07 (exibição 30 dias) parecem conflitantes à primeira leitura, mas não são — uma é retenção regulatória do dado bruto, outra é janela de exibição no app | O pedido do usuário tratou as duas como a mesma coisa e pediu para "corrigir" o NFRD; este agente não tem mandato para alterar NFRD e, tecnicamente, não há conflito a resolver — há um read model de 30 dias sobre um dado retido por 5 anos | Nenhum ajuste em NFRD/PRD necessário; documentar a distinção no data model (read model "Histórico recente" com janela de 30 dias, materializado a partir do dado retido por 5 anos) |
| VAL-02 | FR-11 (estorno de recarga) está "a definir com o jurídico" | Regra de negócio ausente; este agente não inventa regra ausente | `RefundRequest` modelado como entidade stub em Wallet & Recharge, sem estados/transições definidos além de `Solicitado`; bloqueia modelagem tática completa até FRD ser atualizado por quem tem mandato de produto/jurídico |
| VAL-03 | Pedido do usuário de consolidar todos os contextos em `core_db` único com join direto | Contraria ownership de dados por bounded context (heurística central de DDD estratégico e regra explícita do agente) | Modelagem proposta usa um schema/banco por bounded context, com integração via evento, API ou read model — ver `docs/product/data-model/data-model.md` |
