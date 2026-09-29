# FRD — Portal do Lojista
**Requisitos Funcionais**

- **Versão:** 0.2.0
- **Data:** 2026-09-15
- **Status:** Rascunho para revisão
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 0.2.0 | 2026-09-15 | Atual | Inclusão de chargebacks |
| 0.1.0 | 2026-09-05 | Anterior | Versão inicial |

## 1. Requisitos Funcionais

### FRD-POR-01 — Login com segundo fator (F1, BR-02, BR-03)

O lojista entra com e-mail e senha e confirma com código TOTP. Após 5 tentativas inválidas, o acesso fica bloqueado por 30 minutos e é exibida MSG-001. A senha deve ser forte.

Critérios de aceite:
- CA-01: login sem TOTP válido é recusado.
- CA-02: a 5ª tentativa inválida bloqueia o acesso por 30 minutos.

### FRD-POR-02 — Consulta de vendas (F2)

O lojista filtra vendas por período de até 90 dias; o PAN aparece como 6 primeiros + 4 últimos dígitos.

Critérios de aceite:
- CA-01: período acima de 90 dias exibe MSG-002.
- CA-02: nenhuma tela exibe PAN completo.

### FRD-POR-03 — Exportação CSV (F3)

O lojista exporta em CSV o resultado da consulta, com o PAN mascarado igual à tela.

### FRD-CHB-1 — Chargebacks (F4)

O lojista vê os chargebacks abertos com motivo, valor e prazo de defesa.

### FRD-POR-05 — Gestão de operadores (BR-01)

O administrador cria, bloqueia e remove operadores da própria loja.

## 2. Mensagens

| Código | Texto |
|---|---|
| MSG-001 | Acesso bloqueado por 30 minutos após tentativas inválidas. |
| MSG-002 | Selecione um período de no máximo 90 dias. |
