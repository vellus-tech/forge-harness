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
| v1.0 | 2026-09-26 | Criação inicial do FRD a partir do PRD aprovado (v1.0, 2026-09-10) e das notas de discovery |

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

A Recarga Metropolitana permite que o passageiro do Consórcio Metropolitano recarregue o cartão de transporte por Pix ou cartão de crédito pelo app ou pela web, sem depender de fila em posto físico. Hoje 68% das recargas acontecem em postos físicos, com fila média de 22 minutos no pico, e o passageiro não tem como consultar saldo ou histórico fora do posto. Este FRD detalha funcionalmente as capacidades descritas no PRD aprovado para que engenharia, QA, UX e segurança possam quebrar o backlog a partir de requisitos verificáveis.

---

## 2. Objetivo do Documento

Traduzir a visão, as personas, as jornadas e as funcionalidades do PRD em requisitos funcionais testáveis, com fluxos principais e alternativos, regras de negócio, mensagens de erro, permissões por perfil e rastreabilidade completa com o PRD, sem introduzir decisão de arquitetura, banco de dados ou stack tecnológica.

---

## 3. Referências

| Documento | Caminho | Observação |
|---|---|---|
| PRD | docs/product/prd/prd.md | Fonte principal — v1.0, aprovado em 2026-09-09 |
| Notas de Discovery | docs/discovery/discovery-notes.md | Enriquecimento — entrevistas com passageiros, volume de SAC e conciliação financeira |

---

## 4. Visão Geral Funcional

O sistema oferece quatro capacidades funcionais centrais para o passageiro (cadastro/login, vínculo de cartão, recarga por Pix ou cartão de crédito e consulta de saldo/extrato), uma capacidade de bloqueio de cartão por perda com preservação de saldo, e um fluxo de contestação que envolve três perfis — passageiro, atendente SAC e analista financeiro — para tratar recarga paga que não gerou crédito. As notas de discovery mostram que essa falha de "recarga que não caiu" é a principal queixa dos passageiros (900 reclamações/mês ao SAC) e está associada a uma limitação de equipamento: o validador do ônibus sincroniza crédito a cada 30 minutos, o que o produto deve comunicar funcionalmente ao usuário para reduzir a percepção de falha.

---

## 5. Escopo Funcional

| Código | Item de Escopo | Descrição |
|---|---|---|
| ESC-01 | Cadastro e login | Criação de conta e autenticação do passageiro |
| ESC-02 | Vínculo de cartão de transporte | Associação de até 5 cartões por conta |
| ESC-03 | Recarga por Pix e cartão de crédito | Escolha de cartão, valor mínimo de R$ 5,00 e meio de pagamento |
| ESC-04 | Consulta de saldo e extrato | Visualização de saldo e movimentações dos últimos 90 dias |
| ESC-05 | Contestação de recarga | Abertura, acompanhamento e decisão de estorno de recarga paga sem crédito |
| ESC-06 | Bloqueio de cartão por perda | Bloqueio com preservação de saldo para transferência futura |

---

## 6. Fora de Escopo

| Código | Item Fora de Escopo | Justificativa |
|---|---|---|
| OOS-01 | Programa de fidelidade ou cashback | Declarado fora de escopo no PRD (v1) |
| OOS-02 | Recarga por boleto | Declarado fora de escopo no PRD (v1) |
| OOS-03 | Transferência de saldo entre cartões | Adiado para v2; em v1 o bloqueio (F-06) apenas preserva o saldo, sem transferi-lo |
| OOS-04 | Venda de cartão novo pelo app | Declarado fora de escopo no PRD (v1) |

---

## 7. Personas e Atores

| Código | Ator/Persona | Tipo | Descrição |
|---|---|---|---|
| ACT-01 | Passageiro | Usuário final | Titular de um ou mais cartões de transporte; recarrega, vincula cartão, consulta saldo/extrato, contesta recarga e bloqueia cartão perdido |
| ACT-02 | Atendente SAC | Usuário interno | Consulta recargas em nome do passageiro e abre contestação; ponto de escalonamento das ~900 reclamações/mês (fonte: discovery) |
| ACT-03 | Analista Financeiro | Usuário interno | Concilia recargas pagas com créditos gerados e aprova ou nega estornos; hoje concilia manualmente por planilha uma vez ao dia (fonte: discovery) |
| ACT-04 | Validador do ônibus | Sistema externo (não coberto por este FRD) | Sincroniza crédito no cartão físico a cada 30 minutos; citado apenas para contextualizar RF que dependem dessa cadência |

---

## 8. Jornadas Funcionais

| Código | Jornada | Ator Principal | Descrição |
|---|---|---|---|
| JRN-01 | Primeira recarga | Passageiro | Cadastro, vínculo do cartão, recarga por Pix, confirmação |
| JRN-02 | Recarga não caiu | Passageiro, Atendente SAC, Analista Financeiro | Passageiro abre contestação; SAC acompanha; financeiro decide o estorno |

---

## 9. Módulos Funcionais

| Código | Módulo Funcional | Descrição | Funcionalidades Relacionadas |
|---|---|---|---|
| MOD-auth | Cadastro e Acesso | Criação de conta e autenticação do passageiro | F-01 |
| MOD-card | Gestão de Cartões | Vínculo de cartão de transporte e bloqueio por perda | F-02, F-06 |
| MOD-recharge | Recarga | Escolha de cartão/valor, pagamento e geração de crédito | F-03 |
| MOD-balance | Saldo e Extrato | Consulta de saldo e histórico de movimentações | F-04 |
| MOD-dispute | Contestação e Conciliação | Contestação de recarga, acompanhamento SAC e decisão financeira | F-05 |

---

## 10. Requisitos Funcionais

| Código | Requisito Funcional | Descrição | Prioridade | Fonte |
|---|---|---|---|---|
| FRD-auth-01 | Cadastrar conta | O sistema deve permitir que o passageiro crie conta informando CPF, e-mail e senha | Alta | PRD F-01 |
| FRD-auth-02 | Autenticar passageiro | O sistema deve permitir login do passageiro por e-mail e senha | Alta | PRD F-01 |
| FRD-card-01 | Vincular cartão de transporte | O sistema deve permitir vincular cartão informando número impresso (16 dígitos) e data de nascimento do titular, respeitando o limite de 5 cartões por conta | Alta | PRD F-02 |
| FRD-card-02 | Bloquear cartão por perda | O sistema deve permitir bloquear um cartão vinculado, preservando o saldo para transferência futura | Alta | PRD F-06 |
| FRD-recharge-01 | Selecionar cartão e valor da recarga | O sistema deve permitir ao passageiro escolher um cartão vinculado e um valor de recarga igual ou superior a R$ 5,00 | Alta | PRD F-03 |
| FRD-recharge-02 | Pagar recarga por Pix | O sistema deve permitir concluir o pagamento da recarga via Pix | Alta | PRD F-03 |
| FRD-recharge-03 | Pagar recarga por cartão de crédito | O sistema deve permitir concluir o pagamento da recarga via cartão de crédito | Alta | PRD F-03 |
| FRD-recharge-04 | Gerar crédito após confirmação de pagamento | O sistema só deve gerar crédito na recarga após confirmação do pagamento | Alta | PRD RN-01 |
| FRD-recharge-05 | Bloquear recarga duplicada | O sistema não deve aceitar duas recargas de mesmo valor no mesmo cartão em menos de 2 minutos | Alta | PRD RN-02 |
| FRD-recharge-06 | Impedir recarga em cartão bloqueado | O sistema não deve permitir recarga em cartão com status bloqueado | Alta | PRD RN-03 |
| FRD-balance-01 | Consultar saldo | O sistema deve exibir ao passageiro o saldo atual de cada cartão vinculado | Alta | PRD F-04 |
| FRD-balance-02 | Consultar extrato de 90 dias | O sistema deve exibir ao passageiro as recargas e os usos dos últimos 90 dias | Alta | PRD F-04 |
| FRD-dispute-01 | Abrir contestação de recarga | O sistema deve permitir ao passageiro contestar uma recarga paga que não gerou crédito | Alta | PRD F-05 |
| FRD-dispute-02 | Abrir contestação em nome do passageiro | O sistema deve permitir ao atendente SAC contestar, em nome do passageiro, uma recarga paga que não gerou crédito | Alta | PRD F-05 |
| FRD-dispute-03 | Decidir estorno | O sistema deve permitir ao analista financeiro aprovar ou negar o estorno de uma contestação | Alta | PRD F-05 |
| FRD-dispute-04 | Acompanhar contestação | O sistema deve permitir ao passageiro e ao atendente SAC acompanhar o status de uma contestação aberta | Alta | PRD F-05, J-02 |

---

## 11. Detalhamento dos Requisitos Funcionais

## FRD-auth-01 - Cadastrar conta

### Descrição

O sistema deve permitir que o passageiro crie uma conta informando CPF, e-mail e senha, para em seguida vincular cartões e realizar recargas.

### Objetivo

Dar ao passageiro identidade única no sistema, pré-requisito para vincular cartão e recarregar sem ir ao posto físico.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Preenche CPF, e-mail e senha para criar a conta |

### Pré-condições

- O passageiro não possui conta prévia com o mesmo CPF ou e-mail.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro informa CPF, e-mail e senha |
| 2 | Sistema valida formato e unicidade de CPF e e-mail |
| 3 | Sistema cria a conta e autentica o passageiro |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro deixa campo obrigatório em branco | Sistema exibe MSG-001 e mantém o formulário preenchido |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | CPF ou e-mail já cadastrado | Sistema recusa a criação e orienta login ou recuperação de senha | MSG-011 |
| FE-02 | CPF com formato inválido | Sistema recusa o cadastro | MSG-012 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-06 | CPF e e-mail são únicos por conta (Inferência Funcional) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cpf | Texto (11 dígitos) | Sim | CPF do passageiro |
| email | Texto (e-mail) | Sim | E-mail de contato e login |
| senha | Texto | Sim | Senha de acesso |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| conta_id | Identificador | Conta criada, usada nas demais funcionalidades |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Criar a própria conta |
| Atendente SAC | Não pode criar conta em nome do passageiro (Ponto a Validar — VAL-04) |

### Critérios de Aceite

- [ ] O sistema recusa cadastro com CPF ou e-mail já existente.
- [ ] O sistema recusa cadastro com campo obrigatório vazio.
- [ ] Após cadastro bem-sucedido, o passageiro fica autenticado.

### Dependências

- Nenhuma dependência funcional externa a este módulo.

### Observações

- O PRD não define regra de complexidade de senha; tratado como Ponto a Validar.

### Pontos a Validar

- VAL-05 — Regra de complexidade de senha não definida no PRD.

---

## FRD-auth-02 - Autenticar passageiro

### Descrição

O sistema deve permitir que o passageiro autentique-se com e-mail e senha para acessar as demais funcionalidades.

### Objetivo

Garantir que apenas o titular da conta acesse cartões, saldo, extrato e contestações vinculados a ela.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Informa e-mail e senha para autenticar |

### Pré-condições

- O passageiro possui conta cadastrada (FRD-auth-01).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro informa e-mail e senha |
| 2 | Sistema valida as credenciais |
| 3 | Sistema autentica o passageiro e concede acesso à conta |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro esquece a senha | Sistema oferece fluxo de recuperação de senha (Inferência Funcional — não detalhado no PRD) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | E-mail ou senha incorretos | Sistema recusa o login | MSG-013 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-06 | CPF e e-mail são únicos por conta (Inferência Funcional) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| email | Texto (e-mail) | Sim | E-mail cadastrado |
| senha | Texto | Sim | Senha cadastrada |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| sessao | Token/identificador de sessão | Concede acesso autenticado à conta |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Autenticar a própria conta |

### Critérios de Aceite

- [ ] Login com credenciais corretas concede acesso à conta.
- [ ] Login com credenciais incorretas é recusado com mensagem clara.

### Dependências

- FRD-auth-01 (conta previamente cadastrada).

### Observações

- Nenhuma.

### Pontos a Validar

- VAL-06 — Fluxo de recuperação de senha não descrito no PRD (Inferência Funcional necessária para MVP navegável).

---

## FRD-card-01 - Vincular cartão de transporte

### Descrição

O sistema deve permitir que o passageiro vincule um cartão de transporte à sua conta informando o número impresso (16 dígitos) e a data de nascimento do titular, respeitando o limite de 5 cartões por conta.

### Objetivo

Associar o cartão físico de transporte à conta digital para permitir recarga, consulta de saldo e bloqueio pelo passageiro.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Informa dados do cartão para vinculá-lo à conta |

### Pré-condições

- Passageiro autenticado (FRD-auth-02).
- Conta com menos de 5 cartões vinculados.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro informa número do cartão (16 dígitos) e data de nascimento do titular |
| 2 | Sistema valida os dados e confirma que o cartão não está vinculado a outra conta |
| 3 | Sistema vincula o cartão à conta do passageiro |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro tenta vincular 6º cartão | Sistema recusa e exibe MSG-004 |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Número de cartão com formato inválido (diferente de 16 dígitos) | Sistema recusa o vínculo | MSG-002 |
| FE-02 | Data de nascimento não confere com o titular do cartão | Sistema recusa o vínculo | MSG-014 |
| FE-03 | Cartão já vinculado a outra conta | Sistema recusa o vínculo | MSG-003 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-07 | Um cartão pode estar vinculado a no máximo uma conta por vez (Inferência Funcional) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| numero_cartao | Texto (16 dígitos) | Sim | Número impresso no cartão de transporte |
| data_nascimento_titular | Data | Sim | Data de nascimento do titular do cartão, usada como validação de posse |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| cartao_vinculado | Identificador | Cartão passa a aparecer na lista de cartões da conta |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Vincular cartão à própria conta |
| Atendente SAC | Não descrito no PRD como podendo vincular cartão em nome do passageiro |

### Critérios de Aceite

- [ ] O sistema recusa o vínculo de um 6º cartão na mesma conta.
- [ ] O sistema recusa vínculo com número de cartão fora do padrão de 16 dígitos.
- [ ] O sistema recusa vínculo quando a data de nascimento não confere com o titular.
- [ ] O sistema recusa vínculo de cartão já associado a outra conta.

### Dependências

- FRD-auth-02 (passageiro autenticado).

### Observações

- O PRD não especifica a fonte de verdade que associa cartão a titular/data de nascimento (provável integração com o sistema do bilhete eletrônico); tratado como dependência funcional externa (DEP-01).

### Pontos a Validar

- VAL-07 — Comportamento quando dois passageiros tentam vincular o mesmo cartão simultaneamente (condição de corrida) não descrito no PRD.

---

## FRD-card-02 - Bloquear cartão por perda

### Descrição

O sistema deve permitir que o passageiro bloqueie um cartão vinculado quando o cartão físico for perdido, preservando o saldo existente para transferência futura.

### Objetivo

Proteger o saldo do passageiro contra uso indevido de cartão perdido, sem transferir o saldo automaticamente (fora de escopo em v1, conforme OOS-03).

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Solicita o bloqueio do próprio cartão |

### Pré-condições

- Cartão vinculado à conta do passageiro (FRD-card-01).
- Cartão não está previamente bloqueado.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro seleciona o cartão perdido e solicita o bloqueio |
| 2 | Sistema confirma a ação com o passageiro |
| 3 | Sistema altera o status do cartão para bloqueado, preservando o saldo atual |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro cancela a confirmação de bloqueio | Sistema mantém o cartão ativo, sem alteração |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão já está bloqueado | Sistema informa que o cartão já se encontra bloqueado | MSG-015 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-05 | Cartão bloqueado preserva o saldo para transferência futura (v2) | 

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | Identificador | Sim | Cartão vinculado a ser bloqueado |
| confirmacao | Booleano | Sim | Confirmação explícita do passageiro antes do bloqueio |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_cartao | Enumerado (ativo/bloqueado) | Novo status do cartão após a ação |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Bloquear o próprio cartão |
| Atendente SAC | Bloquear cartão em nome do passageiro — Ponto a Validar (VAL-02, PRD §8) |

### Critérios de Aceite

- [ ] Após o bloqueio, o cartão não pode receber recarga (ver FRD-recharge-06).
- [ ] O saldo do cartão permanece inalterado após o bloqueio.
- [ ] O sistema não permite bloquear um cartão já bloqueado sem informar o estado atual.

### Dependências

- FRD-card-01 (cartão vinculado).
- FRD-recharge-06 (impedimento de recarga em cartão bloqueado).

### Observações

- A transferência efetiva do saldo preservado é F-06 apenas parcialmente coberta em v1; a transferência em si é OOS-03 (v2).

### Pontos a Validar

- VAL-02 — O PRD não define se o atendente SAC pode bloquear cartão em nome do passageiro (PRD §8, "Pontos em aberto").

---

## FRD-recharge-01 - Selecionar cartão e valor da recarga

### Descrição

O sistema deve permitir que o passageiro escolha, entre os cartões vinculados à sua conta, qual será recarregado, e informe o valor da recarga, respeitando o valor mínimo de R$ 5,00.

### Objetivo

Coletar as informações necessárias para iniciar o pagamento da recarga.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Seleciona cartão e informa valor |

### Pré-condições

- Passageiro autenticado.
- Passageiro possui ao menos um cartão vinculado e ativo (não bloqueado).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro seleciona um cartão vinculado |
| 2 | Passageiro informa o valor da recarga (mínimo R$ 5,00) |
| 3 | Sistema valida o valor e avança para a escolha do meio de pagamento |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro possui apenas um cartão vinculado | Sistema pré-seleciona o único cartão disponível (Inferência Funcional) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Valor informado inferior a R$ 5,00 | Sistema recusa o prosseguimento | MSG-005 |
| FE-02 | Cartão selecionado está bloqueado | Sistema recusa o prosseguimento (ver FRD-recharge-06) | MSG-007 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-04 | Valor máximo por recarga a ser definido pelo jurídico do consórcio (pendente) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | Identificador | Sim | Cartão vinculado a ser recarregado |
| valor | Monetário | Sim | Valor da recarga, mínimo R$ 5,00 |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| recarga_rascunho_id | Identificador | Intenção de recarga pronta para pagamento |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Selecionar cartão e valor para a própria recarga |

### Critérios de Aceite

- [ ] O sistema recusa valor abaixo de R$ 5,00.
- [ ] O sistema não permite selecionar cartão bloqueado.
- [ ] O sistema não permite selecionar cartão que não pertença à conta autenticada.

### Dependências

- FRD-card-01 (cartão vinculado).

### Observações

- Nenhuma.

### Pontos a Validar

- VAL-03 — Valor máximo por recarga ainda não definido pelo jurídico do consórcio (PRD RN-04).

---

## FRD-recharge-02 - Pagar recarga por Pix

### Descrição

O sistema deve permitir concluir o pagamento de uma recarga selecionada por meio de Pix.

### Objetivo

Oferecer meio de pagamento instantâneo, alinhado à jornada de "primeira recarga" (J-01) descrita no PRD.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Realiza o pagamento via Pix |

### Pré-condições

- Recarga com cartão e valor definidos (FRD-recharge-01).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro escolhe Pix como meio de pagamento |
| 2 | Sistema apresenta os dados para pagamento via Pix |
| 3 | Passageiro efetua o pagamento no aplicativo do seu banco |
| 4 | Sistema recebe a confirmação de pagamento |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro não conclui o pagamento dentro do prazo de validade do Pix (prazo não definido no PRD) | Sistema expira a intenção de recarga — Ponto a Validar (VAL-08) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Pagamento via Pix não confirmado (falha de integração) | Sistema não gera crédito e informa a falha | MSG-006 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | A recarga só gera crédito após confirmação do pagamento |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| recarga_rascunho_id | Identificador | Sim | Intenção de recarga a ser paga |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_pagamento | Enumerado (pendente/confirmado/falho) | Resultado do pagamento via Pix |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Pagar a própria recarga via Pix |

### Critérios de Aceite

- [ ] O crédito só é gerado após a confirmação do pagamento (ver FRD-recharge-04).
- [ ] Falha na confirmação do pagamento não gera crédito nem cobra o passageiro novamente.

### Dependências

- FRD-recharge-01 (cartão e valor definidos).
- FRD-recharge-04 (geração de crédito).

### Observações

- O mecanismo técnico de confirmação (webhook, polling etc.) é decisão de arquitetura, fora do escopo deste FRD.

### Pontos a Validar

- VAL-08 — Prazo de validade da cobrança Pix antes de expirar a intenção de recarga não definido no PRD.

---

## FRD-recharge-03 - Pagar recarga por cartão de crédito

### Descrição

O sistema deve permitir concluir o pagamento de uma recarga selecionada por meio de cartão de crédito.

### Objetivo

Oferecer um segundo meio de pagamento ao passageiro que não utiliza Pix.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Realiza o pagamento via cartão de crédito |

### Pré-condições

- Recarga com cartão de transporte e valor definidos (FRD-recharge-01).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro escolhe cartão de crédito como meio de pagamento |
| 2 | Passageiro informa os dados do cartão de crédito |
| 3 | Sistema envia a cobrança para processamento |
| 4 | Sistema recebe a confirmação de pagamento |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro salva o cartão de crédito para uso futuro | Não descrito no PRD — Inferência Funcional não assumida; tratar como fora de escopo até confirmação |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão de crédito recusado pela operadora | Sistema não gera crédito e informa a recusa | MSG-006 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | A recarga só gera crédito após confirmação do pagamento |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| recarga_rascunho_id | Identificador | Sim | Intenção de recarga a ser paga |
| dados_cartao_credito | Estruturado | Sim | Dados do cartão de crédito informados no ato do pagamento |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_pagamento | Enumerado (pendente/confirmado/falho) | Resultado do pagamento via cartão de crédito |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Pagar a própria recarga via cartão de crédito |

### Critérios de Aceite

- [ ] O crédito só é gerado após a confirmação do pagamento (ver FRD-recharge-04).
- [ ] Recusa da operadora não gera crédito nem duplica cobrança.

### Dependências

- FRD-recharge-01 (cartão e valor definidos).
- FRD-recharge-04 (geração de crédito).

### Observações

- Requisitos de segurança de dados de cartão (PCI DSS) pertencem ao NFRD, não a este FRD.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de recarga.

---

## FRD-recharge-04 - Gerar crédito após confirmação de pagamento

### Descrição

O sistema só deve gerar crédito no cartão de transporte após a confirmação do pagamento da recarga, independentemente do meio de pagamento utilizado.

### Objetivo

Evitar a geração de crédito sem contrapartida de pagamento confirmado, conforme RN-01 do PRD.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Beneficiário do crédito gerado |

### Pré-condições

- Pagamento da recarga confirmado (FRD-recharge-02 ou FRD-recharge-03).
- Cartão de destino não está bloqueado (FRD-recharge-06).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Sistema recebe confirmação de pagamento |
| 2 | Sistema verifica que o cartão de destino não está bloqueado e que não há duplicidade (FRD-recharge-05) |
| 3 | Sistema registra o crédito para envio ao validador do ônibus |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão de destino foi bloqueado entre o início e a confirmação da recarga | Sistema não gera o crédito e sinaliza a condição para tratamento (provável contestação) | MSG-007 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | A recarga só gera crédito após confirmação do pagamento |
| BR-03 | Cartão bloqueado não pode receber recarga |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| status_pagamento | Enumerado | Sim | Confirmação de pagamento recebida |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| credito_gerado | Registro de crédito | Crédito disponível para sincronização com o validador do ônibus |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Sistema | Geração automática do crédito, sem ação manual de nenhum perfil |

### Critérios de Aceite

- [ ] Nenhum crédito é gerado sem confirmação de pagamento.
- [ ] Nenhum crédito é gerado em cartão bloqueado, mesmo com pagamento confirmado.
- [ ] O passageiro é informado de que o crédito pode levar até 1 ciclo de sincronização do validador (até 30 minutos, conforme discovery) para aparecer no cartão físico.

### Dependências

- FRD-recharge-02, FRD-recharge-03 (confirmação de pagamento).
- FRD-recharge-05 (bloqueio de duplicidade).
- FRD-recharge-06 (impedimento em cartão bloqueado).
- DEP-02 (sincronização do validador do ônibus, a cada 30 minutos — sistema externo).

### Observações

- A comunicação ao passageiro sobre o prazo de até 1 ciclo de sincronização (PRD, Visão) é o principal ponto de mitigação funcional da queixa de "recarga que não caiu", registrada nas notas de discovery (900 reclamações/mês ao SAC).

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de recarga.

---

## FRD-recharge-05 - Bloquear recarga duplicada

### Descrição

O sistema não deve aceitar duas recargas de mesmo valor no mesmo cartão em um intervalo menor que 2 minutos, como proteção contra duplicidade.

### Objetivo

Evitar cobrança duplicada acidental do passageiro (ex.: duplo toque no botão de pagar).

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Solicitante da recarga potencialmente duplicada |

### Pré-condições

- Existe uma recarga anterior do mesmo valor, no mesmo cartão, com menos de 2 minutos de diferença.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro solicita uma nova recarga |
| 2 | Sistema verifica se há recarga de mesmo valor no mesmo cartão nos últimos 2 minutos |
| 3 | Sistema segue o fluxo normal se não houver duplicidade |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Recarga de mesmo valor, mesmo cartão, em menos de 2 minutos | Sistema recusa a nova recarga | MSG-008 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-02 | Um mesmo cartão não pode receber duas recargas de mesmo valor em menos de 2 minutos |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | Identificador | Sim | Cartão de destino da nova recarga |
| valor | Monetário | Sim | Valor da nova recarga |
| instante_solicitacao | Data/hora | Sim | Momento da nova solicitação |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| resultado_verificacao | Booleano | Indica se a recarga foi aceita ou recusada por duplicidade |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Sistema | Verificação automática, sem ação manual de nenhum perfil |

### Critérios de Aceite

- [ ] Duas recargas de mesmo valor no mesmo cartão com menos de 2 minutos entre si são recusadas na segunda tentativa.
- [ ] Recargas de valores diferentes no mesmo cartão, mesmo em menos de 2 minutos, não são bloqueadas por esta regra.

### Dependências

- FRD-recharge-01 (dados da nova recarga).

### Observações

- **Dependência arquitetural:** ADR-0001 — `mecanismo-de-idempotencia-de-recarga` (a ser criado via `adr-writer`). A decisão entre token de idempotência gerado pelo cliente e verificação por janela de tempo/hash de payload no servidor tem custo de reversão alto e afeta diretamente o comportamento de BR-02.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de recarga.

---

## FRD-recharge-06 - Impedir recarga em cartão bloqueado

### Descrição

O sistema não deve permitir que um cartão com status bloqueado receba uma nova recarga.

### Objetivo

Impedir que um cartão perdido, já bloqueado pelo passageiro, continue recebendo crédito.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Solicitante da recarga recusada |

### Pré-condições

- Cartão selecionado está com status bloqueado (FRD-card-02).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro tenta selecionar um cartão bloqueado para recarga |
| 2 | Sistema verifica o status do cartão |
| 3 | Sistema recusa o prosseguimento |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Cartão selecionado está bloqueado | Sistema recusa a recarga | MSG-007 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-03 | Cartão bloqueado não pode receber recarga |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | Identificador | Sim | Cartão a ser verificado |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_cartao | Enumerado (ativo/bloqueado) | Status usado para permitir ou recusar a recarga |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Sistema | Verificação automática, sem ação manual de nenhum perfil |

### Critérios de Aceite

- [ ] Nenhuma recarga é concluída em cartão com status bloqueado.
- [ ] O passageiro recebe mensagem clara informando que o cartão está bloqueado.

### Dependências

- FRD-card-02 (bloqueio de cartão).

### Observações

- Nenhuma.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de recarga.

---

## FRD-balance-01 - Consultar saldo

### Descrição

O sistema deve exibir ao passageiro o saldo atual de cada cartão de transporte vinculado à sua conta.

### Objetivo

Reduzir a incerteza do passageiro sobre "se a recarga caiu", identificada como principal dor nas entrevistas de discovery.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Consulta o saldo dos próprios cartões |

### Pré-condições

- Passageiro autenticado.
- Passageiro possui ao menos um cartão vinculado.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro acessa a área de saldo |
| 2 | Sistema exibe o saldo atual de cada cartão vinculado |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro possui múltiplos cartões | Sistema exibe o saldo individual de cada um, sem consolidação (Inferência Funcional) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Nenhum cartão vinculado à conta | Sistema orienta o passageiro a vincular um cartão | MSG-016 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra de negócio específica além do escopo geral de autenticação |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| conta_id | Identificador | Sim | Conta autenticada cujo(s) cartão(ões) serão consultados |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| saldo_por_cartao | Lista de valores monetários | Saldo atual de cada cartão vinculado |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Consultar saldo dos próprios cartões |
| Atendente SAC | Consultar saldo em nome do passageiro (PRD F-05 — "consulta recargas") |
| Analista Financeiro | Consultar saldo para fins de conciliação (PRD F-05, persona P-03) |

### Critérios de Aceite

- [ ] O saldo exibido reflete os créditos já sincronizados pelo validador.
- [ ] O sistema informa quando o saldo pode não refletir uma recarga recém-paga, ainda em ciclo de sincronização.

### Dependências

- FRD-card-01 (cartão vinculado).
- FRD-recharge-04 (crédito gerado).

### Observações

- O saldo exibido no app é o saldo lógico do sistema, que pode estar até 1 ciclo de sincronização (30 minutos, fonte: discovery) à frente do saldo físico no validador do ônibus.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados.

---

## FRD-balance-02 - Consultar extrato de 90 dias

### Descrição

O sistema deve exibir ao passageiro as recargas e os usos dos últimos 90 dias de cada cartão vinculado.

### Objetivo

Dar visibilidade histórica ao passageiro, hoje indisponível fora do posto físico (PRD, Problema).

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Consulta o próprio histórico |

### Pré-condições

- Passageiro autenticado.
- Passageiro possui ao menos um cartão vinculado.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro acessa o extrato de um cartão |
| 2 | Sistema exibe recargas e usos dos últimos 90 dias, em ordem cronológica |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Cartão sem movimentação no período | Sistema exibe extrato vazio com mensagem informativa (Inferência Funcional) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Falha ao carregar o extrato | Sistema informa indisponibilidade temporária | MSG-017 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra de negócio específica além da janela de 90 dias definida no PRD |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| cartao_id | Identificador | Sim | Cartão cujo extrato será consultado |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| extrato | Lista de movimentações | Recargas e usos dos últimos 90 dias |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Consultar o próprio extrato |
| Atendente SAC | Consultar extrato em nome do passageiro para tratar contestação |
| Analista Financeiro | Consultar extrato para fins de conciliação |

### Critérios de Aceite

- [ ] O extrato cobre exatamente os últimos 90 dias a partir da data de consulta.
- [ ] O extrato distingue recargas de usos.

### Dependências

- FRD-card-01 (cartão vinculado).

### Observações

- Nenhuma.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados.

---

## FRD-dispute-01 - Abrir contestação de recarga

### Descrição

O sistema deve permitir que o passageiro conteste uma recarga que foi paga mas não gerou crédito no cartão.

### Objetivo

Dar ao passageiro um canal formal para reportar a falha de "recarga que não caiu", hoje responsável por cerca de 900 reclamações/mês ao SAC (fonte: discovery).

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Abre a contestação sobre a própria recarga |

### Pré-condições

- Existe uma recarga com pagamento confirmado (FRD-recharge-02 ou FRD-recharge-03) sem crédito correspondente gerado (FRD-recharge-04).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro seleciona a recarga não creditada |
| 2 | Passageiro confirma a abertura da contestação |
| 3 | Sistema registra a contestação com status "aberta" e a disponibiliza para o SAC |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Passageiro abre contestação antes do fim do ciclo de sincronização do validador (30 minutos) | Sistema alerta que o crédito pode ainda estar em processamento antes de confirmar a abertura (Inferência Funcional, mitigação da queixa de discovery) |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Recarga já possui contestação em aberto | Sistema recusa nova contestação para a mesma recarga | MSG-009 |
| FE-02 | Recarga selecionada já gerou crédito | Sistema informa que a recarga já foi creditada | MSG-018 |
| FE-03 | Prazo para contestar expirado | Sistema recusa a abertura — **prazo não definido no PRD** | MSG-019 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| BR-01 | A recarga só gera crédito após confirmação do pagamento (contexto da falha contestada) |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| recarga_id | Identificador | Sim | Recarga paga sem crédito correspondente |
| motivo | Texto | Não | Detalhamento opcional do passageiro |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| contestacao_id | Identificador | Contestação registrada com status "aberta" |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Abrir contestação sobre a própria recarga |

### Critérios de Aceite

- [ ] Não é possível abrir uma segunda contestação para a mesma recarga enquanto a primeira estiver em aberto.
- [ ] Não é possível contestar recarga já creditada.
- [ ] A contestação registrada fica visível para o atendente SAC.

### Dependências

- FRD-recharge-04 (crédito não gerado).
- FRD-dispute-02 (abertura em nome do passageiro pelo SAC, fluxo equivalente).

### Observações

- O prazo de contestação (FE-03) é citado no PRD como pendente ("Pontos em aberto") e não pode ser implementado sem definição de produto.

### Pontos a Validar

- VAL-01 — O prazo para o passageiro abrir contestação ainda não foi definido (PRD §8, "Pontos em aberto").

---

## FRD-dispute-02 - Abrir contestação em nome do passageiro

### Descrição

O sistema deve permitir que o atendente SAC abra, em nome do passageiro, uma contestação sobre recarga paga que não gerou crédito.

### Objetivo

Dar ao SAC ferramenta para tratar diretamente o alto volume de reclamações (900/mês, fonte: discovery) sem depender de o próprio passageiro abrir a contestação pelo app.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Atendente SAC (ACT-02) | Abre a contestação em nome do passageiro |
| Passageiro (ACT-01) | Titular da recarga contestada |

### Pré-condições

- Atendente SAC autenticado com acesso à conta do passageiro que reportou a falha.
- Existe recarga paga sem crédito correspondente.

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Atendente SAC localiza a conta e a recarga não creditada reportada pelo passageiro |
| 2 | Atendente SAC registra a contestação em nome do passageiro |
| 3 | Sistema registra a contestação com status "aberta", identificando o SAC como solicitante em nome do passageiro |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Recarga já possui contestação em aberto | Sistema recusa nova contestação para a mesma recarga | MSG-009 |
| FE-02 | Recarga selecionada já gerou crédito | Sistema informa que a recarga já foi creditada | MSG-018 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Regras equivalentes às de FRD-dispute-01, aplicadas ao contexto do SAC |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| conta_id | Identificador | Sim | Conta do passageiro em nome de quem a contestação é aberta |
| recarga_id | Identificador | Sim | Recarga paga sem crédito correspondente |
| atendente_id | Identificador | Sim | Atendente SAC responsável pela abertura |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| contestacao_id | Identificador | Contestação registrada, com origem "SAC" |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Atendente SAC | Abrir contestação em nome de qualquer passageiro |
| Passageiro | Não aplicável a este requisito |

### Critérios de Aceite

- [ ] A contestação aberta pelo SAC registra o atendente responsável, para auditoria.
- [ ] O passageiro consegue ver, no próprio extrato/consulta, uma contestação aberta pelo SAC em seu nome.

### Dependências

- FRD-dispute-01 (regras equivalentes de duplicidade e elegibilidade).

### Observações

- O PRD (F-05) já autoriza explicitamente o atendente SAC a contestar em nome do passageiro; distinto do bloqueio de cartão em nome do passageiro (VAL-02), que permanece em aberto.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de contestação.

---

## FRD-dispute-03 - Decidir estorno

### Descrição

O sistema deve permitir que o analista financeiro aprove ou negue o estorno de uma contestação aberta.

### Objetivo

Dar ao financeiro uma ferramenta para decidir formalmente o desfecho de cada contestação, substituindo a conciliação manual em planilha hoje feita uma vez ao dia (fonte: discovery).

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Analista Financeiro (ACT-03) | Aprova ou nega o estorno |
| Passageiro (ACT-01) | Beneficiário do estorno, se aprovado |

### Pré-condições

- Existe contestação com status "aberta" (FRD-dispute-01 ou FRD-dispute-02).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Analista financeiro analisa a contestação e a recarga associada |
| 2 | Analista financeiro registra a decisão (aprovar ou negar o estorno) |
| 3 | Sistema atualiza o status da contestação e, se aprovado, registra o estorno |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Analista tenta decidir contestação já decidida | Sistema recusa nova decisão sobre a mesma contestação | MSG-010 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra explícita no PRD sobre critérios de aprovação/negação do estorno |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| contestacao_id | Identificador | Sim | Contestação a ser decidida |
| decisao | Enumerado (aprovado/negado) | Sim | Decisão do analista financeiro |
| justificativa | Texto | Não | Motivo da decisão, para auditoria |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_contestacao | Enumerado (aprovada/negada) | Status final da contestação |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Analista Financeiro | Aprovar ou negar estorno |
| Passageiro | Não pode decidir a própria contestação |
| Atendente SAC | Não pode decidir estorno (apenas abrir e acompanhar) |

### Critérios de Aceite

- [ ] Uma contestação decidida não pode ser decidida novamente.
- [ ] O passageiro e o atendente SAC conseguem ver o resultado da decisão (ver FRD-dispute-04).
- [ ] Estorno aprovado gera registro auditável de valor e cartão de destino.

### Dependências

- FRD-dispute-01, FRD-dispute-02 (contestação aberta).

### Observações

- O PRD não define critérios objetivos de aprovação/negação; tratado como decisão de julgamento do analista financeiro, fora do escopo de automação deste FRD.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de contestação.

---

## FRD-dispute-04 - Acompanhar contestação

### Descrição

O sistema deve permitir que o passageiro e o atendente SAC acompanhem o status de uma contestação aberta, do registro até a decisão do financeiro.

### Objetivo

Dar visibilidade de status à jornada "recarga não caiu" (J-02), reduzindo a necessidade de reclamações repetidas ao SAC.

### Atores Envolvidos

| Ator | Papel no Requisito |
|---|---|
| Passageiro (ACT-01) | Acompanha a própria contestação |
| Atendente SAC (ACT-02) | Acompanha contestações sob sua responsabilidade ou reportadas ao SAC |

### Pré-condições

- Existe contestação registrada (FRD-dispute-01 ou FRD-dispute-02).

### Fluxo Principal

| Passo | Ação |
|---|---|
| 1 | Passageiro ou atendente SAC acessa a contestação |
| 2 | Sistema exibe o status atual (aberta, aprovada ou negada) |

### Fluxos Alternativos

| Código | Condição | Fluxo |
|---|---|---|
| FA-01 | Nenhum fluxo alternativo identificado no PRD | — |

### Fluxos de Exceção

| Código | Condição | Comportamento Esperado | Mensagem |
|---|---|---|---|
| FE-01 | Contestação não encontrada ou não pertence ao solicitante | Sistema recusa o acesso | MSG-020 |

### Regras de Negócio Aplicáveis

| Código | Regra |
|---|---|
| — | Nenhuma regra de negócio específica além do controle de acesso por perfil |

### Entradas

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| contestacao_id | Identificador | Sim | Contestação a ser consultada |

### Saídas

| Campo | Tipo | Descrição |
|---|---|---|
| status_contestacao | Enumerado (aberta/aprovada/negada) | Status atual da contestação |

### Permissões

| Perfil/Papel | Permissão |
|---|---|
| Passageiro | Acompanhar as próprias contestações |
| Atendente SAC | Acompanhar contestações de qualquer passageiro |
| Analista Financeiro | Acompanhar contestações pendentes de decisão |

### Critérios de Aceite

- [ ] O passageiro só acompanha as próprias contestações.
- [ ] O atendente SAC acompanha contestações de qualquer passageiro.

### Dependências

- FRD-dispute-01, FRD-dispute-02, FRD-dispute-03.

### Observações

- Nenhuma.

### Pontos a Validar

- Nenhum ponto adicional além dos já registrados para o módulo de contestação.

---

## 12. Casos de Uso

## UC-01 - Primeira recarga

| Campo | Descrição |
|---|---|
| Objetivo | Permitir que um novo passageiro cadastre-se, vincule o cartão de transporte e realize a primeira recarga via Pix |
| Ator Principal | Passageiro |
| Atores Secundários | Nenhum |
| Pré-condições | Passageiro não possui conta prévia |
| Pós-condições | Conta criada, cartão vinculado e recarga com crédito gerado (sujeito ao ciclo de sincronização do validador) |
| Requisitos Relacionados | FRD-auth-01, FRD-auth-02, FRD-card-01, FRD-recharge-01, FRD-recharge-02, FRD-recharge-04 |

### Fluxo Principal

| Passo | Descrição |
|---|---|
| 1 | Passageiro cria a conta (FRD-auth-01) e é autenticado (FRD-auth-02) |
| 2 | Passageiro vincula o cartão de transporte (FRD-card-01) |
| 3 | Passageiro seleciona o cartão e informa o valor da recarga (FRD-recharge-01) |
| 4 | Passageiro paga via Pix (FRD-recharge-02) |
| 5 | Sistema confirma o pagamento e gera o crédito (FRD-recharge-04) |
| 6 | Sistema informa ao passageiro que o crédito pode levar até 1 ciclo de sincronização do validador |

### Fluxos Alternativos

| Código | Descrição |
|---|---|
| FA-01 | Passageiro já possui conta e apenas vincula um novo cartão antes de recarregar |

### Fluxos de Exceção

| Código | Erro | Tratamento |
|---|---|---|
| FE-01 | Cadastro recusado por CPF/e-mail duplicado | Ver FRD-auth-01, MSG-011 |
| FE-02 | Vínculo de cartão recusado (limite, dados inválidos ou cartão já vinculado) | Ver FRD-card-01, MSG-002/003/004/014 |
| FE-03 | Pagamento Pix não confirmado | Ver FRD-recharge-02, MSG-006 |

---

## UC-02 - Recarga não caiu

| Campo | Descrição |
|---|---|
| Objetivo | Tratar o cenário de recarga paga que não gerou crédito, da contestação à decisão de estorno |
| Ator Principal | Passageiro |
| Atores Secundários | Atendente SAC, Analista Financeiro |
| Pré-condições | Existe recarga paga sem crédito correspondente |
| Pós-condições | Contestação decidida (aprovada com estorno ou negada) |
| Requisitos Relacionados | FRD-dispute-01, FRD-dispute-02, FRD-dispute-03, FRD-dispute-04 |

### Fluxo Principal

| Passo | Descrição |
|---|---|
| 1 | Passageiro percebe que a recarga paga não apareceu no saldo/extrato (FRD-balance-01, FRD-balance-02) |
| 2 | Passageiro abre contestação pelo app (FRD-dispute-01) |
| 3 | Atendente SAC acompanha a contestação (FRD-dispute-04) |
| 4 | Analista financeiro analisa e decide o estorno (FRD-dispute-03) |
| 5 | Passageiro e SAC acompanham o resultado (FRD-dispute-04) |

### Fluxos Alternativos

| Código | Descrição |
|---|---|
| FA-01 | Passageiro reporta a falha por outro canal e o atendente SAC abre a contestação em seu nome (FRD-dispute-02) |

### Fluxos de Exceção

| Código | Erro | Tratamento |
|---|---|---|
| FE-01 | Contestação duplicada para a mesma recarga | Ver FRD-dispute-01/02, MSG-009 |
| FE-02 | Prazo de contestação expirado | Ver FRD-dispute-01, MSG-019 — depende de VAL-01 |

---

## 13. Regras de Negócio

| Código | Regra | Descrição | Requisitos Relacionados | Fonte |
|---|---|---|---|---|
| BR-01 | Crédito só após confirmação de pagamento | A recarga só gera crédito após confirmação do pagamento | FRD-recharge-02, FRD-recharge-03, FRD-recharge-04 | PRD RN-01 |
| BR-02 | Bloqueio de recarga duplicada | Um mesmo cartão não pode receber duas recargas de mesmo valor em menos de 2 minutos | FRD-recharge-05 | PRD RN-02 |
| BR-03 | Cartão bloqueado não recarrega | Cartão bloqueado não pode receber recarga | FRD-recharge-06, FRD-recharge-04 | PRD RN-03 |
| BR-04 | Valor máximo por recarga (pendente) | O valor máximo por recarga será definido pelo jurídico do consórcio | FRD-recharge-01 | PRD RN-04 |
| BR-05 | Preservação de saldo no bloqueio | Cartão bloqueado por perda preserva o saldo para transferência futura (transferência em si é v2) | FRD-card-02 | PRD F-06, §7 |
| BR-06 | Unicidade de CPF e e-mail | CPF e e-mail são únicos por conta (Inferência Funcional) | FRD-auth-01, FRD-auth-02 | Inferência Funcional |
| BR-07 | Cartão vinculado a uma única conta | Um cartão de transporte só pode estar vinculado a uma conta por vez (Inferência Funcional) | FRD-card-01 | Inferência Funcional |

---

## 14. Mensagens de Erro e Validação

| Código | Cenário | Mensagem | Tipo | Requisito Relacionado |
|---|---|---|---|---|
| MSG-001 | Campo obrigatório não informado | O campo [nome] é obrigatório. | Validação | FRD-auth-01 |
| MSG-002 | Número de cartão fora do padrão de 16 dígitos | O número do cartão deve ter 16 dígitos. | Validação | FRD-card-01 |
| MSG-003 | Cartão já vinculado a outra conta | Este cartão já está vinculado a outra conta. | Erro de Negócio | FRD-card-01 |
| MSG-004 | Limite de 5 cartões atingido | Você já atingiu o limite de 5 cartões por conta. | Erro de Negócio | FRD-card-01 |
| MSG-005 | Valor de recarga abaixo do mínimo | O valor mínimo de recarga é R$ 5,00. | Validação | FRD-recharge-01 |
| MSG-006 | Pagamento recusado ou não confirmado | Não foi possível confirmar o pagamento. Tente novamente. | Erro de Integração | FRD-recharge-02, FRD-recharge-03 |
| MSG-007 | Cartão bloqueado não pode receber recarga | Este cartão está bloqueado e não pode ser recarregado. | Erro de Negócio | FRD-recharge-06 |
| MSG-008 | Recarga duplicada em menos de 2 minutos | Já identificamos uma recarga de mesmo valor recente neste cartão. | Erro de Negócio | FRD-recharge-05 |
| MSG-009 | Contestação já aberta para a recarga | Já existe uma contestação em aberto para esta recarga. | Erro de Negócio | FRD-dispute-01, FRD-dispute-02 |
| MSG-010 | Contestação já decidida | Esta contestação já foi decidida e não pode ser alterada. | Erro de Negócio | FRD-dispute-03 |
| MSG-011 | CPF ou e-mail já cadastrado | Já existe uma conta com este CPF ou e-mail. | Erro de Negócio | FRD-auth-01 |
| MSG-012 | CPF com formato inválido | Informe um CPF válido. | Validação | FRD-auth-01 |
| MSG-013 | Credenciais de login incorretas | E-mail ou senha incorretos. | Erro de Permissão | FRD-auth-02 |
| MSG-014 | Data de nascimento não confere com o titular | A data de nascimento informada não confere com o titular do cartão. | Validação | FRD-card-01 |
| MSG-015 | Cartão já bloqueado | Este cartão já está bloqueado. | Alerta | FRD-card-02 |
| MSG-016 | Nenhum cartão vinculado | Vincule um cartão para consultar o saldo. | Alerta | FRD-balance-01 |
| MSG-017 | Falha ao carregar extrato | Não foi possível carregar o extrato agora. Tente novamente. | Erro Sistêmico | FRD-balance-02 |
| MSG-018 | Recarga já creditada | Esta recarga já foi creditada e não pode ser contestada. | Erro de Negócio | FRD-dispute-01, FRD-dispute-02 |
| MSG-019 | Prazo de contestação expirado | O prazo para contestar esta recarga já expirou. | Erro de Negócio | FRD-dispute-01 |
| MSG-020 | Contestação não encontrada ou sem permissão | Você não tem acesso a esta contestação. | Erro de Permissão | FRD-dispute-04 |

---

## 15. Matriz de Permissões Funcionais

| Funcionalidade | Passageiro | Atendente SAC | Analista Financeiro |
|---|---|---|---|
| Cadastrar/autenticar a própria conta | Sim | Não | Não |
| Vincular cartão de transporte | Sim | Não (VAL-04) | Não |
| Bloquear cartão por perda | Sim | Ponto a Validar (VAL-02) | Não |
| Selecionar cartão/valor e pagar recarga | Sim | Não | Não |
| Consultar saldo | Sim (próprio) | Sim (em nome do passageiro) | Sim (para conciliação) |
| Consultar extrato | Sim (próprio) | Sim (em nome do passageiro) | Sim (para conciliação) |
| Abrir contestação | Sim (própria) | Sim (em nome do passageiro) | Não |
| Acompanhar contestação | Sim (própria) | Sim (qualquer) | Sim (pendentes de decisão) |
| Aprovar/negar estorno | Não | Não | Sim |

---

## 16. Matriz de Rastreabilidade

| Item PRD | Descrição PRD | Requisito FRD | Status |
|---|---|---|---|
| F-01 | Cadastro e login | FRD-auth-01, FRD-auth-02 | Coberto |
| F-02 | Vincular cartão | FRD-card-01 | Coberto |
| F-03 | Recarregar | FRD-recharge-01, FRD-recharge-02, FRD-recharge-03 | Coberto |
| F-04 | Consultar saldo e extrato | FRD-balance-01, FRD-balance-02 | Coberto |
| F-05 | Contestação de recarga | FRD-dispute-01, FRD-dispute-02, FRD-dispute-03, FRD-dispute-04 | Coberto |
| F-06 | Bloqueio por perda | FRD-card-02 | Parcialmente Coberto — bloqueio em nome do passageiro pelo SAC é Ponto a Validar (VAL-02) |
| RN-01 | Crédito só após confirmação de pagamento | FRD-recharge-04 | Coberto |
| RN-02 | Proteção contra recarga duplicada | FRD-recharge-05 | Coberto |
| RN-03 | Cartão bloqueado não recebe recarga | FRD-recharge-06 | Coberto |
| RN-04 | Valor máximo por recarga (pendente) | FRD-recharge-01 | Ponto a Validar |
| J-01 | Primeira recarga | UC-01 | Coberto |
| J-02 | Recarga não caiu | UC-02 | Coberto |
| PRD §8 — prazo de contestação | Prazo não definido | FRD-dispute-01 | Ponto a Validar |
| PRD §8 — SAC bloqueia cartão em nome do passageiro | Permissão não definida | FRD-card-02 | Ponto a Validar |

---

## 17. Dependências Funcionais

| Código | Dependência | Tipo | Impacto |
|---|---|---|---|
| DEP-01 | Fonte de verdade que associa número de cartão e data de nascimento do titular | Externa (provável sistema do bilhete eletrônico do Consórcio) | Bloqueia a validação de FRD-card-01 sem integração definida |
| DEP-02 | Sincronização do validador do ônibus a cada 30 minutos | Externa (limitação de equipamento, conforme discovery) | Define a mensagem de expectativa de crédito em FRD-recharge-04 e a condição de bloqueio em FRD-dispute-01 |
| DEP-03 | Meios de pagamento Pix e cartão de crédito | Externa (adquirente/PSP) | Bloqueia FRD-recharge-02 e FRD-recharge-03 sem contrato de integração definido (fora do escopo deste FRD) |

---

## 18. Premissas

| Código | Premissa | Impacto |
|---|---|---|
| PRE-01 | O passageiro tem acesso a um aplicativo bancário compatível com Pix | Necessária para FRD-recharge-02 |
| PRE-02 | O número de cartão e a data de nascimento do titular são suficientes como prova de posse do cartão físico | Necessária para FRD-card-01; sujeita a revisão de segurança fora do escopo deste FRD |
| PRE-03 | O SAC e o Financeiro operam por interface própria (não necessariamente o mesmo app do passageiro) | Impacta o desenho de FRD-dispute-02, FRD-dispute-03, FRD-dispute-04, mas não a lógica funcional descrita |

---

## 19. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-01 | Prazo para o passageiro abrir contestação não definido | PRD §8 | Impede especificar completamente FRD-dispute-01 (FE-03) | Definir prazo com produto/jurídico antes de codificar FE-03 |
| VAL-02 | Não está claro se o atendente SAC pode bloquear cartão em nome do passageiro | PRD §8 | Impede especificar completamente a permissão de FRD-card-02 | Confirmar com produto; se sim, tratar como delegação análoga à de FRD-dispute-02 |
| VAL-03 | Valor máximo por recarga ainda não definido pelo jurídico | PRD RN-04 | Impede completar validação de valor em FRD-recharge-01 | Aguardar definição jurídica antes de implementar o teto |
| VAL-04 | Não está definido se o SAC pode vincular cartão em nome do passageiro | Inferência Funcional (ausência no PRD) | Impacta o escopo de permissões de FRD-card-01 | Confirmar com produto se o SAC precisa dessa capacidade para atendimento |
| VAL-05 | Regra de complexidade de senha não definida | Inferência Funcional (ausência no PRD) | Impacta critérios de aceite de FRD-auth-01 | Definir política mínima de senha com produto/segurança |
| VAL-06 | Fluxo de recuperação de senha não descrito no PRD | Inferência Funcional (ausência no PRD) | Impacta a completude de FRD-auth-02 | Especificar fluxo de recuperação como funcionalidade complementar |
| VAL-07 | Comportamento em condição de corrida ao vincular o mesmo cartão em duas contas simultaneamente | Inferência Funcional (ausência no PRD) | Impacta a robustez de FRD-card-01 | Definir regra de desempate (ex.: primeira confirmação vence) |
| VAL-08 | Prazo de validade da cobrança Pix antes de expirar a intenção de recarga | Inferência Funcional (ausência no PRD) | Impacta FRD-recharge-02 (FA-01) | Definir prazo padrão de expiração com produto |

---

## 20. Anexos

Nenhum anexo funcional adicional neste ciclo. Diagramas de fluxo (jornadas J-01/J-02) podem ser adicionados em revisão futura, quando houver protótipo de UX disponível para referência cruzada.
