# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.1
**Data:** 2026-09-26
**Status:** Aprovado
**Fonte Principal:** docs/product/prd/prd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-12 | Criação inicial do FRD a partir do PRD v1.0 |
| v1.1 | 2026-09-26 | Inclui FRD-rec-05 e FRD-rec-06 (F-07 — recarga recorrente com cartão salvo) e BR-04 (RN-05 — tokenização PCI DSS). Nenhum código FRD-acc-* ou FRD-rec-01..04 existente foi alterado ou renumerado. |

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
| FRD-rec-05 | Configurar recarga recorrente com cartão salvo | O sistema deve permitir que o passageiro salve um cartão de crédito (via token do adquirente) e agende recarga automática semanal ou mensal de valor fixo | Must Have | PRD F-07 |
| FRD-rec-06 | Pausar ou cancelar recarga recorrente | O sistema deve permitir que o passageiro pause ou cancele a qualquer momento um agendamento de recarga recorrente ativo | Must Have | PRD F-07 |

---

## 11. Detalhamento dos Requisitos Funcionais

## FRD-rec-01 - Recarregar cartão

### Critérios de Aceite

- [ ] Recarga abaixo de R$ 5,00 é recusada com MSG-001.
- [ ] Crédito só é gerado após confirmação do pagamento (BR-01).
- [ ] Segunda recarga de mesmo valor no mesmo cartão em menos de 2 minutos é recusada (BR-02).

(Demais requisitos detalhados omitidos nesta fixture; manter como estão.)

---

## FRD-rec-05 - Configurar recarga recorrente com cartão salvo

### Descrição

O sistema deve permitir que o passageiro salve um cartão de crédito e agende uma recarga automática, semanal ou mensal, de valor fixo, a ser debitada e creditada sem nova ação do passageiro a cada ciclo.

### Objetivo

Reduzir a fricção de recargas repetidas, eliminando a necessidade de o passageiro reabrir o app a cada recarga.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (P-01) | Cadastra o cartão, define valor e periodicidade do agendamento |

### Pré-condições

- Passageiro autenticado com ao menos um cartão de transporte vinculado (FRD-acc-02).
- Passageiro com cartão de crédito válido para tokenização junto ao adquirente.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro escolhe o cartão de transporte e informa os dados do cartão de crédito. |
| 2 | Sistema envia os dados ao adquirente e recebe de volta um token (BR-04); nenhum dado sensível do cartão é armazenado (FRD-rec-05 depende de BR-04). |
| 3 | Passageiro define valor fixo (mínimo R$ 5,00, conforme FRD-rec-01) e periodicidade (semanal ou mensal). |
| 4 | Sistema confirma o agendamento e passa a executar a recarga automaticamente a cada ciclo, seguindo as mesmas regras BR-01, BR-02 e BR-03 já aplicadas à recarga manual. |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro altera o valor ou a periodicidade de um agendamento existente | Sistema aplica a alteração ao próximo ciclo, sem afetar cobranças já processadas |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Adquirente não retorna token válido para o cartão informado | Sistema não salva o cartão nem cria o agendamento | MSG-003 |
| FE-02 | Cobrança automática do ciclo falha (cartão salvo recusado, expirado ou sem limite) | Sistema não gera crédito, mantém o agendamento ativo e notifica o passageiro | MSG-004 |
| FE-03 | Cartão de transporte vinculado ao agendamento é bloqueado (FRD-rec-04) | Sistema suspende automaticamente o agendamento até o passageiro reativá-lo com outro cartão | MSG-002 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | Crédito após confirmação |
| BR-02 | Antiduplicidade |
| BR-03 | Cartão bloqueado |
| BR-04 | Tokenização do cartão salvo (PCI DSS) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartão de transporte | Referência | Sim | Cartão já vinculado à conta (FRD-acc-02) |
| dados do cartão de crédito | Dados sensíveis (enviados diretamente ao adquirente) | Sim | Nunca persistidos pelo app — ver BR-04 |
| valor fixo | Monetário | Sim | Mínimo R$ 5,00 |
| periodicidade | Enum (semanal, mensal) | Sim | Define o ciclo de cobrança |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| token do cartão salvo | Referência opaca | Identificador devolvido pelo adquirente, sem dado sensível associado |
| status do agendamento | Enum (ativo, pausado, cancelado) | Estado corrente do agendamento |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro (P-01) | Criar, alterar, pausar, cancelar o próprio agendamento |

### Critérios de Aceite

- [ ] Nenhum número completo de cartão nem CVV é persistido pelo app em nenhuma etapa (BR-04).
- [ ] Agendamento só é criado após o adquirente devolver um token válido.
- [ ] Recarga automática de cada ciclo segue BR-01, BR-02 e BR-03, sem exceção para o fluxo recorrente.
- [ ] Falha de cobrança automática não gera crédito e preserva o agendamento ativo (não cancela silenciosamente).

### Dependências

- BR-04 (tokenização do cartão salvo).
- FRD-acc-02 (cartão de transporte vinculado).
- FRD-rec-01 (valor mínimo de recarga).

### Observações

- PRD RN-05 estende a exigência de tokenização a "qualquer funcionalidade futura que cobre cartão salvo" — ver sugestão de ADR em § 6 do resumo final.

### Pontos a Validar

- VAL-03 (limite de tentativas/retentativa de cobrança automática falhada — não definido no PRD v1.1).

---

## FRD-rec-06 - Pausar ou cancelar recarga recorrente

### Descrição

O sistema deve permitir que o passageiro pause ou cancele, a qualquer momento, um agendamento de recarga recorrente ativo, sem custo ou aprovação de terceiros.

### Objetivo

Garantir que o passageiro mantenha controle total sobre a cobrança automática, evitando cobrança indevida após a intenção de encerrar o agendamento.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (P-01) | Solicita a pausa ou o cancelamento do próprio agendamento |

### Pré-condições

- Agendamento de recarga recorrente ativo (FRD-rec-05) associado à conta do passageiro.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro acessa o agendamento ativo. |
| 2 | Passageiro escolhe pausar (suspende cobranças futuras, mantém o cadastro) ou cancelar (encerra definitivamente). |
| 3 | Sistema aplica a mudança a partir do próximo ciclo; nenhuma cobrança já processada é revertida por este requisito. |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro reativa um agendamento pausado | Sistema retoma a cobrança a partir do próximo ciclo, sem exigir nova tokenização se o token salvo ainda for válido |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Passageiro tenta pausar/cancelar agendamento já cancelado | Sistema informa que não há agendamento ativo para a ação | MSG-004 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-04 | Tokenização do cartão salvo (PCI DSS) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| ação | Enum (pausar, cancelar, reativar) | Sim | Ação solicitada pelo passageiro |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status do agendamento | Enum (ativo, pausado, cancelado) | Novo estado após a ação |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro (P-01) | Pausar, cancelar e reativar o próprio agendamento |

### Critérios de Aceite

- [ ] Pausa ou cancelamento é aplicado sem custo e sem aprovação de terceiros.
- [ ] Nenhuma cobrança futura ocorre após o cancelamento confirmado.
- [ ] Reativação não exige novo cadastro de cartão se o token salvo continuar válido.

### Dependências

- FRD-rec-05 (agendamento ativo).

### Observações

- Nenhuma.

### Pontos a Validar

- Nenhum ponto novo além de VAL-03 (compartilhado com FRD-rec-05).

---

## 13. Regras de Negócio

| Código | Regra | Descrição | Requisitos Relacionados | Fonte |
|---|---|---|---|---|
| BR-01 | Crédito após confirmação | Recarga só gera crédito após confirmação do pagamento | FRD-rec-01 | PRD RN-01 |
| BR-02 | Antiduplicidade | Mesmo cartão, mesmo valor, menos de 2 minutos: recusar | FRD-rec-01 | PRD RN-02 |
| BR-03 | Cartão bloqueado | Cartão bloqueado não recebe recarga | FRD-rec-01, FRD-rec-04 | PRD RN-03 |
| BR-04 | Tokenização do cartão salvo | O app nunca armazena o número completo nem o CVV do cartão de crédito salvo; a recarga recorrente usa apenas o token devolvido pelo adquirente. Exigência PCI DSS, vale para qualquer funcionalidade futura que envolva cartão salvo. | FRD-rec-05, FRD-rec-06 | PRD RN-05 |

---

## 14. Mensagens de Erro e Validação

| Código | Cenário | Mensagem | Tipo | Requisito Relacionado |
|---|---|---|---|---|
| MSG-001 | Valor abaixo do mínimo | O valor mínimo de recarga é R$ 5,00. | Validação | FRD-rec-01 |
| MSG-002 | Cartão bloqueado | Este cartão está bloqueado e não pode receber recarga. | Erro de Negócio | FRD-rec-01 |
| MSG-003 | Token do cartão salvo não obtido | Não foi possível salvar este cartão de crédito. Verifique os dados e tente novamente. | Erro de Integração | FRD-rec-05 |
| MSG-004 | Falha na cobrança automática recorrente | Não foi possível processar a recarga automática deste ciclo. O agendamento continua ativo. | Erro de Negócio | FRD-rec-05, FRD-rec-06 |

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
| F-07 | Recarga recorrente com cartão salvo | FRD-rec-05, FRD-rec-06 | Coberto |
| RN-05 | Tokenização do cartão salvo (PCI DSS) | BR-04 | Coberto |

---

## 19. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Valor máximo por recarga | PRD RN-04 | Alto | Obter definição do jurídico |
| VAL-02 | Prazo para abrir contestação | PRD §8 | Médio | Definir com SAC e financeiro |
| VAL-03 | Número de tentativas/retentativa após falha de cobrança automática recorrente e prazo para suspensão do agendamento por falhas consecutivas | PRD F-07 (não detalhado) | Médio | Definir com produto e financeiro antes da implementação |
