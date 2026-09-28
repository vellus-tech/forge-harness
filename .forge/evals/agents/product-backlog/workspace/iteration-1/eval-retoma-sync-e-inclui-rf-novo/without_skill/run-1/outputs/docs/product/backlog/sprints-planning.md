# Sprints Planning

- **Versão:** 1.1.0
- **Sprint length:** 2 semanas
- **Total de sprints:** 3 (+ backlog não alocado)
- **Período:** 2026-10-05 a 2026-11-15

## 1. Visão Executiva

Fundação dos dois módulos na Sprint 1, carteira com recarga Pix e ingestão de lotes na Sprint 2, cobrança integrada e backoffice na Sprint 3.

## 2. Mapa Módulo → Sprints

| Módulo | Sprints envolvidas | Marco principal |
|---|---|---|
| card-wallet | Sprint 1, Sprint 2 | Recarga Pix creditando saldo |
| fare-validation | Sprint 2, Sprint 3 | Primeira cobrança com integração temporal |

## 3. Tabela de Sprints

| Sprint | Slug | Objetivo (1 frase) | Início | Fim | Stories | Story Points |
|---|---|---|---|---|---|---|
| 1 | foundation | Ao final desta sprint, um passageiro consegue criar sua carteira vinculada ao CPF em homologação, viabilizando o piloto fechado com funcionários do consórcio. | 2026-10-05 | 2026-10-18 | 1 | 5 |
| 2 | recarga-pix | Ao final desta sprint, um passageiro consegue recarregar por Pix e ver o saldo, e os validadores conseguem enviar lotes offline, viabilizando o primeiro teste de campo. | 2026-10-19 | 2026-11-01 | 3 | 19 |
| 3 | cobranca-integrada | Ao final desta sprint, um passageiro consegue embarcar em duas linhas pagando uma única tarifa, viabilizando o go-live da integração temporal. | 2026-11-02 | 2026-11-15 | 2 | 11 |

## 4. Dependências Críticas

| Sprint | Depende de | Motivo |
|---|---|---|
| 2 | Sprint 1 | Recarga exige carteira (card-wallet TASK-03) |
| 3 | Sprint 1, Sprint 2 | Cobrança exige crédito Pix (card-wallet TASK-05) e ingestão de lotes (fare-validation TASK-03) |

## 5. Riscos de Cronograma

| Risco | Sprint impactada | Mitigação |
|---|---|---|
| Homologação do PSP Pix atrasar | Sprint 2 | PSP simulado via Testcontainers |

## 6. Backlog não alocado

| Story | Módulo | RF | Story Points | Motivo de não alocar agora | Candidata a |
|---|---|---|---|---|---|
| US-007 | card-wallet | RF-007 | 5 | Incluída pelo PO após o fechamento do escopo das Sprints 1–3 (19 pontos já comprometidos na Sprint 2); entrar agora estouraria a capacidade da sprint sem revalidação com o time | Sprint 4 (a abrir), ou troca de escopo com uma story de Sprint 2/3 mediante decisão do PO |

US-007 (bloqueio de cartão perdido) é requisito de segurança e não bloqueia o marco de nenhuma sprint já planejada — TASK-08 depende apenas de TASK-03 (agregado `Wallet`), já coberta na Sprint 1. Por isso fica no backlog não alocado em vez de forçar entrada em Sprint 2, preservando os compromissos de escopo e data já fechados nas seções 3 e 4.
