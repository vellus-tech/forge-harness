# PRD - Recarga Metropolitana

**Produto:** Recarga Metropolitana
**Versão:** v1.1
**Data:** 2026-09-22
**Status:** Aprovado (comitê de produto de 2026-09-21)

| Versão | Data | Mudança |
|---|---|---|
| v1.0 | 2026-09-10 | Versão inicial |
| v1.1 | 2026-09-22 | Inclui F-07 (recarga recorrente com cartão salvo) e RN-05 |

## 1. Visão

App e web para o passageiro do Consórcio Metropolitano recarregar o cartão de transporte (bilhete eletrônico) por Pix ou cartão de crédito, sem fila no posto de atendimento, com o crédito disponível no validador do ônibus em até 1 ciclo de sincronização.

## 2. Problema

Hoje 68% das recargas acontecem nos postos físicos, com fila média de 22 minutos nos horários de pico. O passageiro não consegue consultar o saldo nem o histórico de uso fora do posto.

## 3. Personas

| Código | Persona | Descrição |
|---|---|---|
| P-01 | Passageiro | Titular de um ou mais cartões de transporte; recarrega e consulta saldo |
| P-02 | Atendente SAC | Colaborador do consórcio que consulta recargas e abre contestação em nome do passageiro |
| P-03 | Analista Financeiro | Colaborador que concilia recargas pagas com créditos gerados e aprova estornos |

## 4. Funcionalidades

| Código | Funcionalidade | Descrição |
|---|---|---|
| F-01 | Cadastro e login | Passageiro cria conta com CPF, e-mail e senha; login por e-mail e senha |
| F-02 | Vincular cartão | Passageiro vincula cartão de transporte informando o número impresso (16 dígitos) e a data de nascimento do titular; máximo de 5 cartões por conta |
| F-03 | Recarregar | Passageiro escolhe o cartão, o valor (mínimo R$ 5,00) e paga por Pix ou cartão de crédito |
| F-04 | Consultar saldo e extrato | Passageiro vê o saldo e as últimas 90 dias de recargas e usos |
| F-05 | Contestação de recarga | Passageiro ou atendente SAC contesta recarga paga que não virou crédito; analista financeiro aprova ou nega o estorno |
| F-06 | Bloqueio por perda | Passageiro bloqueia cartão perdido; o saldo fica preservado para transferência futura |
| F-07 | Recarga recorrente com cartão salvo | Passageiro salva um cartão de crédito e agenda recarga automática semanal ou mensal de valor fixo; pode pausar ou cancelar a qualquer momento |

## 5. Regras de negócio explícitas

- RN-01: A recarga só gera crédito após confirmação do pagamento.
- RN-02: Um mesmo cartão não pode receber duas recargas de mesmo valor em menos de 2 minutos (proteção contra duplicidade).
- RN-03: Cartão bloqueado não pode receber recarga.
- RN-04: O valor máximo por recarga será definido pelo jurídico do consórcio (pendente).
- RN-05: O app nunca armazena o número completo nem o CVV do cartão de crédito salvo; a recarga recorrente usa apenas o token devolvido pelo adquirente (exigência PCI DSS, vale para qualquer funcionalidade futura que cobre cartão salvo).

## 6. Jornadas

- J-01: Primeira recarga — cadastro, vínculo do cartão, recarga por Pix, confirmação.
- J-02: Recarga não caiu — passageiro abre contestação; SAC acompanha; financeiro decide o estorno.

## 7. Fora de escopo (v1)

- Programa de fidelidade ou cashback.
- Recarga por boleto.
- Transferência de saldo entre cartões (fica para v2; F-06 só preserva o saldo).
- Venda de cartão novo pelo app.

## 8. Pontos em aberto

- O prazo para o passageiro abrir contestação ainda não foi definido.
- Não está claro se o atendente SAC pode bloquear cartão em nome do passageiro.
