# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Base:** PRD v1.0 (Aprovado, comitê de produto de 2026-09-09) + discovery notes (2026-08)
**Versão deste FRD:** v0.1 (rascunho)
**Data:** 2026-09-26
**Status:** Rascunho — contém dois pontos que exigem decisão do comitê de produto antes de aprovação (ver Seção 0)

## 0. Aviso ao solicitante — dois itens do pedido não foram incorporados diretamente

O pedido de geração deste FRD veio acompanhado de três combinados de uma reunião com o comercial. Dois deles não podem entrar neste documento do jeito que foram descritos, e o terceiro entrou com ressalva:

1. **Cashback de 2% em recargas acima de R$ 50 — está fora do escopo aprovado do PRD.** A Seção 7 do PRD ("Fora de escopo (v1)") lista explicitamente "Programa de fidelidade ou cashback" como não incluído na v1, e o PRD tem status "Aprovado" pelo comitê em 2026-09-09. Um FRD deriva requisitos funcionais do PRD; ele não é o instrumento para reabrir escopo já aprovado. Incluir o cashback aqui, ou alterar a Seção 7 do PRD para removê-lo, exigiria uma decisão do comitê de produto (o mesmo grupo que aprovou o PRD), não uma decisão unilateral de quem gera o FRD. **Este FRD não especifica o cashback e o `prd.md` não foi alterado** — ver Seção 6 para o registro formal desse ponto em aberto.
2. **Tópico Kafka `recarga.confirmada` e tabela `saldo_cartao` no PostgreSQL são decisões de arquitetura/design técnico, não requisitos funcionais.** Um FRD descreve o que o sistema deve fazer e as regras de negócio associadas, de forma agnóstica de tecnologia; nome de tópico de mensageria e nome de tabela de banco pertencem ao documento de design técnico (TRD/DDD), que é elaborado a partir deste FRD, não o contrário. Registrei a intenção funcional por trás desses dois itens (publicar evento de recarga confirmada; persistir saldo de forma consultável) como requisito funcional e não-funcional agnóstico de tecnologia (RF-07, RNF-04), e anotei a preferência técnica do comercial como nota para a fase de design (Seção 6), mas não fixei nomes de tópico/tabela neste nível.
3. **Metas de p99 < 300 ms e disponibilidade 99,95% na confirmação de recarga foram incorporadas como requisitos não-funcionais (RNF-01, RNF-02)** — isso é compatível com um FRD/NFRD, que é o lugar correto para metas de desempenho e disponibilidade.

## 1. Escopo deste FRD

Deriva requisitos funcionais e não funcionais das funcionalidades F-01 a F-06 do PRD v1.0, incorporando os achados de discovery (sincronização do validador a cada 30 min, volume de 900 reclamações/mês no SAC, conciliação manual do financeiro). Não introduz funcionalidade fora da Seção 4 do PRD, exceto quando marcado como pendência de decisão (Seção 6).

## 2. Requisitos funcionais

| Código | Requisito | Origem (PRD) | Notas |
|---|---|---|---|
| RF-01 | O sistema deve permitir cadastro de passageiro com CPF, e-mail e senha, e login por e-mail/senha | F-01 | — |
| RF-02 | O sistema deve permitir vincular até 5 cartões de transporte por conta, validando número impresso (16 dígitos) e data de nascimento do titular | F-02 | — |
| RF-03 | O sistema deve permitir recarga de um cartão vinculado, com valor mínimo de R$ 5,00, pago por Pix ou cartão de crédito | F-03 | RN-04 (valor máximo) segue pendente conforme PRD §8 |
| RF-04 | O sistema deve exibir saldo atual e extrato de recargas e usos dos últimos 90 dias | F-04 | — |
| RF-05 | O sistema deve permitir abertura de contestação de recarga paga sem crédito, por passageiro ou atendente SAC, com decisão de estorno pelo analista financeiro | F-05 | Prazo de abertura ainda não definido (PRD §8) |
| RF-06 | O sistema deve permitir bloqueio de cartão por perda, preservando o saldo para transferência futura | F-06 | Transferência em si é v2 |
| RF-07 | O sistema deve notificar os componentes internos interessados (ex.: validador, conciliação financeira) quando uma recarga for confirmada | Inferido de F-03 + discovery (dor de "não saber se a recarga caiu") | Mecanismo de notificação (fila, evento, polling) é decisão de design técnico; comercial expressou preferência por evento assíncrono via Kafka — repassado como nota de design (Seção 6), não fixado aqui |

## 3. Regras de negócio (herdadas do PRD, sem alteração)

- RN-01: A recarga só gera crédito após confirmação do pagamento.
- RN-02: Um mesmo cartão não pode receber duas recargas de mesmo valor em menos de 2 minutos.
- RN-03: Cartão bloqueado não pode receber recarga.
- RN-04: Valor máximo por recarga — pendente de definição pelo jurídico (PRD §8).

## 4. Requisitos não funcionais

| Código | Requisito | Origem |
|---|---|---|
| RNF-01 | A confirmação de recarga deve responder com p99 abaixo de 300 ms | Combinado com o comercial (reunião de 2026-09-25) |
| RNF-02 | O fluxo de confirmação de recarga deve ter disponibilidade de 99,95% | Combinado com o comercial (reunião de 2026-09-25) |
| RNF-03 | O saldo do cartão deve ficar consultável de forma consistente para os fluxos de extrato (RF-04) e conciliação financeira | Inferido de F-04 + discovery (conciliação manual hoje é por planilha) |
| RNF-04 | O crédito da recarga deve refletir no validador do ônibus em até 1 ciclo de sincronização do equipamento (hoje 30 min, conforme discovery) | PRD §1 (visão) + discovery |

## 5. Jornadas (sem alteração de escopo)

- J-01: Primeira recarga — cadastro, vínculo do cartão, recarga por Pix, confirmação.
- J-02: Recarga não caiu — passageiro abre contestação; SAC acompanha; financeiro decide o estorno.

## 6. Pontos em aberto e decisões pendentes

| Item | Descrição | Decisão necessária | Responsável sugerido |
|---|---|---|---|
| PA-01 | Cashback de 2% em recargas acima de R$ 50 | O PRD aprovado lista cashback/fidelidade como fora de escopo v1 (§7). Incluir exige reabertura formal de escopo pelo comitê de produto que aprovou o PRD, com análise de impacto (financeiro, regulatório — crédito em cartão de transporte pode ter implicações de meios de pagamento) | Comitê de produto |
| PA-02 | Tecnologia de mensageria e persistência (Kafka `recarga.confirmada`, tabela `saldo_cartao` em PostgreSQL) | RF-07/RNF-03 descrevem a necessidade funcional; a escolha de tecnologia específica deve ser validada na fase de design técnico (TRD/DDD), considerando arquitetura já existente do consórcio | Arquitetura/tech lead na fase de design |
| PA-03 (herdado do PRD) | Valor máximo por recarga (RN-04) | Pendente do jurídico | Jurídico do consórcio |
| PA-04 (herdado do PRD) | Prazo para abrir contestação | Pendente de definição | Produto |
| PA-05 (herdado do PRD) | Atendente SAC pode bloquear cartão em nome do passageiro? | Pendente de definição | Produto |

## 7. Fora de escopo (herdado do PRD, sem alteração)

- Programa de fidelidade ou cashback.
- Recarga por boleto.
- Transferência de saldo entre cartões (v2).
- Venda de cartão novo pelo app.
