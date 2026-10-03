# ADR-0004 — Ledger de créditos do cartão transporte em PostgreSQL

- Status: Aceito
- Data: 2026-08-14
- Decisores: @arquitetura, @produto

## Contexto

O ledger de créditos do cartão transporte (lançamentos de crédito por recarga, débito por embarque, estorno e saldo derivado) exige integridade referencial forte com a tabela de parâmetros tarifários e reconciliação diária com as operadoras via SQL. A `data-governance.md` atribui transacional de negócio ao MongoDB por padrão; este ADR registra a exceção para o ledger.

## Decisão

O ledger de créditos (tabelas de lançamento e de saldo) fica em PostgreSQL, no mesmo cluster dos parâmetros tarifários, com RLS por `tenant_id` (cada operadora é um tenant). O escopo deste ADR é só o ledger; nenhum outro dado transacional ou de telemetria é coberto por ele.

## Consequências

Dados transacionais fora do ledger seguem a `data-governance.md` (MongoDB). Qualquer extensão deste ADR a outro dado exige novo ADR.
