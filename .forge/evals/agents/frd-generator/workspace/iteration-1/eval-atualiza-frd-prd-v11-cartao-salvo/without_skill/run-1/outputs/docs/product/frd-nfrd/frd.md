# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.1
**Data:** 2026-09-28
**Status:** Em Elaboração (v1.1 — base v1.0 permanece Aprovada; item novo pendente de validação do QA)
**Fonte Principal:** docs/product/prd/prd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-12 | Criação inicial do FRD a partir do PRD v1.0 |
| v1.1 | 2026-09-28 | Adiciona FRD-rec-05 (recarga recorrente com cartão de crédito salvo, PRD F-07) e BR-04 (token PCI, PRD RN-05). Nenhum código existente (FRD-acc-*, FRD-rec-01 a FRD-rec-04, BR-01 a BR-03, MSG-001, MSG-002) foi alterado, renumerado ou removido. |

---

## 9. Módulos Funcionais

| Código | Módulo Funcional | Descrição | Funcionalidades Relacionadas |
|---|---|---|---|
| MOD-01 | Conta (acc) | Cadastro, login e vínculo de cartões | F-01, F-02 |
| MOD-02 | Recarga (rec) | Recarga, saldo, extrato, contestação, bloqueio e recarga recorrente com cartão salvo | F-03, F-04, F-05, F-06, F-07 |

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
| FRD-rec-05 | Recarga recorrente com cartão salvo | O sistema deve permitir que o passageiro salve um cartão de crédito (via token do adquirente) e agende recarga automática semanal ou mensal de valor fixo, com opção de pausar ou cancelar a qualquer momento | Must Have | PRD F-07 |

---

## 11. Detalhamento dos Requisitos Funcionais

## FRD-rec-01 - Recarregar cartão

### Critérios de Aceite

- [ ] Recarga abaixo de R$ 5,00 é recusada com MSG-001.
- [ ] Crédito só é gerado após confirmação do pagamento (BR-01).
- [ ] Segunda recarga de mesmo valor no mesmo cartão em menos de 2 minutos é recusada (BR-02).

(Demais requisitos detalhados omitidos nesta fixture; manter como estão.)

---

## FRD-rec-05 - Recarga recorrente com cartão salvo

### Critérios de Aceite

- [ ] Ao salvar o cartão de crédito, o sistema armazena apenas o token devolvido pelo adquirente; número completo (PAN) e CVV nunca são persistidos (BR-04).
- [ ] O passageiro pode agendar recorrência semanal ou mensal, com valor fixo igual ou acima do mínimo de R$ 5,00 (mesma regra de valor mínimo de FRD-rec-01).
- [ ] O passageiro pode pausar ou cancelar a recorrência a qualquer momento; recorrência cancelada não gera nova cobrança.
- [ ] Cartão bloqueado não pode ser alvo de recarga recorrente (BR-03, já vale para FRD-rec-01, estendida aqui).
- [ ] Falha na cobrança recorrente (token expirado, adquirente recusa) é reportada ao passageiro com MSG-003 e não interrompe as próximas execuções da recorrência sem confirmação do passageiro.
- [ ] Crédito da recarga recorrente só é gerado após confirmação do pagamento (BR-01, já vale para FRD-rec-01, estendida aqui).

---

## 13. Regras de Negócio

| Código | Regra | Descrição | Requisitos Relacionados | Fonte |
|---|---|---|---|---|
| BR-01 | Crédito após confirmação | Recarga só gera crédito após confirmação do pagamento | FRD-rec-01, FRD-rec-05 | PRD RN-01 |
| BR-02 | Antiduplicidade | Mesmo cartão, mesmo valor, menos de 2 minutos: recusar | FRD-rec-01 | PRD RN-02 |
| BR-03 | Cartão bloqueado | Cartão bloqueado não recebe recarga | FRD-rec-01, FRD-rec-04, FRD-rec-05 | PRD RN-03 |
| BR-04 | Token PCI para cartão salvo | O sistema nunca armazena o número completo (PAN) nem o CVV do cartão de crédito salvo; toda recarga recorrente usa exclusivamente o token devolvido pelo adquirente. Regra vale para FRD-rec-05 e para qualquer requisito futuro que envolva cartão salvo | FRD-rec-05 | PRD RN-05 |

**Nota de rastreabilidade:** BR-01 e BR-03 passaram a listar FRD-rec-05 na coluna "Requisitos Relacionados" por já se aplicarem à recarga recorrente conforme o texto do PRD v1.1; a descrição e a fonte dessas regras não mudaram.

---

## 14. Mensagens de Erro e Validação

| Código | Cenário | Mensagem | Tipo | Requisito Relacionado |
|---|---|---|---|---|
| MSG-001 | Valor abaixo do mínimo | O valor mínimo de recarga é R$ 5,00. | Validação | FRD-rec-01 |
| MSG-002 | Cartão bloqueado | Este cartão está bloqueado e não pode receber recarga. | Erro de Negócio | FRD-rec-01 |
| MSG-003 | Falha na cobrança recorrente | Não foi possível cobrar a recarga automática deste mês. Verifique o cartão salvo. | Erro de Negócio | FRD-rec-05 |

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
| F-07 | Recarga recorrente com cartão salvo | FRD-rec-05 | Coberto |
| RN-05 | Token PCI para cartão salvo | BR-04 | Coberto |

---

## 19. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Valor máximo por recarga | PRD RN-04 | Alto | Obter definição do jurídico |
| VAL-02 | Prazo para abrir contestação | PRD §8 | Médio | Definir com SAC e financeiro |
| VAL-03 | Comportamento após N falhas consecutivas de cobrança recorrente | PRD F-07 (não detalhado) | Médio | Definir com produto se a recorrência deve ser pausada automaticamente após um número de falhas, e qual o número |
