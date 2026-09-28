# Resultado da Geração do FRD

## 1. Arquivos Criados ou Atualizados

| Arquivo | Ação |
|---|---|
| docs/product/frd-nfrd/frd.md | Criado |

## 2. Módulos Funcionais Identificados

| Código | Módulo | Quantidade de Requisitos |
|---|---|---|
| MOD-auth | Cadastro e Acesso | 2 |
| MOD-card | Gestão de Cartões | 2 |
| MOD-recharge | Recarga | 6 |
| MOD-balance | Saldo e Extrato | 2 |
| MOD-dispute | Contestação e Conciliação | 4 |

## 3. Quantidade de Requisitos

| Tipo | Quantidade |
|---|---|
| Requisitos Funcionais | 16 |
| Casos de Uso | 2 |
| Regras de Negócio | 7 |
| Mensagens | 20 |
| Pontos a Validar | 8 |

## 4. Principais Pontos a Validar

- VAL-01 — Prazo para o passageiro abrir contestação não definido (PRD §8).
- VAL-02 — Se o atendente SAC pode bloquear cartão em nome do passageiro (PRD §8).
- VAL-03 — Valor máximo por recarga pendente de definição jurídica (PRD RN-04).

## 5. Observações

- Os requisitos de segurança (armazenamento de CPF, dados de cartão de crédito, PCI DSS) pertencem ao NFRD, não a este FRD.
- A comunicação ao passageiro sobre o ciclo de sincronização do validador (até 30 minutos, fonte: discovery) foi tratada como parte funcional de FRD-recharge-04 e FRD-dispute-01, por ser a mitigação funcional direta da principal queixa levantada em discovery (900 reclamações/mês ao SAC).
- Nenhum arquivo de entrada (prd.md, discovery-notes.md) foi alterado.

## 6. ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (RF/UC/BR/PRD) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0001 | mecanismo-de-idempotencia-de-recarga | FRD-recharge-05 (BR-02) | Alta | A proteção contra recarga duplicada exige escolher entre token de idempotência do cliente e verificação por janela/hash no servidor; decisão de custo de reversão alto que afeta diretamente o comportamento observável da regra. |
| ADR-0002 | politica-de-retencao-de-cpf-e-dados-de-pagamento | FRD-auth-01, FRD-recharge-03 | Média | Cadastro com CPF e pagamento com dados de cartão de crédito implicam política de retenção/tokenização vinculante a mais de um módulo, com precedente de compliance (LGPD/PCI DSS). |
