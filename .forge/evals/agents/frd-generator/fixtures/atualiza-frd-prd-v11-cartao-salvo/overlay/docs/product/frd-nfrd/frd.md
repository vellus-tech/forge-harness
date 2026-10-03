# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.0
**Data:** 2026-09-12
**Status:** Aprovado
**Fonte Principal:** docs/product/prd/prd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-12 | Criação inicial do FRD a partir do PRD v1.0 |

---

## 9. Módulos Funcionais

| Código | Módulo Funcional | Descrição | Funcionalidades Relacionadas |
|---|---|---|---|
| MOD-01 | Conta (acc) | Cadastro, login e vínculo de cartões | F-01, F-02 |
| MOD-02 | Recarga (rec) | Recarga, saldo, extrato, contestação e bloqueio | F-03, F-04, F-05, F-06 |

---

## 10. Requisitos Funcionais

| Código | Requisito Funcional | Descrição | Prioridade | Fonte |
|---|---|---|---|---|
| FRD-acc-01 | Cadastrar conta | O sistema deve permitir que o passageiro crie conta com CPF, e-mail e senha | Must Have | PRD F-01 |
| FRD-acc-02 | Vincular cartão de transporte | O sistema deve vincular até 5 cartões por conta mediante número e data de nascimento do titular | Must Have | PRD F-02 |
| FRD-rec-01 | Recarregar cartão | O sistema deve permitir recarga a partir de R$ 5,00 por Pix ou cartão de crédito | Must Have | PRD F-03 |
| FRD-rec-02 | Consultar saldo e extrato | O sistema deve exibir saldo e 90 dias de recargas e usos | Must Have | PRD F-04 |
| FRD-rec-03 | Contestar recarga | O sistema deve permitir abrir contestação de recarga paga sem crédito | Should Have | PRD F-05 |
| FRD-rec-04 | Bloquear cartão por perda | O sistema deve bloquear o cartão e preservar o saldo | Must Have | PRD F-06 |

---

## 11. Detalhamento dos Requisitos Funcionais

## FRD-rec-01 - Recarregar cartão

### Critérios de Aceite

- [ ] Recarga abaixo de R$ 5,00 é recusada com MSG-001.
- [ ] Crédito só é gerado após confirmação do pagamento (BR-01).
- [ ] Segunda recarga de mesmo valor no mesmo cartão em menos de 2 minutos é recusada (BR-02).

(Demais requisitos detalhados omitidos nesta fixture; manter como estão.)

---

## 13. Regras de Negócio

| Código | Regra | Descrição | Requisitos Relacionados | Fonte |
|---|---|---|---|---|
| BR-01 | Crédito após confirmação | Recarga só gera crédito após confirmação do pagamento | FRD-rec-01 | PRD RN-01 |
| BR-02 | Antiduplicidade | Mesmo cartão, mesmo valor, menos de 2 minutos: recusar | FRD-rec-01 | PRD RN-02 |
| BR-03 | Cartão bloqueado | Cartão bloqueado não recebe recarga | FRD-rec-01, FRD-rec-04 | PRD RN-03 |

---

## 14. Mensagens de Erro e Validação

| Código | Cenário | Mensagem | Tipo | Requisito Relacionado |
|---|---|---|---|---|
| MSG-001 | Valor abaixo do mínimo | O valor mínimo de recarga é R$ 5,00. | Validação | FRD-rec-01 |
| MSG-002 | Cartão bloqueado | Este cartão está bloqueado e não pode receber recarga. | Erro de Negócio | FRD-rec-01 |

---

## 16. Matriz de Rastreabilidade

| Item PRD | Descrição PRD | Requisito FRD | Status |
|---|---|---|---|
| F-01 | Cadastro e login | FRD-acc-01 | Parcialmente Coberto |
| F-02 | Vincular cartão | FRD-acc-02 | Coberto |
| F-03 | Recarregar | FRD-rec-01 | Coberto |
| F-04 | Saldo e extrato | FRD-rec-02 | Coberto |
| F-05 | Contestação | FRD-rec-03 | Coberto |
| F-06 | Bloqueio por perda | FRD-rec-04 | Coberto |

---

## 19. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Valor máximo por recarga | PRD RN-04 | Alto | Obter definição do jurídico |
| VAL-02 | Prazo para abrir contestação | PRD §8 | Médio | Definir com SAC e financeiro |
