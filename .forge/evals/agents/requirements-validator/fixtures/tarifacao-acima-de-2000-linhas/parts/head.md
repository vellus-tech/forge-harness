# TRF — Tarifação

**Requisitos Funcionais e Não-Funcionais**

| Campo | Valor |
|-------|-------|
| **Versão** | 0.4.0 |
| **Data** | 2026-09-21 |
| **Status** | Rascunho para revisão |
| **Referência pai** | PRD Rota Única v2.1.0 (`docs/product/prd/prd.md`) |

## Histórico de Versões

| Versão | Data | Autor | Descrição |
|--------|------|-------|-----------|
| 0.1.0 | 2026-08-25 | requirements-writer | Rascunho inicial |
| 0.4.0 | 2026-09-21 | requirements-writer | Catálogo de tarifas por linha incorporado |

## Visão Geral

O módulo Tarifação define a tarifa cobrada por embarque em cada linha das três operadoras do consórcio e as regras de integração temporal de 90 minutos (OBJ-02 do PRD).

## Escopo

- Tarifa por linha e faixa horária.
- Integração temporal entre linhas do consórcio.
- Catálogo de tarifas de todas as linhas.

## Personas / Atores

| Persona | Descrição |
|---------|-----------|
| Passageiro | Paga a tarifa no embarque |
| Gestor de tarifas da operadora | Cadastra e reajusta tarifas das linhas da própria operadora |
| Validador | Equipamento que consulta a tarifa no embarque |

## Requisitos Funcionais

