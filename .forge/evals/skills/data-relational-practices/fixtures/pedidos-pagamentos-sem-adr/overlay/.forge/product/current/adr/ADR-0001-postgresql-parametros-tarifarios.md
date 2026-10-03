---
id: ADR-0001
title: PostgreSQL para parâmetros tarifários do serviço de recargas
status: accepted
date: 2026-07-02
---

# ADR-0001 — PostgreSQL para parâmetros tarifários do serviço de recargas

## Contexto

O serviço de recargas precisa de parâmetros por operadora (valor de face permitido, limites diários, produtos habilitados) com integridade referencial entre operadora, produto e canal.

## Decisão

Os parâmetros tarifários e de produto do serviço de recargas ficam em PostgreSQL 16, no schema `recargas_param`, seguindo a `rules/data/data-governance.md` (parâmetros e configuração → PostgreSQL) e a `rules/data/data-config-sql.md`.

## Fora do escopo

Esta decisão não trata o armazenamento dos pedidos de recarga, pagamentos nem conciliação; isso será objeto de outra decisão.
