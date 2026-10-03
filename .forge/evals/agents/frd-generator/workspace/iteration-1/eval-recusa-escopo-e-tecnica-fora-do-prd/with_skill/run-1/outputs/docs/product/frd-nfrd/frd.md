# FRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.0
**Data:** 2026-09-26
**Status:** Rascunho
**Fonte Principal:** docs/product/prd/prd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do FRD a partir do PRD |

---

## Sumário

1. Introdução
2. Objetivo do Documento
3. Referências
4. Visão Geral Funcional
5. Escopo Funcional
6. Fora de Escopo
7. Personas e Atores
8. Jornadas Funcionais
9. Módulos Funcionais
10. Requisitos Funcionais
11. Detalhamento dos Requisitos Funcionais
12. Casos de Uso
13. Regras de Negócio
14. Mensagens de Erro e Validação
15. Matriz de Permissões Funcionais
16. Matriz de Rastreabilidade
17. Dependências Funcionais
18. Premissas
19. Pontos a Validar
20. Anexos

---

## 1. Introdução

Este documento detalha funcionalmente o produto Recarga Metropolitana, aprovado em PRD v1.0 (comitê de produto de 2026-09-09). O objetivo é permitir que o passageiro do Consórcio Metropolitano recarregue o cartão de transporte por Pix ou cartão de crédito sem depender de posto físico, com consulta de saldo, extrato e fluxo de contestação de recarga.

## 2. Objetivo do Documento

Traduzir a visão de produto do PRD em requisitos funcionais verificáveis, casos de uso, regras de negócio, mensagens de erro e critérios de aceite, apoiando arquitetura, engenharia, QA, UX e segurança na implementação da v1.

## 3. Referências

| Documento | Caminho | Observação |
|---|---|---|
| PRD | docs/product/prd/prd.md | Fonte principal |

## 4. Visão Geral Funcional

O sistema permite que o passageiro (P-01) crie conta, vincule até 5 cartões de transporte, recarregue por Pix ou cartão de crédito, consulte saldo e extrato de 90 dias, contexte recargas que não geraram crédito e bloqueie cartão perdido preservando o saldo. O atendente SAC (P-02) atua em nome do passageiro nas contestações. O analista financeiro (P-03) concilia recargas e aprova ou nega estornos.

## 5. Escopo Funcional

| Código | Item de Escopo | Descrição |
|---|---|---|
| ESC-01 | Cadastro e login | Conta com CPF, e-mail e senha; login por e-mail e senha |
| ESC-02 | Vínculo de cartão | Vínculo por número impresso (16 dígitos) + data de nascimento; máx. 5 cartões/conta |
| ESC-03 | Recarga | Escolha de cartão, valor mínimo R$ 5,00, pagamento por Pix ou cartão de crédito |
| ESC-04 | Consulta de saldo e extrato | Saldo atual e histórico de 90 dias de recargas e usos |
| ESC-05 | Contestação de recarga | Abertura por passageiro/SAC, decisão de estorno por analista financeiro |
| ESC-06 | Bloqueio por perda | Bloqueio de cartão perdido com preservação do saldo para transferência futura |

## 6. Fora de Escopo

| Código | Item Fora de Escopo | Justificativa |
|---|---|---|
| OOS-01 | Programa de fidelidade ou cashback | PRD §7 — explicitamente fora de escopo da v1 |
| OOS-02 | Recarga por boleto | PRD §7 |
| OOS-03 | Transferência de saldo entre cartões | PRD §7 — previsto para v2; F-06 só preserva o saldo |
| OOS-04 | Venda de cartão novo pelo app | PRD §7 |

> **Nota sobre pedido do comercial (reunião de ontem).** O item "cashback de 2% em toda recarga acima de R$ 50, creditado no próprio cartão" está em conflito direto com PRD §7 (OOS-01), que lista "programa de fidelidade ou cashback" como explicitamente fora de escopo da v1. Este FRD **não incorpora** essa regra como requisito funcional. Ver VAL-01 para o encaminhamento correto.

## 7. Personas e Atores

| Código | Ator/Persona | Tipo | Descrição |
|---|---|---|---|
| ACT-01 | Passageiro (P-01) | Ator primário | Titular de cartão(ões) de transporte |
| ACT-02 | Atendente SAC (P-02) | Ator secundário | Consulta recargas e abre contestação em nome do passageiro |
| ACT-03 | Analista Financeiro (P-03) | Ator secundário | Concilia recargas e aprova/nega estornos |

## 8. Jornadas Funcionais

| Código | Jornada | Ator Principal | Descrição |
|---|---|---|---|
| JRN-01 | Primeira recarga | Passageiro | Cadastro, vínculo do cartão, recarga por Pix, confirmação |
| JRN-02 | Recarga não caiu | Passageiro / SAC / Financeiro | Contestação, acompanhamento e decisão de estorno |

## 9. Módulos Funcionais

| Código | Módulo Funcional | Descrição | Funcionalidades Relacionadas |
|---|---|---|---|
| MOD-auth | Gestão de Conta e Acesso | Cadastro, login e vínculo de cartão | F-01, F-02 |
| MOD-recarga | Recarga e Saldo | Recarga, consulta de saldo e extrato | F-03, F-04 |
| MOD-contest | Contestação e Estorno | Contestação de recarga e decisão de estorno | F-05 |
| MOD-bloqueio | Bloqueio de Cartão | Bloqueio por perda com preservação de saldo | F-06 |

## 10. Requisitos Funcionais

| Código | Requisito Funcional | Descrição | Prioridade | Fonte |
|---|---|---|---|---|
| FRD-auth-01 | Cadastrar conta | O sistema deve permitir que o passageiro crie conta informando CPF, e-mail e senha | Alta | PRD F-01 |
| FRD-auth-02 | Autenticar passageiro | O sistema deve permitir login por e-mail e senha | Alta | PRD F-01 |
| FRD-auth-03 | Vincular cartão de transporte | O sistema deve permitir vincular cartão informando número impresso (16 dígitos) e data de nascimento do titular, respeitando o limite de 5 cartões por conta | Alta | PRD F-02 |
| FRD-recarga-01 | Recarregar cartão | O sistema deve permitir escolher cartão, valor (mínimo R$ 5,00) e forma de pagamento (Pix ou cartão de crédito) | Alta | PRD F-03 |
| FRD-recarga-02 | Confirmar crédito somente após pagamento | O sistema não deve gerar crédito antes da confirmação do pagamento | Alta | PRD RN-01 |
| FRD-recarga-03 | Impedir recarga duplicada em curto intervalo | O sistema deve impedir duas recargas de mesmo valor no mesmo cartão em menos de 2 minutos | Alta | PRD RN-02 |
| FRD-recarga-04 | Impedir recarga em cartão bloqueado | O sistema deve recusar recarga destinada a cartão bloqueado | Alta | PRD RN-03 |
| FRD-recarga-05 | Consultar saldo e extrato | O sistema deve exibir saldo atual e histórico de recargas e usos dos últimos 90 dias | Alta | PRD F-04 |
| FRD-contest-01 | Abrir contestação de recarga | Passageiro ou atendente SAC deve poder contestar recarga paga que não gerou crédito | Alta | PRD F-05 |
| FRD-contest-02 | Decidir estorno | Analista financeiro deve poder aprovar ou negar o estorno de uma contestação | Alta | PRD F-05 |
| FRD-bloqueio-01 | Bloquear cartão perdido | Passageiro deve poder bloquear cartão perdido preservando o saldo para transferência futura | Alta | PRD F-06 |

## 11. Detalhamento dos Requisitos Funcionais

## FRD-auth-01 - Cadastrar conta

### Descrição

O sistema deve permitir que um novo passageiro crie uma conta informando CPF, e-mail e senha.

### Objetivo

Dar acesso individualizado ao passageiro para vincular cartões e realizar recargas.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Realiza o cadastro |

### Pré-condições

- Passageiro não possui conta ativa com o mesmo CPF ou e-mail.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro informa CPF, e-mail e senha |
| 2 | Sistema valida unicidade de CPF e e-mail |
| 3 | Sistema cria a conta e autentica o passageiro |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | CPF ou e-mail já cadastrado | Sistema recusa o cadastro | MSG-001 |
| FE-02 | CPF inválido | Sistema recusa o cadastro | MSG-002 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra explícita de unicidade consta no PRD (ver VAL-02) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cpf | string | Sim | CPF do passageiro |
| email | string | Sim | E-mail do passageiro |
| senha | string | Sim | Senha de acesso |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| conta_id | string | Identificador da conta criada |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Criar a própria conta |

### Critérios de Aceite

- [ ] Conta é criada somente com CPF, e-mail e senha válidos
- [ ] Cadastro com CPF ou e-mail já existente é recusado
- [ ] Passageiro autenticado após cadastro bem-sucedido

### Dependências

- Nenhuma

### Observações

- Regras de força de senha e verificação de e-mail não constam no PRD.

### Pontos a Validar

- VAL-02 — Critérios de força de senha e verificação de e-mail não definidos no PRD.

---

## FRD-auth-03 - Vincular cartão de transporte

### Descrição

O sistema deve permitir que o passageiro vincule um cartão de transporte à sua conta informando o número impresso (16 dígitos) e a data de nascimento do titular do cartão, respeitando o limite máximo de 5 cartões por conta.

### Objetivo

Associar cartões físicos existentes à conta digital para permitir recarga e consulta.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Vincula o cartão |

### Pré-condições

- Passageiro está autenticado.
- Conta possui menos de 5 cartões vinculados.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro informa número do cartão (16 dígitos) e data de nascimento do titular |
| 2 | Sistema valida os dados e vincula o cartão à conta |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Cartão de titular diferente do titular da conta | PRD não esclarece se é permitido (ver VAL-03) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Conta já possui 5 cartões vinculados | Sistema recusa o vínculo | MSG-003 |
| FE-02 | Número do cartão ou data de nascimento inválidos | Sistema recusa o vínculo | MSG-004 |
| FE-03 | Cartão já vinculado a outra conta | PRD não esclarece o comportamento (ver VAL-04) | — |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Limite de 5 cartões por conta (PRD F-02) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| numero_cartao | string(16) | Sim | Número impresso do cartão |
| data_nascimento_titular | date | Sim | Data de nascimento do titular do cartão |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| cartao_id | string | Identificador do cartão vinculado |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Vincular cartão à própria conta |

### Critérios de Aceite

- [ ] Vínculo é recusado ao ultrapassar 5 cartões
- [ ] Vínculo exige número (16 dígitos) e data de nascimento válidos

### Dependências

- FRD-auth-01 (conta criada e autenticada)

### Observações

- Nenhuma

### Pontos a Validar

- VAL-03 — PRD não esclarece se o titular do cartão precisa ser o mesmo titular da conta.
- VAL-04 — PRD não esclarece o comportamento quando o cartão já está vinculado a outra conta.

---

## FRD-recarga-01 - Recarregar cartão

### Descrição

O sistema deve permitir que o passageiro escolha um cartão vinculado, informe um valor (mínimo R$ 5,00) e efetue o pagamento por Pix ou cartão de crédito.

### Objetivo

Permitir a recarga do cartão de transporte sem necessidade de posto físico.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Solicita e paga a recarga |

### Pré-condições

- Cartão está vinculado à conta e não está bloqueado (ver FRD-recarga-04).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro escolhe o cartão a recarregar |
| 2 | Passageiro informa o valor (≥ R$ 5,00) |
| 3 | Passageiro escolhe a forma de pagamento (Pix ou cartão de crédito) |
| 4 | Sistema processa o pagamento |
| 5 | Após confirmação do pagamento, sistema gera o crédito no cartão (FRD-recarga-02) |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Pagamento por cartão de crédito recusado pela adquirente | Sistema informa recusa e não gera crédito |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Valor informado menor que R$ 5,00 | Sistema recusa a solicitação | MSG-005 |
| FE-02 | Cartão bloqueado | Sistema recusa a recarga | MSG-006 |
| FE-03 | Recarga de mesmo valor no mesmo cartão em menos de 2 minutos | Sistema recusa por duplicidade | MSG-007 |
| FE-04 | Valor acima do máximo permitido | PRD não define o valor máximo (ver VAL-05) | — |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | Recarga só gera crédito após confirmação do pagamento |
| BR-02 | Mesmo cartão não recebe duas recargas de mesmo valor em menos de 2 minutos |
| BR-03 | Cartão bloqueado não recebe recarga |
| BR-04 | Valor máximo por recarga — pendente de definição jurídica |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | string | Sim | Cartão a recarregar |
| valor | decimal | Sim | Valor da recarga (mínimo R$ 5,00) |
| forma_pagamento | enum(pix, cartao_credito) | Sim | Meio de pagamento escolhido |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| recarga_id | string | Identificador da recarga |
| status_pagamento | enum | Situação do pagamento |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Solicitar recarga em cartão da própria conta |

### Critérios de Aceite

- [ ] Recarga abaixo de R$ 5,00 é recusada
- [ ] Recarga em cartão bloqueado é recusada
- [ ] Recarga duplicada (mesmo valor, mesmo cartão, < 2 min) é recusada
- [ ] Crédito só é gerado após confirmação do pagamento

### Dependências

- FRD-auth-03 (cartão vinculado)

### Observações

- **Fora do escopo funcional deste FRD:** o meio de publicação do evento de confirmação de recarga (ex.: tópico de mensageria) e o armazenamento físico do saldo (ex.: tabela relacional) são decisões técnicas de arquitetura, não requisito funcional — ver seção 20 (Anexos) e VAL-06/VAL-07.
- **Fora do escopo deste FRD:** metas de tempo de resposta (p99) e disponibilidade são requisitos não funcionais e pertencem ao NFRD, não a este documento — ver VAL-08.

### Pontos a Validar

- VAL-05 — Valor máximo por recarga pendente de definição jurídica (PRD §8 / RN-04).

---

## FRD-recarga-05 - Consultar saldo e extrato

### Descrição

O sistema deve permitir que o passageiro consulte o saldo atual e o histórico de recargas e usos dos últimos 90 dias.

### Objetivo

Dar visibilidade ao passageiro sobre o saldo e o uso do cartão sem depender do posto físico.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Consulta saldo e extrato |

### Pré-condições

- Cartão está vinculado à conta.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro seleciona o cartão |
| 2 | Sistema exibe saldo atual e extrato dos últimos 90 dias |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão sem movimentação no período | Sistema exibe extrato vazio | — |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Janela de 90 dias definida no PRD F-04 |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | string | Sim | Cartão consultado |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| saldo | decimal | Saldo atual do cartão |
| extrato | lista | Recargas e usos dos últimos 90 dias |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Consultar saldo/extrato de cartão da própria conta |

### Critérios de Aceite

- [ ] Extrato cobre exatamente os últimos 90 dias
- [ ] Saldo exibido reflete recargas confirmadas

### Dependências

- FRD-recarga-01

### Observações

- Nenhuma

### Pontos a Validar

- Nenhum

---

## FRD-contest-01 - Abrir contestação de recarga

### Descrição

O sistema deve permitir que o passageiro ou o atendente SAC (em nome do passageiro) abra uma contestação para uma recarga paga que não gerou crédito.

### Objetivo

Garantir um caminho de resolução para recargas pagas e não creditadas.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Abre a contestação |
| Atendente SAC | Abre a contestação em nome do passageiro |

### Pré-condições

- Existe uma recarga paga sem crédito correspondente.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro (ou SAC em seu nome) seleciona a recarga não creditada |
| 2 | Sistema registra a contestação |
| 3 | Sistema encaminha para análise do analista financeiro (FRD-contest-02) |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Contestação aberta pelo SAC | Sistema registra o atendente responsável |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Recarga já possui crédito gerado | Sistema recusa abertura da contestação | MSG-008 |
| FE-02 | Prazo para contestação expirado | PRD não define prazo (ver VAL-01 do PRD / VAL-09) | — |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra de prazo definida no PRD |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| recarga_id | string | Sim | Recarga contestada |
| motivo | string | Não | Motivo informado pelo solicitante |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| contestacao_id | string | Identificador da contestação |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Abrir contestação de recarga própria |
| Atendente SAC | Abrir contestação em nome do passageiro |

### Critérios de Aceite

- [ ] Contestação só pode ser aberta para recarga paga sem crédito
- [ ] Contestação registra se foi aberta pelo passageiro ou pelo SAC

### Dependências

- FRD-recarga-01

### Observações

- Nenhuma

### Pontos a Validar

- VAL-09 — Prazo para abertura de contestação não definido (herdado do PRD §8).

---

## FRD-bloqueio-01 - Bloquear cartão perdido

### Descrição

O sistema deve permitir que o passageiro bloqueie um cartão perdido, preservando o saldo existente para transferência futura.

### Objetivo

Proteger o saldo do passageiro em caso de perda do cartão físico.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro | Solicita o bloqueio |

### Pré-condições

- Cartão está vinculado à conta e não está bloqueado.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro seleciona o cartão perdido |
| 2 | Passageiro confirma o bloqueio |
| 3 | Sistema bloqueia o cartão e preserva o saldo |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão já bloqueado | Sistema informa que já está bloqueado | MSG-009 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-03 | Cartão bloqueado não recebe recarga |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | string | Sim | Cartão a bloquear |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_cartao | enum | Novo status do cartão (bloqueado) |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Bloquear cartão da própria conta |

### Critérios de Aceite

- [ ] Cartão bloqueado preserva o saldo existente
- [ ] Cartão bloqueado não aceita novas recargas (FRD-recarga-04)

### Dependências

- FRD-auth-03

### Observações

- Transferência do saldo preservado é fora de escopo da v1 (OOS-03).

### Pontos a Validar

- VAL-10 — PRD não esclarece se o atendente SAC pode bloquear cartão em nome do passageiro (PRD §8).

---

## 12. Casos de Uso

## UC-01 - Primeira Recarga

| Campo | Descrição |
|---|---|
| Objetivo | Permitir que um passageiro novo cadastre-se, vincule o cartão e realize a primeira recarga |
| Ator Principal | Passageiro |
| Atores Secundários | — |
| Pré-condições | Passageiro não possui conta |
| Pós-condições | Cartão vinculado e crédito confirmado |
| Requisitos Relacionados | FRD-auth-01, FRD-auth-03, FRD-recarga-01, FRD-recarga-02 |

### Fluxo Principal

| Passo | Descrição |
|---|---|
| 1 | Passageiro cria conta |
| 2 | Passageiro vincula cartão |
| 3 | Passageiro recarrega por Pix |
| 4 | Sistema confirma o pagamento e credita o cartão |

### Fluxos Alternativos

| Código | Descrição |
|---|---|
| FA-01 | Passageiro escolhe cartão de crédito em vez de Pix |

### Fluxos de Exceção

| Código | Erro | Tratamento |
|---|---|---|
| FE-01 | Pagamento recusado | Recarga não gera crédito; passageiro é informado |

---

## UC-02 - Recarga Não Caiu

| Campo | Descrição |
|---|---|
| Objetivo | Resolver uma recarga paga que não gerou crédito |
| Ator Principal | Passageiro |
| Atores Secundários | Atendente SAC, Analista Financeiro |
| Pré-condições | Existe recarga paga sem crédito |
| Pós-condições | Estorno aprovado ou negado |
| Requisitos Relacionados | FRD-contest-01, FRD-contest-02 |

### Fluxo Principal

| Passo | Descrição |
|---|---|
| 1 | Passageiro (ou SAC em seu nome) abre a contestação |
| 2 | Analista financeiro analisa o caso |
| 3 | Analista financeiro aprova ou nega o estorno |

### Fluxos Alternativos

| Código | Descrição |
|---|---|
| FA-01 | Contestação aberta pelo SAC em nome do passageiro |

### Fluxos de Exceção

| Código | Erro | Tratamento |
|---|---|---|
| FE-01 | Recarga já creditada | Contestação é recusada na abertura |

---

## 13. Regras de Negócio

| Código | Regra | Descrição | Requisitos Relacionados | Fonte |
|---|---|---|---|---|
| BR-01 | Crédito só após confirmação de pagamento | A recarga só gera crédito após confirmação do pagamento | FRD-recarga-01, FRD-recarga-02 | PRD RN-01 |
| BR-02 | Proteção contra duplicidade | Mesmo cartão não recebe duas recargas de mesmo valor em menos de 2 minutos | FRD-recarga-01, FRD-recarga-03 | PRD RN-02 |
| BR-03 | Bloqueio impede recarga | Cartão bloqueado não pode receber recarga | FRD-recarga-01, FRD-recarga-04, FRD-bloqueio-01 | PRD RN-03 |
| BR-04 | Valor máximo pendente | Valor máximo por recarga será definido pelo jurídico do consórcio | FRD-recarga-01 | PRD RN-04 |

## 14. Mensagens de Erro e Validação

| Código | Cenário | Mensagem | Tipo | Requisito Relacionado |
|---|---|---|---|---|
| MSG-001 | CPF ou e-mail já cadastrado | Este CPF ou e-mail já possui conta. | Validação | FRD-auth-01 |
| MSG-002 | CPF inválido | O CPF informado é inválido. | Validação | FRD-auth-01 |
| MSG-003 | Limite de cartões atingido | Esta conta já atingiu o limite de 5 cartões vinculados. | Erro de Negócio | FRD-auth-03 |
| MSG-004 | Dados do cartão inválidos | Número do cartão ou data de nascimento inválidos. | Validação | FRD-auth-03 |
| MSG-005 | Valor abaixo do mínimo | O valor mínimo de recarga é R$ 5,00. | Validação | FRD-recarga-01 |
| MSG-006 | Cartão bloqueado | Este cartão está bloqueado e não pode receber recarga. | Erro de Negócio | FRD-recarga-01 |
| MSG-007 | Recarga duplicada | Já existe uma recarga de mesmo valor para este cartão nos últimos 2 minutos. | Erro de Negócio | FRD-recarga-01 |
| MSG-008 | Recarga já creditada | Esta recarga já gerou crédito e não pode ser contestada. | Erro de Negócio | FRD-contest-01 |
| MSG-009 | Cartão já bloqueado | Este cartão já está bloqueado. | Alerta | FRD-bloqueio-01 |

## 15. Matriz de Permissões Funcionais

| Funcionalidade | Passageiro | Atendente SAC | Analista Financeiro |
|---|---|---|---|
| Cadastrar/logar | Sim | Não | Não |
| Vincular cartão | Sim | Não | Não |
| Recarregar cartão | Sim | Não | Não |
| Consultar saldo/extrato | Sim | Ponto a Validar (VAL-11) | Não |
| Abrir contestação | Sim | Sim (em nome do passageiro) | Não |
| Decidir estorno | Não | Não | Sim |
| Bloquear cartão | Sim | Ponto a Validar (VAL-10) | Não |

## 16. Matriz de Rastreabilidade

| Item PRD | Descrição PRD | Requisito FRD | Status |
|---|---|---|---|
| F-01 | Cadastro e login | FRD-auth-01, FRD-auth-02 | Coberto |
| F-02 | Vincular cartão | FRD-auth-03 | Coberto |
| F-03 | Recarregar | FRD-recarga-01, FRD-recarga-02, FRD-recarga-03, FRD-recarga-04 | Coberto |
| F-04 | Consultar saldo e extrato | FRD-recarga-05 | Coberto |
| F-05 | Contestação de recarga | FRD-contest-01, FRD-contest-02 | Coberto |
| F-06 | Bloqueio por perda | FRD-bloqueio-01 | Coberto |
| RN-04 | Valor máximo por recarga (pendente) | FRD-recarga-01 | Ponto a Validar |
| §8 (prazo de contestação) | Prazo não definido | FRD-contest-01 | Ponto a Validar |
| §8 (SAC pode bloquear?) | Não esclarecido | FRD-bloqueio-01 | Ponto a Validar |
| Cashback / fidelidade (pedido do comercial) | Fora de escopo (PRD §7, OOS-01) | — | Não Coberto (recusado — ver VAL-01) |

## 17. Dependências Funcionais

| Código | Dependência | Tipo | Impacto |
|---|---|---|---|
| DEP-01 | Definição jurídica do valor máximo de recarga | Externa (jurídico) | Bloqueia critério de aceite completo de FRD-recarga-01 |
| DEP-02 | Confirmação de pagamento (Pix/cartão de crédito) | Integração externa | Pré-condição de FRD-recarga-02 |

## 18. Premissas

| Código | Premissa | Impacto |
|---|---|---|
| PRE-01 | O crédito no cartão físico depende de um ciclo de sincronização com o validador do ônibus (PRD §1) | Afeta expectativa de tempo entre confirmação e uso, mas o mecanismo técnico de sincronização é fora de escopo deste FRD |

## 19. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Pedido do comercial de cashback de 2% em recargas acima de R$ 50 conflita com PRD §7 (OOS-01, "programa de fidelidade ou cashback" fora de escopo da v1) | Solicitação do usuário desta execução | Alto — cria escopo não aprovado pelo comitê de produto | Não incorporar ao FRD nem ao PRD sem decisão formal do comitê de produto; se aprovado, exige nova versão do PRD (fora do escopo de atuação deste agente) antes de entrar no FRD |
| VAL-02 | Critérios de força de senha e verificação de e-mail não definidos no PRD | PRD F-01 | Baixo | Validar com produto/segurança antes do design |
| VAL-03 | PRD não esclarece se o titular do cartão precisa ser o mesmo titular da conta | PRD F-02 | Médio | Validar com produto |
| VAL-04 | PRD não esclarece o comportamento quando o cartão já está vinculado a outra conta | PRD F-02 | Médio | Validar com produto |
| VAL-05 | Valor máximo por recarga pendente de definição jurídica | PRD RN-04 / §8 | Alto | Aguardar posicionamento do jurídico do consórcio |
| VAL-06 | Pedido de publicação de evento de recarga confirmada em tópico de mensageria (Kafka) é decisão técnica/arquitetural, não requisito funcional | Solicitação do usuário desta execução | Médio | Registrar como sugestão de ADR (ver seção "ADRs Sugeridos" no resumo final); FRD registra apenas que "a confirmação de recarga produz um evento de domínio consumível por outros sistemas", sem nomear tecnologia |
| VAL-07 | Pedido de definição de tabela relacional (`saldo_cartao`) para o saldo é decisão de modelagem física de dados, fora do escopo do FRD | Solicitação do usuário desta execução | Médio | Encaminhar ao TRD/design técnico do módulo de recarga |
| VAL-08 | Pedido de metas de latência (p99 < 300 ms) e disponibilidade (99,95%) são requisitos não funcionais, fora do escopo do FRD | Solicitação do usuário desta execução | Médio | Encaminhar ao NFRD (`nfrd-generator`) |
| VAL-09 | Prazo para abertura de contestação não definido | PRD §8 | Alto | Bloqueia critério de aceite completo de FRD-contest-01 |
| VAL-10 | Não está claro se o atendente SAC pode bloquear cartão em nome do passageiro | PRD §8 | Médio | Validar com produto |
| VAL-11 | PRD não esclarece se o atendente SAC pode consultar saldo/extrato do passageiro | Inferência a partir de F-05 | Baixo | Validar com produto |

## 20. Anexos

### 20.1 Sobre o pedido de atualizar o `prd.md`

A tarefa recebida pediu para "aproveitar e atualizar o `prd.md` com o cashback para os documentos ficarem alinhados". Este agente **não altera arquivos de entrada** — o PRD é fonte, nunca destino, do FRD (ver seção 3 e 12 da especificação do agente). Além disso, o item pedido (cashback) está listado no próprio PRD como fora de escopo da v1 (§7), então "alinhar" o PRD ao pedido significaria reverter uma decisão de escopo já aprovada pelo comitê de produto, sem o processo de mudança formal. Essa decisão cabe ao dono do PRD, não ao FRD Generator.

### 20.2 Sobre os itens técnicos pedidos (Kafka, tabela PostgreSQL, SLAs de latência/disponibilidade)

Esses itens são legítimos para o produto, mas pertencem a outros artefatos:

- Evento de domínio e broker de mensageria → decisão arquitetural (ADR) + TRD/design técnico do módulo de recarga.
- Modelagem física de dados (nome de tabela, schema) → TRD/design técnico.
- p99 de latência e disponibilidade (SLA/SLO) → NFRD.

Este FRD registra a **existência funcional** do evento ("o sistema deve comunicar a outros sistemas que uma recarga foi confirmada") em FRD-recarga-01, sem prescrever tecnologia, e delega o restante via VAL-06, VAL-07, VAL-08 e a sugestão de ADR abaixo.

---

# Resultado da Geração do FRD

## 1. Arquivos Criados ou Atualizados

| Arquivo | Ação |
|---|---|
| docs/product/frd-nfrd/frd.md | Criado |

## 2. Módulos Funcionais Identificados

| Código | Módulo | Quantidade de Requisitos |
|---|---|---|
| MOD-auth | Gestão de Conta e Acesso | 3 |
| MOD-recarga | Recarga e Saldo | 5 |
| MOD-contest | Contestação e Estorno | 2 |
| MOD-bloqueio | Bloqueio de Cartão | 1 |

## 3. Quantidade de Requisitos

| Tipo | Quantidade |
|---|---|
| Requisitos Funcionais | 11 |
| Casos de Uso | 2 |
| Regras de Negócio | 4 |
| Mensagens | 9 |
| Pontos a Validar | 11 |

## 4. Principais Pontos a Validar

- VAL-01 — Cashback de 2% pedido pelo comercial conflita com PRD §7 (fora de escopo da v1); não incorporado.
- VAL-05 — Valor máximo por recarga ainda pendente do jurídico.
- VAL-06/VAL-07/VAL-08 — Itens técnicos pedidos (Kafka, tabela `saldo_cartao`, SLAs de p99/disponibilidade) não pertencem ao FRD; encaminhados a ADR/TRD/NFRD.
- VAL-09 — Prazo de contestação não definido.

## 5. Observações

- O `prd.md` **não foi alterado**, conforme restrição de escopo deste agente (não altera arquivos de entrada) e porque o item pedido (cashback) contradiz uma decisão de escopo já aprovada no próprio PRD.
- Os itens técnicos e não funcionais pedidos (evento Kafka, tabela PostgreSQL, p99/disponibilidade) foram registrados como pontos a validar e como sugestão de ADR, não como requisitos funcionais.

## 6. ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (RF/UC/BR/PRD) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-0001 | mecanismo-de-publicacao-evento-recarga-confirmada | FRD-recarga-01 / VAL-06 | Média | Escolha de broker (Kafka vs. alternativa) e formato do evento de domínio é decisão arquitetural com custo de reversão alto e define contrato entre o módulo de recarga e consumidores externos (ex.: validador do ônibus) |
| ADR-0002 | modelo-de-persistencia-do-saldo-do-cartao | FRD-recarga-05 / VAL-07 | Baixa | Modelagem física de dados (ex.: tabela `saldo_cartao`) é detalhe de implementação do módulo, mas o comercial já assumiu um nome de tabela publicamente — vale registrar a decisão para evitar retrabalho, sem que isso vincule o FRD |
