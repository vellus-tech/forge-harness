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

### Req 1 — Tarifa da linha 001 (Terminal Leste ↔ Bairro 001)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 001 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 1.1 A tarifa base da linha 001 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 1.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 001 não é cobrado.

### Req 2 — Tarifa da linha 002 (Terminal Leste ↔ Bairro 002)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 002 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 2.1 A tarifa base da linha 002 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 2.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 002 não é cobrado.

### Req 3 — Tarifa da linha 003 (Terminal Leste ↔ Bairro 003)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 003 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 3.1 A tarifa base da linha 003 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 3.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 003 não é cobrado.

### Req 4 — Tarifa da linha 004 (Terminal Leste ↔ Bairro 004)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 004 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 4.1 A tarifa base da linha 004 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 4.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 004 não é cobrado.

### Req 5 — Tarifa da linha 005 (Terminal Leste ↔ Bairro 005)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 005 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 5.1 A tarifa base da linha 005 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 5.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 005 não é cobrado.

### Req 6 — Tarifa da linha 006 (Terminal Leste ↔ Bairro 006)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 006 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 6.1 A tarifa base da linha 006 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 6.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 006 não é cobrado.

### Req 7 — Tarifa da linha 007 (Terminal Leste ↔ Bairro 007)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 007 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 7.1 A tarifa base da linha 007 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 7.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 007 não é cobrado.

### Req 8 — Tarifa da linha 008 (Terminal Leste ↔ Bairro 008)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 008 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 8.1 A tarifa base da linha 008 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 8.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 008 não é cobrado.

### Req 9 — Tarifa da linha 009 (Terminal Leste ↔ Bairro 009)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 009 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 9.1 A tarifa base da linha 009 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 9.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 009 não é cobrado.

### Req 10 — Tarifa da linha 010 (Terminal Leste ↔ Bairro 010)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 010 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 10.1 A tarifa base da linha 010 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 10.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 010 não é cobrado.

### Req 11 — Tarifa da linha 011 (Terminal Leste ↔ Bairro 011)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 011 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 11.1 A tarifa base da linha 011 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 11.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 011 não é cobrado.

### Req 12 — Tarifa da linha 012 (Terminal Leste ↔ Bairro 012)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 012 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 12.1 A tarifa base da linha 012 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 12.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 012 não é cobrado.

### Req 13 — Tarifa da linha 013 (Terminal Leste ↔ Bairro 013)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 013 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 13.1 A tarifa base da linha 013 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 13.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 013 não é cobrado.

### Req 14 — Tarifa da linha 014 (Terminal Leste ↔ Bairro 014)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 014 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 14.1 A tarifa base da linha 014 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 14.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 014 não é cobrado.

### Req 15 — Tarifa da linha 015 (Terminal Leste ↔ Bairro 015)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 015 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 15.1 A tarifa base da linha 015 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 15.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 015 não é cobrado.

### Req 16 — Tarifa da linha 016 (Terminal Leste ↔ Bairro 016)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 016 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 16.1 A tarifa base da linha 016 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 16.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 016 não é cobrado.

### Req 17 — Tarifa da linha 017 (Terminal Leste ↔ Bairro 017)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 017 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 17.1 A tarifa base da linha 017 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 17.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 017 não é cobrado.

### Req 18 — Tarifa da linha 018 (Terminal Leste ↔ Bairro 018)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 018 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 18.1 A tarifa base da linha 018 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 18.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 018 não é cobrado.

### Req 19 — Tarifa da linha 019 (Terminal Leste ↔ Bairro 019)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 019 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 19.1 A tarifa base da linha 019 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 19.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 019 não é cobrado.

### Req 20 — Tarifa da linha 020 (Terminal Leste ↔ Bairro 020)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 020 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 20.1 A tarifa base da linha 020 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 20.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 020 não é cobrado.

### Req 21 — Tarifa da linha 021 (Terminal Leste ↔ Bairro 021)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 021 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 21.1 A tarifa base da linha 021 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 21.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 021 não é cobrado.

### Req 22 — Tarifa da linha 022 (Terminal Leste ↔ Bairro 022)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 022 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 22.1 A tarifa base da linha 022 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 22.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 022 não é cobrado.

### Req 23 — Tarifa da linha 023 (Terminal Leste ↔ Bairro 023)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 023 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 23.1 A tarifa base da linha 023 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 23.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 023 não é cobrado.

### Req 24 — Tarifa da linha 024 (Terminal Leste ↔ Bairro 024)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 024 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 24.1 A tarifa base da linha 024 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 24.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 024 não é cobrado.

### Req 25 — Tarifa da linha 025 (Terminal Leste ↔ Bairro 025)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 025 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 25.1 A tarifa base da linha 025 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 25.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 025 não é cobrado.

### Req 26 — Tarifa da linha 026 (Terminal Leste ↔ Bairro 026)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 026 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 26.1 A tarifa base da linha 026 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 26.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 026 não é cobrado.

### Req 27 — Tarifa da linha 027 (Terminal Leste ↔ Bairro 027)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 027 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 27.1 A tarifa base da linha 027 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 27.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 027 não é cobrado.

### Req 28 — Tarifa da linha 028 (Terminal Leste ↔ Bairro 028)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 028 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 28.1 A tarifa base da linha 028 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 28.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 028 não é cobrado.

### Req 29 — Tarifa da linha 029 (Terminal Leste ↔ Bairro 029)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 029 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 29.1 A tarifa base da linha 029 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 29.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 029 não é cobrado.

### Req 30 — Tarifa da linha 030 (Terminal Leste ↔ Bairro 030)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 030 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 30.1 A tarifa base da linha 030 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 30.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 030 não é cobrado.

### Req 31 — Tarifa da linha 031 (Terminal Leste ↔ Bairro 031)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 031 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 31.1 A tarifa base da linha 031 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 31.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 031 não é cobrado.

### Req 32 — Tarifa da linha 032 (Terminal Leste ↔ Bairro 032)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 032 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 32.1 A tarifa base da linha 032 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 32.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 032 não é cobrado.

### Req 33 — Tarifa da linha 033 (Terminal Leste ↔ Bairro 033)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 033 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 33.1 A tarifa base da linha 033 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 33.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 033 não é cobrado.

### Req 34 — Tarifa da linha 034 (Terminal Leste ↔ Bairro 034)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 034 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 34.1 A tarifa base da linha 034 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 34.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 034 não é cobrado.

### Req 35 — Tarifa da linha 035 (Terminal Leste ↔ Bairro 035)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 035 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 35.1 A tarifa base da linha 035 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 35.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 035 não é cobrado.

### Req 36 — Tarifa da linha 036 (Terminal Leste ↔ Bairro 036)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 036 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 36.1 A tarifa base da linha 036 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 36.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 036 não é cobrado.

### Req 37 — Tarifa da linha 037 (Terminal Leste ↔ Bairro 037)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 037 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 37.1 A tarifa base da linha 037 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 37.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 037 não é cobrado.

### Req 38 — Tarifa da linha 038 (Terminal Leste ↔ Bairro 038)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 038 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 38.1 A tarifa base da linha 038 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 38.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 038 não é cobrado.

### Req 39 — Tarifa da linha 039 (Terminal Leste ↔ Bairro 039)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 039 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 39.1 A tarifa base da linha 039 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 39.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 039 não é cobrado.

### Req 40 — Tarifa da linha 040 (Terminal Leste ↔ Bairro 040)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 040 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 40.1 A tarifa base da linha 040 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 40.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 040 não é cobrado.

### Req 41 — Tarifa da linha 041 (Terminal Leste ↔ Bairro 041)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 041 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 41.1 A tarifa base da linha 041 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 41.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 041 não é cobrado.

### Req 42 — Tarifa da linha 042 (Terminal Leste ↔ Bairro 042)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 042 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 42.1 A tarifa base da linha 042 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 42.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 042 não é cobrado.

### Req 43 — Tarifa da linha 043 (Terminal Leste ↔ Bairro 043)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 043 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 43.1 A tarifa base da linha 043 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 43.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 043 não é cobrado.

### Req 44 — Tarifa da linha 044 (Terminal Leste ↔ Bairro 044)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 044 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 44.1 A tarifa base da linha 044 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 44.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 044 não é cobrado.

### Req 45 — Tarifa da linha 045 (Terminal Leste ↔ Bairro 045)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 045 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 45.1 A tarifa base da linha 045 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 45.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 045 não é cobrado.

### Req 46 — Tarifa da linha 046 (Terminal Leste ↔ Bairro 046)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 046 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 46.1 A tarifa base da linha 046 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 46.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 046 não é cobrado.

### Req 47 — Tarifa da linha 047 (Terminal Leste ↔ Bairro 047)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 047 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 47.1 A tarifa base da linha 047 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 47.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 047 não é cobrado.

### Req 48 — Tarifa da linha 048 (Terminal Leste ↔ Bairro 048)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 048 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 48.1 A tarifa base da linha 048 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 48.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 048 não é cobrado.

### Req 49 — Tarifa da linha 049 (Terminal Leste ↔ Bairro 049)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 049 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 49.1 A tarifa base da linha 049 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 49.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 049 não é cobrado.

### Req 50 — Tarifa da linha 050 (Terminal Leste ↔ Bairro 050)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 050 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 50.1 A tarifa base da linha 050 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 50.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 050 não é cobrado.

### Req 51 — Tarifa da linha 051 (Terminal Leste ↔ Bairro 051)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 051 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 51.1 A tarifa base da linha 051 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 51.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 051 não é cobrado.

### Req 52 — Tarifa da linha 052 (Terminal Leste ↔ Bairro 052)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 052 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 52.1 A tarifa base da linha 052 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 52.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 052 não é cobrado.

### Req 53 — Tarifa da linha 053 (Terminal Leste ↔ Bairro 053)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 053 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 53.1 A tarifa base da linha 053 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 53.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 053 não é cobrado.

### Req 54 — Tarifa da linha 054 (Terminal Leste ↔ Bairro 054)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 054 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 54.1 A tarifa base da linha 054 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 54.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 054 não é cobrado.

### Req 55 — Tarifa da linha 055 (Terminal Leste ↔ Bairro 055)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 055 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 55.1 A tarifa base da linha 055 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 55.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 055 não é cobrado.

### Req 56 — Tarifa da linha 056 (Terminal Leste ↔ Bairro 056)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 056 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 56.1 A tarifa base da linha 056 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 56.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 056 não é cobrado.

### Req 57 — Tarifa da linha 057 (Terminal Leste ↔ Bairro 057)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 057 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 57.1 A tarifa base da linha 057 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 57.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 057 não é cobrado.

### Req 58 — Tarifa da linha 058 (Terminal Leste ↔ Bairro 058)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 058 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 58.1 A tarifa base da linha 058 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 58.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 058 não é cobrado.

### Req 59 — Tarifa da linha 059 (Terminal Leste ↔ Bairro 059)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 059 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 59.1 A tarifa base da linha 059 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 59.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 059 não é cobrado.

### Req 60 — Tarifa da linha 060 (Terminal Leste ↔ Bairro 060)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 060 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 60.1 A tarifa base da linha 060 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 60.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 060 não é cobrado.

### Req 61 — Tarifa da linha 061 (Terminal Leste ↔ Bairro 061)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 061 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 61.1 A tarifa base da linha 061 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 61.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 061 não é cobrado.

### Req 62 — Tarifa da linha 062 (Terminal Leste ↔ Bairro 062)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 062 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 62.1 A tarifa base da linha 062 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 62.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 062 não é cobrado.

### Req 63 — Tarifa da linha 063 (Terminal Leste ↔ Bairro 063)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 063 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 63.1 A tarifa base da linha 063 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 63.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 063 não é cobrado.

### Req 64 — Tarifa da linha 064 (Terminal Leste ↔ Bairro 064)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 064 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 64.1 A tarifa base da linha 064 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 64.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 064 não é cobrado.

### Req 65 — Tarifa da linha 065 (Terminal Leste ↔ Bairro 065)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 065 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 65.1 A tarifa base da linha 065 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 65.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 065 não é cobrado.

### Req 66 — Tarifa da linha 066 (Terminal Leste ↔ Bairro 066)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 066 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 66.1 A tarifa base da linha 066 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 66.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 066 não é cobrado.

### Req 67 — Tarifa da linha 067 (Terminal Leste ↔ Bairro 067)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 067 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 67.1 A tarifa base da linha 067 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 67.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 067 não é cobrado.

### Req 68 — Tarifa da linha 068 (Terminal Leste ↔ Bairro 068)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 068 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 68.1 A tarifa base da linha 068 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 68.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 068 não é cobrado.

### Req 69 — Tarifa da linha 069 (Terminal Leste ↔ Bairro 069)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 069 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 69.1 A tarifa base da linha 069 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 69.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 069 não é cobrado.

### Req 70 — Tarifa da linha 070 (Terminal Leste ↔ Bairro 070)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 070 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 70.1 A tarifa base da linha 070 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 70.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 070 não é cobrado.

### Req 71 — Tarifa da linha 071 (Terminal Leste ↔ Bairro 071)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 071 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 71.1 A tarifa base da linha 071 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 71.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 071 não é cobrado.

### Req 72 — Tarifa da linha 072 (Terminal Leste ↔ Bairro 072)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 072 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 72.1 A tarifa base da linha 072 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 72.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 072 não é cobrado.

### Req 73 — Tarifa da linha 073 (Terminal Leste ↔ Bairro 073)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 073 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 73.1 A tarifa base da linha 073 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 73.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 073 não é cobrado.

### Req 74 — Tarifa da linha 074 (Terminal Leste ↔ Bairro 074)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 074 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 74.1 A tarifa base da linha 074 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 74.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 074 não é cobrado.

### Req 75 — Tarifa da linha 075 (Terminal Leste ↔ Bairro 075)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 075 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 75.1 A tarifa base da linha 075 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 75.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 075 não é cobrado.

### Req 76 — Tarifa da linha 076 (Terminal Leste ↔ Bairro 076)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 076 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 76.1 A tarifa base da linha 076 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 76.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 076 não é cobrado.

### Req 77 — Tarifa da linha 077 (Terminal Leste ↔ Bairro 077)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 077 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 77.1 A tarifa base da linha 077 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 77.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 077 não é cobrado.

### Req 78 — Tarifa da linha 078 (Terminal Leste ↔ Bairro 078)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 078 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 78.1 A tarifa base da linha 078 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 78.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 078 não é cobrado.

### Req 79 — Tarifa da linha 079 (Terminal Leste ↔ Bairro 079)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 079 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 79.1 A tarifa base da linha 079 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 79.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 079 não é cobrado.

### Req 80 — Tarifa da linha 080 (Terminal Leste ↔ Bairro 080)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 080 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 80.1 A tarifa base da linha 080 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 80.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 080 não é cobrado.

### Req 81 — Tarifa da linha 081 (Terminal Leste ↔ Bairro 081)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 081 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 81.1 A tarifa base da linha 081 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 81.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 081 não é cobrado.

### Req 82 — Tarifa da linha 082 (Terminal Leste ↔ Bairro 082)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 082 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 82.1 A tarifa base da linha 082 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 82.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 082 não é cobrado.

### Req 83 — Tarifa da linha 083 (Terminal Leste ↔ Bairro 083)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 083 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 83.1 A tarifa base da linha 083 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 83.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 083 não é cobrado.

### Req 84 — Tarifa da linha 084 (Terminal Leste ↔ Bairro 084)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 084 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 84.1 A tarifa base da linha 084 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 84.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 084 não é cobrado.

### Req 85 — Tarifa da linha 085 (Terminal Leste ↔ Bairro 085)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 085 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 85.1 A tarifa base da linha 085 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 85.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 085 não é cobrado.

### Req 86 — Tarifa da linha 086 (Terminal Leste ↔ Bairro 086)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 086 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 86.1 A tarifa base da linha 086 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 86.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 086 não é cobrado.

### Req 87 — Tarifa da linha 087 (Terminal Leste ↔ Bairro 087)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 087 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 87.1 A tarifa base da linha 087 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 87.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 087 não é cobrado.

### Req 88 — Tarifa da linha 088 (Terminal Leste ↔ Bairro 088)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 088 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 88.1 A tarifa base da linha 088 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 88.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 088 não é cobrado.

### Req 89 — Tarifa da linha 089 (Terminal Leste ↔ Bairro 089)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 089 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 89.1 A tarifa base da linha 089 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 89.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 089 não é cobrado.

### Req 90 — Tarifa da linha 090 (Terminal Leste ↔ Bairro 090)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 090 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 90.1 A tarifa base da linha 090 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 90.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 090 não é cobrado.

### Req 91 — Tarifa da linha 091 (Terminal Leste ↔ Bairro 091)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 091 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 91.1 A tarifa base da linha 091 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 91.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 091 não é cobrado.

### Req 92 — Tarifa da linha 092 (Terminal Leste ↔ Bairro 092)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 092 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 92.1 A tarifa base da linha 092 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 92.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 092 não é cobrado.

### Req 93 — Tarifa da linha 093 (Terminal Leste ↔ Bairro 093)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 093 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 93.1 A tarifa base da linha 093 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 93.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 093 não é cobrado.

### Req 94 — Tarifa da linha 094 (Terminal Leste ↔ Bairro 094)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 094 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 94.1 A tarifa base da linha 094 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 94.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 094 não é cobrado.

### Req 95 — Tarifa da linha 095 (Terminal Leste ↔ Bairro 095)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 095 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 95.1 A tarifa base da linha 095 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 95.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 095 não é cobrado.

### Req 96 — Tarifa da linha 096 (Terminal Leste ↔ Bairro 096)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 096 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 96.1 A tarifa base da linha 096 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 96.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 096 não é cobrado.

### Req 97 — Tarifa da linha 097 (Terminal Leste ↔ Bairro 097)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 097 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 97.1 A tarifa base da linha 097 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 97.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 097 não é cobrado.

### Req 98 — Tarifa da linha 098 (Terminal Leste ↔ Bairro 098)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 098 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 98.1 A tarifa base da linha 098 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 98.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 098 não é cobrado.

### Req 99 — Tarifa da linha 099 (Terminal Leste ↔ Bairro 099)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 099 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 99.1 A tarifa base da linha 099 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 99.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 099 não é cobrado.

### Req 100 — Tarifa da linha 100 (Terminal Leste ↔ Bairro 100)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 100 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 100.1 A tarifa base da linha 100 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 100.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 100 não é cobrado.

### Req 101 — Tarifa da linha 101 (Terminal Leste ↔ Bairro 101)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 101 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 101.1 A tarifa base da linha 101 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 101.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 101 não é cobrado.

### Req 102 — Tarifa da linha 102 (Terminal Leste ↔ Bairro 102)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 102 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 102.1 A tarifa base da linha 102 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 102.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 102 não é cobrado.

### Req 103 — Tarifa da linha 103 (Terminal Leste ↔ Bairro 103)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 103 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 103.1 A tarifa base da linha 103 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 103.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 103 não é cobrado.

### Req 104 — Tarifa da linha 104 (Terminal Leste ↔ Bairro 104)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 104 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 104.1 A tarifa base da linha 104 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 104.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 104 não é cobrado.

### Req 105 — Tarifa da linha 105 (Terminal Leste ↔ Bairro 105)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 105 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 105.1 A tarifa base da linha 105 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 105.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 105 não é cobrado.

### Req 106 — Tarifa da linha 106 (Terminal Leste ↔ Bairro 106)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 106 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 106.1 A tarifa base da linha 106 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 106.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 106 não é cobrado.

### Req 107 — Tarifa da linha 107 (Terminal Leste ↔ Bairro 107)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 107 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 107.1 A tarifa base da linha 107 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 107.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 107 não é cobrado.

### Req 108 — Tarifa da linha 108 (Terminal Leste ↔ Bairro 108)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 108 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 108.1 A tarifa base da linha 108 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 108.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 108 não é cobrado.

### Req 109 — Tarifa da linha 109 (Terminal Leste ↔ Bairro 109)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 109 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 109.1 A tarifa base da linha 109 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 109.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 109 não é cobrado.

### Req 110 — Tarifa da linha 110 (Terminal Leste ↔ Bairro 110)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 110 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 110.1 A tarifa base da linha 110 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 110.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 110 não é cobrado.

### Req 111 — Tarifa da linha 111 (Terminal Leste ↔ Bairro 111)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 111 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 111.1 A tarifa base da linha 111 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 111.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 111 não é cobrado.

### Req 112 — Tarifa da linha 112 (Terminal Leste ↔ Bairro 112)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 112 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 112.1 A tarifa base da linha 112 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 112.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 112 não é cobrado.

### Req 113 — Tarifa da linha 113 (Terminal Leste ↔ Bairro 113)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 113 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 113.1 A tarifa base da linha 113 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 113.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 113 não é cobrado.

### Req 114 — Tarifa da linha 114 (Terminal Leste ↔ Bairro 114)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 114 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 114.1 A tarifa base da linha 114 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 114.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 114 não é cobrado.

### Req 115 — Tarifa da linha 115 (Terminal Leste ↔ Bairro 115)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 115 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 115.1 A tarifa base da linha 115 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 115.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 115 não é cobrado.

### Req 116 — Tarifa da linha 116 (Terminal Leste ↔ Bairro 116)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 116 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 116.1 A tarifa base da linha 116 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 116.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 116 não é cobrado.

### Req 117 — Tarifa da linha 117 (Terminal Leste ↔ Bairro 117)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 117 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 117.1 A tarifa base da linha 117 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 117.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 117 não é cobrado.

### Req 118 — Tarifa da linha 118 (Terminal Leste ↔ Bairro 118)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 118 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 118.1 A tarifa base da linha 118 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 118.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 118 não é cobrado.

### Req 119 — Tarifa da linha 119 (Terminal Leste ↔ Bairro 119)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 119 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 119.1 A tarifa base da linha 119 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 119.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 119 não é cobrado.

### Req 120 — Tarifa da linha 120 (Terminal Leste ↔ Bairro 120)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 120 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 120.1 A tarifa base da linha 120 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 120.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 120 não é cobrado.

### Req 121 — Tarifa da linha 121 (Terminal Leste ↔ Bairro 121)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 121 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 121.1 A tarifa base da linha 121 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 121.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 121 não é cobrado.

### Req 122 — Tarifa da linha 122 (Terminal Leste ↔ Bairro 122)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 122 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 122.1 A tarifa base da linha 122 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 122.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 122 não é cobrado.

### Req 123 — Tarifa da linha 123 (Terminal Leste ↔ Bairro 123)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 123 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 123.1 A tarifa base da linha 123 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 123.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 123 não é cobrado.

### Req 124 — Tarifa da linha 124 (Terminal Leste ↔ Bairro 124)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 124 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 124.1 A tarifa base da linha 124 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 124.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 124 não é cobrado.

### Req 125 — Tarifa da linha 125 (Terminal Leste ↔ Bairro 125)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 125 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 125.1 A tarifa base da linha 125 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 125.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 125 não é cobrado.

### Req 126 — Tarifa da linha 126 (Terminal Leste ↔ Bairro 126)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 126 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 126.1 A tarifa base da linha 126 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 126.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 126 não é cobrado.

### Req 127 — Tarifa da linha 127 (Terminal Leste ↔ Bairro 127)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 127 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 127.1 A tarifa base da linha 127 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 127.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 127 não é cobrado.

### Req 128 — Tarifa da linha 128 (Terminal Leste ↔ Bairro 128)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 128 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 128.1 A tarifa base da linha 128 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 128.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 128 não é cobrado.

### Req 129 — Tarifa da linha 129 (Terminal Leste ↔ Bairro 129)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 129 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 129.1 A tarifa base da linha 129 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 129.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 129 não é cobrado.

### Req 130 — Tarifa da linha 130 (Terminal Leste ↔ Bairro 130)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 130 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 130.1 A tarifa base da linha 130 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 130.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 130 não é cobrado.

### Req 131 — Tarifa da linha 131 (Terminal Leste ↔ Bairro 131)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 131 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 131.1 A tarifa base da linha 131 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 131.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 131 não é cobrado.

### Req 132 — Tarifa da linha 132 (Terminal Leste ↔ Bairro 132)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 132 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 132.1 A tarifa base da linha 132 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 132.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 132 não é cobrado.

### Req 133 — Tarifa da linha 133 (Terminal Leste ↔ Bairro 133)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 133 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 133.1 A tarifa base da linha 133 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 133.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 133 não é cobrado.

### Req 134 — Tarifa da linha 134 (Terminal Leste ↔ Bairro 134)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 134 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 134.1 A tarifa base da linha 134 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 134.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 134 não é cobrado.

### Req 135 — Tarifa da linha 135 (Terminal Leste ↔ Bairro 135)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 135 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 135.1 A tarifa base da linha 135 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 135.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 135 não é cobrado.

### Req 136 — Tarifa da linha 136 (Terminal Leste ↔ Bairro 136)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 136 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 136.1 A tarifa base da linha 136 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 136.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 136 não é cobrado.

### Req 137 — Tarifa da linha 137 (Terminal Leste ↔ Bairro 137)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 137 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 137.1 A tarifa base da linha 137 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 137.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 137 não é cobrado.

### Req 138 — Tarifa da linha 138 (Terminal Leste ↔ Bairro 138)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 138 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 138.1 A tarifa base da linha 138 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 138.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 138 não é cobrado.

### Req 139 — Tarifa da linha 139 (Terminal Leste ↔ Bairro 139)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 139 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 139.1 A tarifa base da linha 139 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 139.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 139 não é cobrado.

### Req 140 — Tarifa da linha 140 (Terminal Leste ↔ Bairro 140)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 140 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 140.1 A tarifa base da linha 140 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 140.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 140 não é cobrado.

### Req 141 — Tarifa da linha 141 (Terminal Leste ↔ Bairro 141)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 141 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 141.1 A tarifa base da linha 141 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 141.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 141 não é cobrado.

### Req 142 — Tarifa da linha 142 (Terminal Leste ↔ Bairro 142)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 142 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 142.1 A tarifa base da linha 142 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 142.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 142 não é cobrado.

### Req 143 — Tarifa da linha 143 (Terminal Leste ↔ Bairro 143)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 143 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 143.1 A tarifa base da linha 143 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 143.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 143 não é cobrado.

### Req 144 — Tarifa da linha 144 (Terminal Leste ↔ Bairro 144)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 144 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 144.1 A tarifa base da linha 144 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 144.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 144 não é cobrado.

### Req 145 — Tarifa da linha 145 (Terminal Leste ↔ Bairro 145)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 145 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 145.1 A tarifa base da linha 145 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 145.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 145 não é cobrado.

### Req 146 — Tarifa da linha 146 (Terminal Leste ↔ Bairro 146)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 146 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 146.1 A tarifa base da linha 146 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 146.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 146 não é cobrado.

### Req 147 — Tarifa da linha 147 (Terminal Leste ↔ Bairro 147)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 147 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 147.1 A tarifa base da linha 147 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 147.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 147 não é cobrado.

### Req 148 — Tarifa da linha 148 (Terminal Leste ↔ Bairro 148)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 148 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 148.1 A tarifa base da linha 148 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 148.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 148 não é cobrado.

### Req 149 — Tarifa da linha 149 (Terminal Leste ↔ Bairro 149)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 149 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 149.1 A tarifa base da linha 149 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 149.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 149 não é cobrado.

### Req 150 — Tarifa da linha 150 (Terminal Leste ↔ Bairro 150)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 150 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 150.1 A tarifa base da linha 150 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 150.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 150 não é cobrado.

### Req 151 — Tarifa da linha 151 (Terminal Leste ↔ Bairro 151)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 151 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 151.1 A tarifa base da linha 151 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 151.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 151 não é cobrado.

### Req 152 — Tarifa da linha 152 (Terminal Leste ↔ Bairro 152)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 152 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 152.1 A tarifa base da linha 152 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 152.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 152 não é cobrado.

### Req 153 — Tarifa da linha 153 (Terminal Leste ↔ Bairro 153)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 153 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 153.1 A tarifa base da linha 153 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 153.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 153 não é cobrado.

### Req 154 — Tarifa da linha 154 (Terminal Leste ↔ Bairro 154)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 154 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 154.1 A tarifa base da linha 154 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 154.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 154 não é cobrado.

### Req 155 — Tarifa da linha 155 (Terminal Leste ↔ Bairro 155)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 155 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 155.1 A tarifa base da linha 155 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 155.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 155 não é cobrado.

### Req 156 — Tarifa da linha 156 (Terminal Leste ↔ Bairro 156)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 156 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 156.1 A tarifa base da linha 156 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 156.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 156 não é cobrado.

### Req 157 — Tarifa da linha 157 (Terminal Leste ↔ Bairro 157)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 157 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 157.1 A tarifa base da linha 157 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 157.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 157 não é cobrado.

### Req 158 — Tarifa da linha 158 (Terminal Leste ↔ Bairro 158)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 158 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 158.1 A tarifa base da linha 158 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 158.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 158 não é cobrado.

### Req 159 — Tarifa da linha 159 (Terminal Leste ↔ Bairro 159)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 159 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 159.1 A tarifa base da linha 159 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 159.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 159 não é cobrado.

### Req 160 — Tarifa da linha 160 (Terminal Leste ↔ Bairro 160)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 160 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 160.1 A tarifa base da linha 160 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 160.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 160 não é cobrado.

### Req 161 — Tarifa da linha 161 (Terminal Leste ↔ Bairro 161)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 161 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 161.1 A tarifa base da linha 161 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 161.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 161 não é cobrado.

### Req 162 — Tarifa da linha 162 (Terminal Leste ↔ Bairro 162)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 162 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 162.1 A tarifa base da linha 162 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 162.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 162 não é cobrado.

### Req 163 — Tarifa da linha 163 (Terminal Leste ↔ Bairro 163)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 163 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 163.1 A tarifa base da linha 163 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 163.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 163 não é cobrado.

### Req 164 — Tarifa da linha 164 (Terminal Leste ↔ Bairro 164)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 164 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 164.1 A tarifa base da linha 164 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 164.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 164 não é cobrado.

### Req 165 — Tarifa da linha 165 (Terminal Leste ↔ Bairro 165)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 165 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 165.1 A tarifa base da linha 165 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 165.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 165 não é cobrado.

### Req 166 — Tarifa da linha 166 (Terminal Leste ↔ Bairro 166)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 166 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 166.1 A tarifa base da linha 166 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 166.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 166 não é cobrado.

### Req 167 — Tarifa da linha 167 (Terminal Leste ↔ Bairro 167)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 167 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 167.1 A tarifa base da linha 167 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 167.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 167 não é cobrado.

### Req 168 — Tarifa da linha 168 (Terminal Leste ↔ Bairro 168)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 168 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Expresso Sul 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 168.1 A tarifa base da linha 168 (Expresso Sul) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 168.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 168 não é cobrado.

### Req 169 — Tarifa da linha 169 (Terminal Leste ↔ Bairro 169)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 169 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária Viação Leste 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 169.1 A tarifa base da linha 169 (Viação Leste) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 169.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 169 não é cobrado.

### Req 170 — Tarifa da linha 170 (Terminal Leste ↔ Bairro 170)

**Como** Passageiro **quero** pagar a tarifa vigente da linha 170 **para** embarcar com o valor correto.

| Campo | Valor |
|-------|-------|
| **Prioridade** | Must |
| **Origem** | Tabela tarifária TransNorte 2026 |
| **Módulo** | tarifacao |

**Critérios de Aceite:**
- 170.1 A tarifa base da linha 170 (TransNorte) é 440 centavos; na faixa noturna (23h às 5h) é 490 centavos.
- 170.2 Um segundo embarque em outra linha do consórcio em até 90 minutos após o embarque na linha 170 não é cobrado.

## Requisitos Não-Funcionais

- **RNF-01 (Performance):** A consulta de tarifa pelo validador responde em até 50 ms no p99, medida no serviço.
- **RNF-02 (Auditoria):** Todo reajuste de tarifa gera registro imutável com operadora, linha, valor anterior, valor novo e ator.

## Property-Based Testing

### PBT-01 — Integração temporal nunca cobra mais que a tarifa cheia

**Mapeia para:** Req 1.2
**Tipo:** Invariante matemática
**Propriedade:**

> Para qualquer par de embarques dentro de 90 minutos, o valor cobrado no segundo embarque é menor ou igual à tarifa cheia da linha.

## Glossário local

| Termo | Definição |
|-------|-----------|
| Faixa horária | Intervalo do dia com tarifa própria (pico, noturna) |

## Fora do escopo do MVP

- Gratuidade estudantil (fase 2).
- Bilhete magnético.

## Referências cruzadas

- PRD Rota Única v2.1.0
- ADR-0002 — Valores monetários em centavos inteiros
