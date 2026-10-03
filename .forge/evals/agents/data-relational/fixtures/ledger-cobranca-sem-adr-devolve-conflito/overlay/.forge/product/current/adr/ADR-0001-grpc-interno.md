---
id: ADR-0001
title: gRPC para comunicação interna entre serviços
status: accepted
date: 2026-08-10
---

# ADR-0001 — gRPC para comunicação interna entre serviços

## Contexto

Os serviços tarifacao, cobranca e cadastro-operador trocam dados de forma síncrona.

## Decisão

Comunicação síncrona interna por gRPC com contratos `.proto` versionados em `contracts/proto`; parceiros externos só por REST ou fila dedicada.

## Consequências

Nenhuma decisão de store de dados é tomada aqui.
