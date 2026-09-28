# TRF — Tarifação

Design Técnico

- Versão: 1.0.0
- Data: 2026-09-20
- Status: Rascunho para revisão
- Base: `docs/product/modules/tarifacao/requirements.md` v1.0.0
- ADRs aplicáveis: ADR-0001, ADR-0002, ADR-0003
- Rules aplicáveis: `.forge/rules/architecture`, `.forge/rules/data`

## Histórico de Versões

| Versão | Data | Autor | Mudança |
|--------|------|-------|---------|
| 1.0.0 | 2026-09-20 | design-writer | Versão inicial com tabela completa de tarifas |

## Visão Geral

A Tarifação calcula o valor de cada embarque a partir da linha, da faixa horária e da integração temporal.

## Estrutura da Solução

- `TRF.Domain`, `TRF.Application`, `TRF.Infrastructure`, `TRF.Api`, `TRF.Contracts`, `TRF.Architecture.Tests`

## Modelo de Domínio

```csharp
namespace TRF.Domain;

using Npgsql;

public class TabelaTarifa
{
    public Guid LinhaId { get; set; }
    public float ValorTarifa { get; set; }
    public NpgsqlConnection Conexao { get; set; }
}
```

## Apêndice A — Tabela de tarifas e contratos por linha

As seções a seguir detalham, linha a linha, a tarifa vigente, as faixas horárias e o endpoint de consulta de cada linha do consórcio.

### A.1 — Linha 001 (Terminal Leste ↔ Bairro 001)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/001?faixa={faixa}` → 200 `{ linha: "001", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.2 — Linha 002 (Terminal Leste ↔ Bairro 002)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/002?faixa={faixa}` → 200 `{ linha: "002", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.3 — Linha 003 (Terminal Leste ↔ Bairro 003)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/003?faixa={faixa}` → 200 `{ linha: "003", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.4 — Linha 004 (Terminal Leste ↔ Bairro 004)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/004?faixa={faixa}` → 200 `{ linha: "004", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.5 — Linha 005 (Terminal Leste ↔ Bairro 005)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/005?faixa={faixa}` → 200 `{ linha: "005", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.6 — Linha 006 (Terminal Leste ↔ Bairro 006)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/006?faixa={faixa}` → 200 `{ linha: "006", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.7 — Linha 007 (Terminal Leste ↔ Bairro 007)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/007?faixa={faixa}` → 200 `{ linha: "007", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.8 — Linha 008 (Terminal Leste ↔ Bairro 008)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/008?faixa={faixa}` → 200 `{ linha: "008", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.9 — Linha 009 (Terminal Leste ↔ Bairro 009)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/009?faixa={faixa}` → 200 `{ linha: "009", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.10 — Linha 010 (Terminal Leste ↔ Bairro 010)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/010?faixa={faixa}` → 200 `{ linha: "010", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.11 — Linha 011 (Terminal Leste ↔ Bairro 011)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/011?faixa={faixa}` → 200 `{ linha: "011", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.12 — Linha 012 (Terminal Leste ↔ Bairro 012)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/012?faixa={faixa}` → 200 `{ linha: "012", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.13 — Linha 013 (Terminal Leste ↔ Bairro 013)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/013?faixa={faixa}` → 200 `{ linha: "013", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.14 — Linha 014 (Terminal Leste ↔ Bairro 014)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/014?faixa={faixa}` → 200 `{ linha: "014", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.15 — Linha 015 (Terminal Leste ↔ Bairro 015)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/015?faixa={faixa}` → 200 `{ linha: "015", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.16 — Linha 016 (Terminal Leste ↔ Bairro 016)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/016?faixa={faixa}` → 200 `{ linha: "016", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.17 — Linha 017 (Terminal Leste ↔ Bairro 017)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/017?faixa={faixa}` → 200 `{ linha: "017", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.18 — Linha 018 (Terminal Leste ↔ Bairro 018)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/018?faixa={faixa}` → 200 `{ linha: "018", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.19 — Linha 019 (Terminal Leste ↔ Bairro 019)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/019?faixa={faixa}` → 200 `{ linha: "019", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.20 — Linha 020 (Terminal Leste ↔ Bairro 020)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/020?faixa={faixa}` → 200 `{ linha: "020", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.21 — Linha 021 (Terminal Leste ↔ Bairro 021)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/021?faixa={faixa}` → 200 `{ linha: "021", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.22 — Linha 022 (Terminal Leste ↔ Bairro 022)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/022?faixa={faixa}` → 200 `{ linha: "022", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.23 — Linha 023 (Terminal Leste ↔ Bairro 023)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/023?faixa={faixa}` → 200 `{ linha: "023", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.24 — Linha 024 (Terminal Leste ↔ Bairro 024)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/024?faixa={faixa}` → 200 `{ linha: "024", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.25 — Linha 025 (Terminal Leste ↔ Bairro 025)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/025?faixa={faixa}` → 200 `{ linha: "025", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.26 — Linha 026 (Terminal Leste ↔ Bairro 026)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/026?faixa={faixa}` → 200 `{ linha: "026", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.27 — Linha 027 (Terminal Leste ↔ Bairro 027)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/027?faixa={faixa}` → 200 `{ linha: "027", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.28 — Linha 028 (Terminal Leste ↔ Bairro 028)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/028?faixa={faixa}` → 200 `{ linha: "028", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.29 — Linha 029 (Terminal Leste ↔ Bairro 029)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/029?faixa={faixa}` → 200 `{ linha: "029", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.30 — Linha 030 (Terminal Leste ↔ Bairro 030)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/030?faixa={faixa}` → 200 `{ linha: "030", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.31 — Linha 031 (Terminal Leste ↔ Bairro 031)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/031?faixa={faixa}` → 200 `{ linha: "031", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.32 — Linha 032 (Terminal Leste ↔ Bairro 032)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/032?faixa={faixa}` → 200 `{ linha: "032", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.33 — Linha 033 (Terminal Leste ↔ Bairro 033)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/033?faixa={faixa}` → 200 `{ linha: "033", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.34 — Linha 034 (Terminal Leste ↔ Bairro 034)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/034?faixa={faixa}` → 200 `{ linha: "034", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.35 — Linha 035 (Terminal Leste ↔ Bairro 035)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/035?faixa={faixa}` → 200 `{ linha: "035", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.36 — Linha 036 (Terminal Leste ↔ Bairro 036)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/036?faixa={faixa}` → 200 `{ linha: "036", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.37 — Linha 037 (Terminal Leste ↔ Bairro 037)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/037?faixa={faixa}` → 200 `{ linha: "037", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.38 — Linha 038 (Terminal Leste ↔ Bairro 038)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/038?faixa={faixa}` → 200 `{ linha: "038", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.39 — Linha 039 (Terminal Leste ↔ Bairro 039)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/039?faixa={faixa}` → 200 `{ linha: "039", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.40 — Linha 040 (Terminal Leste ↔ Bairro 040)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/040?faixa={faixa}` → 200 `{ linha: "040", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.41 — Linha 041 (Terminal Leste ↔ Bairro 041)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/041?faixa={faixa}` → 200 `{ linha: "041", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.42 — Linha 042 (Terminal Leste ↔ Bairro 042)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/042?faixa={faixa}` → 200 `{ linha: "042", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.43 — Linha 043 (Terminal Leste ↔ Bairro 043)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/043?faixa={faixa}` → 200 `{ linha: "043", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.44 — Linha 044 (Terminal Leste ↔ Bairro 044)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/044?faixa={faixa}` → 200 `{ linha: "044", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.45 — Linha 045 (Terminal Leste ↔ Bairro 045)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/045?faixa={faixa}` → 200 `{ linha: "045", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.46 — Linha 046 (Terminal Leste ↔ Bairro 046)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/046?faixa={faixa}` → 200 `{ linha: "046", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.47 — Linha 047 (Terminal Leste ↔ Bairro 047)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/047?faixa={faixa}` → 200 `{ linha: "047", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.48 — Linha 048 (Terminal Leste ↔ Bairro 048)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/048?faixa={faixa}` → 200 `{ linha: "048", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.49 — Linha 049 (Terminal Leste ↔ Bairro 049)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/049?faixa={faixa}` → 200 `{ linha: "049", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.50 — Linha 050 (Terminal Leste ↔ Bairro 050)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/050?faixa={faixa}` → 200 `{ linha: "050", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.51 — Linha 051 (Terminal Leste ↔ Bairro 051)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/051?faixa={faixa}` → 200 `{ linha: "051", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.52 — Linha 052 (Terminal Leste ↔ Bairro 052)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/052?faixa={faixa}` → 200 `{ linha: "052", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.53 — Linha 053 (Terminal Leste ↔ Bairro 053)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/053?faixa={faixa}` → 200 `{ linha: "053", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.54 — Linha 054 (Terminal Leste ↔ Bairro 054)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/054?faixa={faixa}` → 200 `{ linha: "054", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.55 — Linha 055 (Terminal Leste ↔ Bairro 055)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/055?faixa={faixa}` → 200 `{ linha: "055", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.56 — Linha 056 (Terminal Leste ↔ Bairro 056)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/056?faixa={faixa}` → 200 `{ linha: "056", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.57 — Linha 057 (Terminal Leste ↔ Bairro 057)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/057?faixa={faixa}` → 200 `{ linha: "057", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.58 — Linha 058 (Terminal Leste ↔ Bairro 058)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/058?faixa={faixa}` → 200 `{ linha: "058", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.59 — Linha 059 (Terminal Leste ↔ Bairro 059)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/059?faixa={faixa}` → 200 `{ linha: "059", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.60 — Linha 060 (Terminal Leste ↔ Bairro 060)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/060?faixa={faixa}` → 200 `{ linha: "060", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.61 — Linha 061 (Terminal Leste ↔ Bairro 061)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/061?faixa={faixa}` → 200 `{ linha: "061", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.62 — Linha 062 (Terminal Leste ↔ Bairro 062)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/062?faixa={faixa}` → 200 `{ linha: "062", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.63 — Linha 063 (Terminal Leste ↔ Bairro 063)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/063?faixa={faixa}` → 200 `{ linha: "063", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.64 — Linha 064 (Terminal Leste ↔ Bairro 064)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/064?faixa={faixa}` → 200 `{ linha: "064", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.65 — Linha 065 (Terminal Leste ↔ Bairro 065)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/065?faixa={faixa}` → 200 `{ linha: "065", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.66 — Linha 066 (Terminal Leste ↔ Bairro 066)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/066?faixa={faixa}` → 200 `{ linha: "066", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.67 — Linha 067 (Terminal Leste ↔ Bairro 067)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/067?faixa={faixa}` → 200 `{ linha: "067", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.68 — Linha 068 (Terminal Leste ↔ Bairro 068)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/068?faixa={faixa}` → 200 `{ linha: "068", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.69 — Linha 069 (Terminal Leste ↔ Bairro 069)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/069?faixa={faixa}` → 200 `{ linha: "069", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.70 — Linha 070 (Terminal Leste ↔ Bairro 070)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/070?faixa={faixa}` → 200 `{ linha: "070", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.71 — Linha 071 (Terminal Leste ↔ Bairro 071)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/071?faixa={faixa}` → 200 `{ linha: "071", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.72 — Linha 072 (Terminal Leste ↔ Bairro 072)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/072?faixa={faixa}` → 200 `{ linha: "072", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.73 — Linha 073 (Terminal Leste ↔ Bairro 073)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/073?faixa={faixa}` → 200 `{ linha: "073", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.74 — Linha 074 (Terminal Leste ↔ Bairro 074)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/074?faixa={faixa}` → 200 `{ linha: "074", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.75 — Linha 075 (Terminal Leste ↔ Bairro 075)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/075?faixa={faixa}` → 200 `{ linha: "075", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.76 — Linha 076 (Terminal Leste ↔ Bairro 076)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/076?faixa={faixa}` → 200 `{ linha: "076", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.77 — Linha 077 (Terminal Leste ↔ Bairro 077)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/077?faixa={faixa}` → 200 `{ linha: "077", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.78 — Linha 078 (Terminal Leste ↔ Bairro 078)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/078?faixa={faixa}` → 200 `{ linha: "078", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.79 — Linha 079 (Terminal Leste ↔ Bairro 079)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/079?faixa={faixa}` → 200 `{ linha: "079", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.80 — Linha 080 (Terminal Leste ↔ Bairro 080)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/080?faixa={faixa}` → 200 `{ linha: "080", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.81 — Linha 081 (Terminal Leste ↔ Bairro 081)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/081?faixa={faixa}` → 200 `{ linha: "081", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.82 — Linha 082 (Terminal Leste ↔ Bairro 082)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/082?faixa={faixa}` → 200 `{ linha: "082", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.83 — Linha 083 (Terminal Leste ↔ Bairro 083)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/083?faixa={faixa}` → 200 `{ linha: "083", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.84 — Linha 084 (Terminal Leste ↔ Bairro 084)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/084?faixa={faixa}` → 200 `{ linha: "084", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.85 — Linha 085 (Terminal Leste ↔ Bairro 085)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/085?faixa={faixa}` → 200 `{ linha: "085", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.86 — Linha 086 (Terminal Leste ↔ Bairro 086)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/086?faixa={faixa}` → 200 `{ linha: "086", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.87 — Linha 087 (Terminal Leste ↔ Bairro 087)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/087?faixa={faixa}` → 200 `{ linha: "087", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.88 — Linha 088 (Terminal Leste ↔ Bairro 088)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/088?faixa={faixa}` → 200 `{ linha: "088", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.89 — Linha 089 (Terminal Leste ↔ Bairro 089)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/089?faixa={faixa}` → 200 `{ linha: "089", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.90 — Linha 090 (Terminal Leste ↔ Bairro 090)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/090?faixa={faixa}` → 200 `{ linha: "090", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.91 — Linha 091 (Terminal Leste ↔ Bairro 091)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/091?faixa={faixa}` → 200 `{ linha: "091", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.92 — Linha 092 (Terminal Leste ↔ Bairro 092)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/092?faixa={faixa}` → 200 `{ linha: "092", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.93 — Linha 093 (Terminal Leste ↔ Bairro 093)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/093?faixa={faixa}` → 200 `{ linha: "093", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.94 — Linha 094 (Terminal Leste ↔ Bairro 094)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/094?faixa={faixa}` → 200 `{ linha: "094", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.95 — Linha 095 (Terminal Leste ↔ Bairro 095)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/095?faixa={faixa}` → 200 `{ linha: "095", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.96 — Linha 096 (Terminal Leste ↔ Bairro 096)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/096?faixa={faixa}` → 200 `{ linha: "096", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.97 — Linha 097 (Terminal Leste ↔ Bairro 097)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/097?faixa={faixa}` → 200 `{ linha: "097", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.98 — Linha 098 (Terminal Leste ↔ Bairro 098)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/098?faixa={faixa}` → 200 `{ linha: "098", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.99 — Linha 099 (Terminal Leste ↔ Bairro 099)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/099?faixa={faixa}` → 200 `{ linha: "099", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.100 — Linha 100 (Terminal Leste ↔ Bairro 100)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/100?faixa={faixa}` → 200 `{ linha: "100", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.101 — Linha 101 (Terminal Leste ↔ Bairro 101)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/101?faixa={faixa}` → 200 `{ linha: "101", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.102 — Linha 102 (Terminal Leste ↔ Bairro 102)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/102?faixa={faixa}` → 200 `{ linha: "102", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.103 — Linha 103 (Terminal Leste ↔ Bairro 103)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/103?faixa={faixa}` → 200 `{ linha: "103", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.104 — Linha 104 (Terminal Leste ↔ Bairro 104)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/104?faixa={faixa}` → 200 `{ linha: "104", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.105 — Linha 105 (Terminal Leste ↔ Bairro 105)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/105?faixa={faixa}` → 200 `{ linha: "105", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.106 — Linha 106 (Terminal Leste ↔ Bairro 106)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/106?faixa={faixa}` → 200 `{ linha: "106", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.107 — Linha 107 (Terminal Leste ↔ Bairro 107)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/107?faixa={faixa}` → 200 `{ linha: "107", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.108 — Linha 108 (Terminal Leste ↔ Bairro 108)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/108?faixa={faixa}` → 200 `{ linha: "108", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.109 — Linha 109 (Terminal Leste ↔ Bairro 109)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/109?faixa={faixa}` → 200 `{ linha: "109", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.110 — Linha 110 (Terminal Leste ↔ Bairro 110)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/110?faixa={faixa}` → 200 `{ linha: "110", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.111 — Linha 111 (Terminal Leste ↔ Bairro 111)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/111?faixa={faixa}` → 200 `{ linha: "111", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.112 — Linha 112 (Terminal Leste ↔ Bairro 112)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/112?faixa={faixa}` → 200 `{ linha: "112", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.113 — Linha 113 (Terminal Leste ↔ Bairro 113)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/113?faixa={faixa}` → 200 `{ linha: "113", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.114 — Linha 114 (Terminal Leste ↔ Bairro 114)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/114?faixa={faixa}` → 200 `{ linha: "114", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.115 — Linha 115 (Terminal Leste ↔ Bairro 115)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/115?faixa={faixa}` → 200 `{ linha: "115", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.116 — Linha 116 (Terminal Leste ↔ Bairro 116)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/116?faixa={faixa}` → 200 `{ linha: "116", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.117 — Linha 117 (Terminal Leste ↔ Bairro 117)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/117?faixa={faixa}` → 200 `{ linha: "117", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.118 — Linha 118 (Terminal Leste ↔ Bairro 118)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/118?faixa={faixa}` → 200 `{ linha: "118", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.119 — Linha 119 (Terminal Leste ↔ Bairro 119)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/119?faixa={faixa}` → 200 `{ linha: "119", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.120 — Linha 120 (Terminal Leste ↔ Bairro 120)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/120?faixa={faixa}` → 200 `{ linha: "120", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.121 — Linha 121 (Terminal Leste ↔ Bairro 121)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/121?faixa={faixa}` → 200 `{ linha: "121", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.122 — Linha 122 (Terminal Leste ↔ Bairro 122)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/122?faixa={faixa}` → 200 `{ linha: "122", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.123 — Linha 123 (Terminal Leste ↔ Bairro 123)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/123?faixa={faixa}` → 200 `{ linha: "123", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.124 — Linha 124 (Terminal Leste ↔ Bairro 124)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/124?faixa={faixa}` → 200 `{ linha: "124", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.125 — Linha 125 (Terminal Leste ↔ Bairro 125)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/125?faixa={faixa}` → 200 `{ linha: "125", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.126 — Linha 126 (Terminal Leste ↔ Bairro 126)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/126?faixa={faixa}` → 200 `{ linha: "126", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.127 — Linha 127 (Terminal Leste ↔ Bairro 127)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/127?faixa={faixa}` → 200 `{ linha: "127", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.128 — Linha 128 (Terminal Leste ↔ Bairro 128)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/128?faixa={faixa}` → 200 `{ linha: "128", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.129 — Linha 129 (Terminal Leste ↔ Bairro 129)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/129?faixa={faixa}` → 200 `{ linha: "129", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.130 — Linha 130 (Terminal Leste ↔ Bairro 130)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/130?faixa={faixa}` → 200 `{ linha: "130", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.131 — Linha 131 (Terminal Leste ↔ Bairro 131)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/131?faixa={faixa}` → 200 `{ linha: "131", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.132 — Linha 132 (Terminal Leste ↔ Bairro 132)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/132?faixa={faixa}` → 200 `{ linha: "132", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.133 — Linha 133 (Terminal Leste ↔ Bairro 133)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/133?faixa={faixa}` → 200 `{ linha: "133", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.134 — Linha 134 (Terminal Leste ↔ Bairro 134)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/134?faixa={faixa}` → 200 `{ linha: "134", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.135 — Linha 135 (Terminal Leste ↔ Bairro 135)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/135?faixa={faixa}` → 200 `{ linha: "135", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.136 — Linha 136 (Terminal Leste ↔ Bairro 136)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/136?faixa={faixa}` → 200 `{ linha: "136", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.137 — Linha 137 (Terminal Leste ↔ Bairro 137)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/137?faixa={faixa}` → 200 `{ linha: "137", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.138 — Linha 138 (Terminal Leste ↔ Bairro 138)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/138?faixa={faixa}` → 200 `{ linha: "138", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.139 — Linha 139 (Terminal Leste ↔ Bairro 139)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/139?faixa={faixa}` → 200 `{ linha: "139", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.140 — Linha 140 (Terminal Leste ↔ Bairro 140)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/140?faixa={faixa}` → 200 `{ linha: "140", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.141 — Linha 141 (Terminal Leste ↔ Bairro 141)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/141?faixa={faixa}` → 200 `{ linha: "141", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.142 — Linha 142 (Terminal Leste ↔ Bairro 142)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/142?faixa={faixa}` → 200 `{ linha: "142", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.143 — Linha 143 (Terminal Leste ↔ Bairro 143)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/143?faixa={faixa}` → 200 `{ linha: "143", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.144 — Linha 144 (Terminal Leste ↔ Bairro 144)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/144?faixa={faixa}` → 200 `{ linha: "144", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.145 — Linha 145 (Terminal Leste ↔ Bairro 145)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/145?faixa={faixa}` → 200 `{ linha: "145", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.146 — Linha 146 (Terminal Leste ↔ Bairro 146)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/146?faixa={faixa}` → 200 `{ linha: "146", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.147 — Linha 147 (Terminal Leste ↔ Bairro 147)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/147?faixa={faixa}` → 200 `{ linha: "147", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.148 — Linha 148 (Terminal Leste ↔ Bairro 148)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/148?faixa={faixa}` → 200 `{ linha: "148", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.149 — Linha 149 (Terminal Leste ↔ Bairro 149)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/149?faixa={faixa}` → 200 `{ linha: "149", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.150 — Linha 150 (Terminal Leste ↔ Bairro 150)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/150?faixa={faixa}` → 200 `{ linha: "150", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.151 — Linha 151 (Terminal Leste ↔ Bairro 151)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/151?faixa={faixa}` → 200 `{ linha: "151", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.152 — Linha 152 (Terminal Leste ↔ Bairro 152)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/152?faixa={faixa}` → 200 `{ linha: "152", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.153 — Linha 153 (Terminal Leste ↔ Bairro 153)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/153?faixa={faixa}` → 200 `{ linha: "153", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.154 — Linha 154 (Terminal Leste ↔ Bairro 154)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/154?faixa={faixa}` → 200 `{ linha: "154", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.155 — Linha 155 (Terminal Leste ↔ Bairro 155)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/155?faixa={faixa}` → 200 `{ linha: "155", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.156 — Linha 156 (Terminal Leste ↔ Bairro 156)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/156?faixa={faixa}` → 200 `{ linha: "156", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.157 — Linha 157 (Terminal Leste ↔ Bairro 157)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/157?faixa={faixa}` → 200 `{ linha: "157", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.158 — Linha 158 (Terminal Leste ↔ Bairro 158)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/158?faixa={faixa}` → 200 `{ linha: "158", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.159 — Linha 159 (Terminal Leste ↔ Bairro 159)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/159?faixa={faixa}` → 200 `{ linha: "159", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.160 — Linha 160 (Terminal Leste ↔ Bairro 160)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/160?faixa={faixa}` → 200 `{ linha: "160", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.161 — Linha 161 (Terminal Leste ↔ Bairro 161)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/161?faixa={faixa}` → 200 `{ linha: "161", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.162 — Linha 162 (Terminal Leste ↔ Bairro 162)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/162?faixa={faixa}` → 200 `{ linha: "162", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.163 — Linha 163 (Terminal Leste ↔ Bairro 163)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/163?faixa={faixa}` → 200 `{ linha: "163", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.164 — Linha 164 (Terminal Leste ↔ Bairro 164)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/164?faixa={faixa}` → 200 `{ linha: "164", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.165 — Linha 165 (Terminal Leste ↔ Bairro 165)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/165?faixa={faixa}` → 200 `{ linha: "165", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.166 — Linha 166 (Terminal Leste ↔ Bairro 166)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/166?faixa={faixa}` → 200 `{ linha: "166", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.167 — Linha 167 (Terminal Leste ↔ Bairro 167)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/167?faixa={faixa}` → 200 `{ linha: "167", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.168 — Linha 168 (Terminal Leste ↔ Bairro 168)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/168?faixa={faixa}` → 200 `{ linha: "168", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.169 — Linha 169 (Terminal Leste ↔ Bairro 169)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/169?faixa={faixa}` → 200 `{ linha: "169", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.170 — Linha 170 (Terminal Leste ↔ Bairro 170)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/170?faixa={faixa}` → 200 `{ linha: "170", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.171 — Linha 171 (Terminal Leste ↔ Bairro 171)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/171?faixa={faixa}` → 200 `{ linha: "171", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.172 — Linha 172 (Terminal Leste ↔ Bairro 172)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/172?faixa={faixa}` → 200 `{ linha: "172", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.173 — Linha 173 (Terminal Leste ↔ Bairro 173)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/173?faixa={faixa}` → 200 `{ linha: "173", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.174 — Linha 174 (Terminal Leste ↔ Bairro 174)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/174?faixa={faixa}` → 200 `{ linha: "174", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.175 — Linha 175 (Terminal Leste ↔ Bairro 175)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/175?faixa={faixa}` → 200 `{ linha: "175", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.176 — Linha 176 (Terminal Leste ↔ Bairro 176)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/176?faixa={faixa}` → 200 `{ linha: "176", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.177 — Linha 177 (Terminal Leste ↔ Bairro 177)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/177?faixa={faixa}` → 200 `{ linha: "177", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.178 — Linha 178 (Terminal Leste ↔ Bairro 178)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/178?faixa={faixa}` → 200 `{ linha: "178", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.179 — Linha 179 (Terminal Leste ↔ Bairro 179)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/179?faixa={faixa}` → 200 `{ linha: "179", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.180 — Linha 180 (Terminal Leste ↔ Bairro 180)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/180?faixa={faixa}` → 200 `{ linha: "180", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.181 — Linha 181 (Terminal Leste ↔ Bairro 181)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/181?faixa={faixa}` → 200 `{ linha: "181", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.182 — Linha 182 (Terminal Leste ↔ Bairro 182)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/182?faixa={faixa}` → 200 `{ linha: "182", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.183 — Linha 183 (Terminal Leste ↔ Bairro 183)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/183?faixa={faixa}` → 200 `{ linha: "183", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.184 — Linha 184 (Terminal Leste ↔ Bairro 184)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/184?faixa={faixa}` → 200 `{ linha: "184", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.185 — Linha 185 (Terminal Leste ↔ Bairro 185)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/185?faixa={faixa}` → 200 `{ linha: "185", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.186 — Linha 186 (Terminal Leste ↔ Bairro 186)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/186?faixa={faixa}` → 200 `{ linha: "186", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.187 — Linha 187 (Terminal Leste ↔ Bairro 187)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/187?faixa={faixa}` → 200 `{ linha: "187", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.188 — Linha 188 (Terminal Leste ↔ Bairro 188)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/188?faixa={faixa}` → 200 `{ linha: "188", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.189 — Linha 189 (Terminal Leste ↔ Bairro 189)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/189?faixa={faixa}` → 200 `{ linha: "189", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.190 — Linha 190 (Terminal Leste ↔ Bairro 190)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/190?faixa={faixa}` → 200 `{ linha: "190", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.191 — Linha 191 (Terminal Leste ↔ Bairro 191)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/191?faixa={faixa}` → 200 `{ linha: "191", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.192 — Linha 192 (Terminal Leste ↔ Bairro 192)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/192?faixa={faixa}` → 200 `{ linha: "192", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.193 — Linha 193 (Terminal Leste ↔ Bairro 193)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/193?faixa={faixa}` → 200 `{ linha: "193", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.194 — Linha 194 (Terminal Leste ↔ Bairro 194)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/194?faixa={faixa}` → 200 `{ linha: "194", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.195 — Linha 195 (Terminal Leste ↔ Bairro 195)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/195?faixa={faixa}` → 200 `{ linha: "195", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.196 — Linha 196 (Terminal Leste ↔ Bairro 196)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/196?faixa={faixa}` → 200 `{ linha: "196", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.197 — Linha 197 (Terminal Leste ↔ Bairro 197)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/197?faixa={faixa}` → 200 `{ linha: "197", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.198 — Linha 198 (Terminal Leste ↔ Bairro 198)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/198?faixa={faixa}` → 200 `{ linha: "198", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.199 — Linha 199 (Terminal Leste ↔ Bairro 199)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/199?faixa={faixa}` → 200 `{ linha: "199", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.200 — Linha 200 (Terminal Leste ↔ Bairro 200)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/200?faixa={faixa}` → 200 `{ linha: "200", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.201 — Linha 201 (Terminal Leste ↔ Bairro 201)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/201?faixa={faixa}` → 200 `{ linha: "201", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.202 — Linha 202 (Terminal Leste ↔ Bairro 202)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/202?faixa={faixa}` → 200 `{ linha: "202", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.203 — Linha 203 (Terminal Leste ↔ Bairro 203)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/203?faixa={faixa}` → 200 `{ linha: "203", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.204 — Linha 204 (Terminal Leste ↔ Bairro 204)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/204?faixa={faixa}` → 200 `{ linha: "204", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.205 — Linha 205 (Terminal Leste ↔ Bairro 205)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/205?faixa={faixa}` → 200 `{ linha: "205", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.206 — Linha 206 (Terminal Leste ↔ Bairro 206)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/206?faixa={faixa}` → 200 `{ linha: "206", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.207 — Linha 207 (Terminal Leste ↔ Bairro 207)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/207?faixa={faixa}` → 200 `{ linha: "207", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.208 — Linha 208 (Terminal Leste ↔ Bairro 208)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/208?faixa={faixa}` → 200 `{ linha: "208", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.209 — Linha 209 (Terminal Leste ↔ Bairro 209)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/209?faixa={faixa}` → 200 `{ linha: "209", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.210 — Linha 210 (Terminal Leste ↔ Bairro 210)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/210?faixa={faixa}` → 200 `{ linha: "210", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.211 — Linha 211 (Terminal Leste ↔ Bairro 211)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/211?faixa={faixa}` → 200 `{ linha: "211", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.212 — Linha 212 (Terminal Leste ↔ Bairro 212)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/212?faixa={faixa}` → 200 `{ linha: "212", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.213 — Linha 213 (Terminal Leste ↔ Bairro 213)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/213?faixa={faixa}` → 200 `{ linha: "213", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.214 — Linha 214 (Terminal Leste ↔ Bairro 214)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/214?faixa={faixa}` → 200 `{ linha: "214", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.215 — Linha 215 (Terminal Leste ↔ Bairro 215)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/215?faixa={faixa}` → 200 `{ linha: "215", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.216 — Linha 216 (Terminal Leste ↔ Bairro 216)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/216?faixa={faixa}` → 200 `{ linha: "216", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.217 — Linha 217 (Terminal Leste ↔ Bairro 217)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/217?faixa={faixa}` → 200 `{ linha: "217", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.218 — Linha 218 (Terminal Leste ↔ Bairro 218)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/218?faixa={faixa}` → 200 `{ linha: "218", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.219 — Linha 219 (Terminal Leste ↔ Bairro 219)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/219?faixa={faixa}` → 200 `{ linha: "219", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.220 — Linha 220 (Terminal Leste ↔ Bairro 220)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/220?faixa={faixa}` → 200 `{ linha: "220", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.221 — Linha 221 (Terminal Leste ↔ Bairro 221)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/221?faixa={faixa}` → 200 `{ linha: "221", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.222 — Linha 222 (Terminal Leste ↔ Bairro 222)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/222?faixa={faixa}` → 200 `{ linha: "222", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.223 — Linha 223 (Terminal Leste ↔ Bairro 223)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/223?faixa={faixa}` → 200 `{ linha: "223", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.224 — Linha 224 (Terminal Leste ↔ Bairro 224)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/224?faixa={faixa}` → 200 `{ linha: "224", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.225 — Linha 225 (Terminal Leste ↔ Bairro 225)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/225?faixa={faixa}` → 200 `{ linha: "225", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.226 — Linha 226 (Terminal Leste ↔ Bairro 226)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/226?faixa={faixa}` → 200 `{ linha: "226", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.227 — Linha 227 (Terminal Leste ↔ Bairro 227)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/227?faixa={faixa}` → 200 `{ linha: "227", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.228 — Linha 228 (Terminal Leste ↔ Bairro 228)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/228?faixa={faixa}` → 200 `{ linha: "228", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.229 — Linha 229 (Terminal Leste ↔ Bairro 229)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/229?faixa={faixa}` → 200 `{ linha: "229", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.230 — Linha 230 (Terminal Leste ↔ Bairro 230)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/230?faixa={faixa}` → 200 `{ linha: "230", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.231 — Linha 231 (Terminal Leste ↔ Bairro 231)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/231?faixa={faixa}` → 200 `{ linha: "231", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.232 — Linha 232 (Terminal Leste ↔ Bairro 232)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/232?faixa={faixa}` → 200 `{ linha: "232", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.233 — Linha 233 (Terminal Leste ↔ Bairro 233)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/233?faixa={faixa}` → 200 `{ linha: "233", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.234 — Linha 234 (Terminal Leste ↔ Bairro 234)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/234?faixa={faixa}` → 200 `{ linha: "234", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.235 — Linha 235 (Terminal Leste ↔ Bairro 235)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/235?faixa={faixa}` → 200 `{ linha: "235", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.236 — Linha 236 (Terminal Leste ↔ Bairro 236)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/236?faixa={faixa}` → 200 `{ linha: "236", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.237 — Linha 237 (Terminal Leste ↔ Bairro 237)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/237?faixa={faixa}` → 200 `{ linha: "237", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.238 — Linha 238 (Terminal Leste ↔ Bairro 238)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/238?faixa={faixa}` → 200 `{ linha: "238", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.239 — Linha 239 (Terminal Leste ↔ Bairro 239)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/239?faixa={faixa}` → 200 `{ linha: "239", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.240 — Linha 240 (Terminal Leste ↔ Bairro 240)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/240?faixa={faixa}` → 200 `{ linha: "240", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.241 — Linha 241 (Terminal Leste ↔ Bairro 241)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/241?faixa={faixa}` → 200 `{ linha: "241", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.242 — Linha 242 (Terminal Leste ↔ Bairro 242)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/242?faixa={faixa}` → 200 `{ linha: "242", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.243 — Linha 243 (Terminal Leste ↔ Bairro 243)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/243?faixa={faixa}` → 200 `{ linha: "243", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.244 — Linha 244 (Terminal Leste ↔ Bairro 244)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/244?faixa={faixa}` → 200 `{ linha: "244", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.245 — Linha 245 (Terminal Leste ↔ Bairro 245)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/245?faixa={faixa}` → 200 `{ linha: "245", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.246 — Linha 246 (Terminal Leste ↔ Bairro 246)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/246?faixa={faixa}` → 200 `{ linha: "246", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.247 — Linha 247 (Terminal Leste ↔ Bairro 247)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/247?faixa={faixa}` → 200 `{ linha: "247", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.248 — Linha 248 (Terminal Leste ↔ Bairro 248)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/248?faixa={faixa}` → 200 `{ linha: "248", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.249 — Linha 249 (Terminal Leste ↔ Bairro 249)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/249?faixa={faixa}` → 200 `{ linha: "249", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.250 — Linha 250 (Terminal Leste ↔ Bairro 250)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/250?faixa={faixa}` → 200 `{ linha: "250", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.251 — Linha 251 (Terminal Leste ↔ Bairro 251)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/251?faixa={faixa}` → 200 `{ linha: "251", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.252 — Linha 252 (Terminal Leste ↔ Bairro 252)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/252?faixa={faixa}` → 200 `{ linha: "252", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.253 — Linha 253 (Terminal Leste ↔ Bairro 253)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/253?faixa={faixa}` → 200 `{ linha: "253", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.254 — Linha 254 (Terminal Leste ↔ Bairro 254)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/254?faixa={faixa}` → 200 `{ linha: "254", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.255 — Linha 255 (Terminal Leste ↔ Bairro 255)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/255?faixa={faixa}` → 200 `{ linha: "255", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.256 — Linha 256 (Terminal Leste ↔ Bairro 256)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/256?faixa={faixa}` → 200 `{ linha: "256", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.257 — Linha 257 (Terminal Leste ↔ Bairro 257)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/257?faixa={faixa}` → 200 `{ linha: "257", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.258 — Linha 258 (Terminal Leste ↔ Bairro 258)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/258?faixa={faixa}` → 200 `{ linha: "258", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.259 — Linha 259 (Terminal Leste ↔ Bairro 259)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/259?faixa={faixa}` → 200 `{ linha: "259", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.260 — Linha 260 (Terminal Leste ↔ Bairro 260)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/260?faixa={faixa}` → 200 `{ linha: "260", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.261 — Linha 261 (Terminal Leste ↔ Bairro 261)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/261?faixa={faixa}` → 200 `{ linha: "261", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.262 — Linha 262 (Terminal Leste ↔ Bairro 262)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/262?faixa={faixa}` → 200 `{ linha: "262", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.263 — Linha 263 (Terminal Leste ↔ Bairro 263)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/263?faixa={faixa}` → 200 `{ linha: "263", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.264 — Linha 264 (Terminal Leste ↔ Bairro 264)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/264?faixa={faixa}` → 200 `{ linha: "264", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.265 — Linha 265 (Terminal Leste ↔ Bairro 265)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/265?faixa={faixa}` → 200 `{ linha: "265", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.266 — Linha 266 (Terminal Leste ↔ Bairro 266)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/266?faixa={faixa}` → 200 `{ linha: "266", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.267 — Linha 267 (Terminal Leste ↔ Bairro 267)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/267?faixa={faixa}` → 200 `{ linha: "267", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.268 — Linha 268 (Terminal Leste ↔ Bairro 268)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/268?faixa={faixa}` → 200 `{ linha: "268", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.269 — Linha 269 (Terminal Leste ↔ Bairro 269)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/269?faixa={faixa}` → 200 `{ linha: "269", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.270 — Linha 270 (Terminal Leste ↔ Bairro 270)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/270?faixa={faixa}` → 200 `{ linha: "270", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.271 — Linha 271 (Terminal Leste ↔ Bairro 271)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/271?faixa={faixa}` → 200 `{ linha: "271", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.272 — Linha 272 (Terminal Leste ↔ Bairro 272)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/272?faixa={faixa}` → 200 `{ linha: "272", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.273 — Linha 273 (Terminal Leste ↔ Bairro 273)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/273?faixa={faixa}` → 200 `{ linha: "273", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.274 — Linha 274 (Terminal Leste ↔ Bairro 274)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/274?faixa={faixa}` → 200 `{ linha: "274", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.275 — Linha 275 (Terminal Leste ↔ Bairro 275)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/275?faixa={faixa}` → 200 `{ linha: "275", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.276 — Linha 276 (Terminal Leste ↔ Bairro 276)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/276?faixa={faixa}` → 200 `{ linha: "276", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.277 — Linha 277 (Terminal Leste ↔ Bairro 277)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/277?faixa={faixa}` → 200 `{ linha: "277", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.278 — Linha 278 (Terminal Leste ↔ Bairro 278)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/278?faixa={faixa}` → 200 `{ linha: "278", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.279 — Linha 279 (Terminal Leste ↔ Bairro 279)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/279?faixa={faixa}` → 200 `{ linha: "279", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.280 — Linha 280 (Terminal Leste ↔ Bairro 280)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/280?faixa={faixa}` → 200 `{ linha: "280", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.281 — Linha 281 (Terminal Leste ↔ Bairro 281)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/281?faixa={faixa}` → 200 `{ linha: "281", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.282 — Linha 282 (Terminal Leste ↔ Bairro 282)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/282?faixa={faixa}` → 200 `{ linha: "282", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.283 — Linha 283 (Terminal Leste ↔ Bairro 283)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/283?faixa={faixa}` → 200 `{ linha: "283", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.284 — Linha 284 (Terminal Leste ↔ Bairro 284)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/284?faixa={faixa}` → 200 `{ linha: "284", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.285 — Linha 285 (Terminal Leste ↔ Bairro 285)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/285?faixa={faixa}` → 200 `{ linha: "285", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.286 — Linha 286 (Terminal Leste ↔ Bairro 286)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/286?faixa={faixa}` → 200 `{ linha: "286", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.287 — Linha 287 (Terminal Leste ↔ Bairro 287)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/287?faixa={faixa}` → 200 `{ linha: "287", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.288 — Linha 288 (Terminal Leste ↔ Bairro 288)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/288?faixa={faixa}` → 200 `{ linha: "288", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.289 — Linha 289 (Terminal Leste ↔ Bairro 289)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/289?faixa={faixa}` → 200 `{ linha: "289", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.290 — Linha 290 (Terminal Leste ↔ Bairro 290)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/290?faixa={faixa}` → 200 `{ linha: "290", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.291 — Linha 291 (Terminal Leste ↔ Bairro 291)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/291?faixa={faixa}` → 200 `{ linha: "291", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.292 — Linha 292 (Terminal Leste ↔ Bairro 292)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/292?faixa={faixa}` → 200 `{ linha: "292", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.293 — Linha 293 (Terminal Leste ↔ Bairro 293)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/293?faixa={faixa}` → 200 `{ linha: "293", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.294 — Linha 294 (Terminal Leste ↔ Bairro 294)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/294?faixa={faixa}` → 200 `{ linha: "294", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.295 — Linha 295 (Terminal Leste ↔ Bairro 295)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/295?faixa={faixa}` → 200 `{ linha: "295", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.296 — Linha 296 (Terminal Leste ↔ Bairro 296)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/296?faixa={faixa}` → 200 `{ linha: "296", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.297 — Linha 297 (Terminal Leste ↔ Bairro 297)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/297?faixa={faixa}` → 200 `{ linha: "297", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.298 — Linha 298 (Terminal Leste ↔ Bairro 298)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/298?faixa={faixa}` → 200 `{ linha: "298", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.299 — Linha 299 (Terminal Leste ↔ Bairro 299)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/299?faixa={faixa}` → 200 `{ linha: "299", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.300 — Linha 300 (Terminal Leste ↔ Bairro 300)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/300?faixa={faixa}` → 200 `{ linha: "300", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.301 — Linha 301 (Terminal Leste ↔ Bairro 301)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/301?faixa={faixa}` → 200 `{ linha: "301", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.302 — Linha 302 (Terminal Leste ↔ Bairro 302)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/302?faixa={faixa}` → 200 `{ linha: "302", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.303 — Linha 303 (Terminal Leste ↔ Bairro 303)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/303?faixa={faixa}` → 200 `{ linha: "303", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.304 — Linha 304 (Terminal Leste ↔ Bairro 304)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/304?faixa={faixa}` → 200 `{ linha: "304", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.305 — Linha 305 (Terminal Leste ↔ Bairro 305)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/305?faixa={faixa}` → 200 `{ linha: "305", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.306 — Linha 306 (Terminal Leste ↔ Bairro 306)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/306?faixa={faixa}` → 200 `{ linha: "306", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.307 — Linha 307 (Terminal Leste ↔ Bairro 307)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/307?faixa={faixa}` → 200 `{ linha: "307", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.308 — Linha 308 (Terminal Leste ↔ Bairro 308)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/308?faixa={faixa}` → 200 `{ linha: "308", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.309 — Linha 309 (Terminal Leste ↔ Bairro 309)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/309?faixa={faixa}` → 200 `{ linha: "309", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.310 — Linha 310 (Terminal Leste ↔ Bairro 310)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/310?faixa={faixa}` → 200 `{ linha: "310", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.311 — Linha 311 (Terminal Leste ↔ Bairro 311)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/311?faixa={faixa}` → 200 `{ linha: "311", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.312 — Linha 312 (Terminal Leste ↔ Bairro 312)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/312?faixa={faixa}` → 200 `{ linha: "312", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.313 — Linha 313 (Terminal Leste ↔ Bairro 313)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/313?faixa={faixa}` → 200 `{ linha: "313", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.314 — Linha 314 (Terminal Leste ↔ Bairro 314)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/314?faixa={faixa}` → 200 `{ linha: "314", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.315 — Linha 315 (Terminal Leste ↔ Bairro 315)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/315?faixa={faixa}` → 200 `{ linha: "315", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.316 — Linha 316 (Terminal Leste ↔ Bairro 316)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/316?faixa={faixa}` → 200 `{ linha: "316", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.317 — Linha 317 (Terminal Leste ↔ Bairro 317)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/317?faixa={faixa}` → 200 `{ linha: "317", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.318 — Linha 318 (Terminal Leste ↔ Bairro 318)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/318?faixa={faixa}` → 200 `{ linha: "318", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.319 — Linha 319 (Terminal Leste ↔ Bairro 319)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/319?faixa={faixa}` → 200 `{ linha: "319", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.320 — Linha 320 (Terminal Leste ↔ Bairro 320)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/320?faixa={faixa}` → 200 `{ linha: "320", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.321 — Linha 321 (Terminal Leste ↔ Bairro 321)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/321?faixa={faixa}` → 200 `{ linha: "321", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.322 — Linha 322 (Terminal Leste ↔ Bairro 322)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/322?faixa={faixa}` → 200 `{ linha: "322", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.323 — Linha 323 (Terminal Leste ↔ Bairro 323)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/323?faixa={faixa}` → 200 `{ linha: "323", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.324 — Linha 324 (Terminal Leste ↔ Bairro 324)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/324?faixa={faixa}` → 200 `{ linha: "324", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.325 — Linha 325 (Terminal Leste ↔ Bairro 325)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/325?faixa={faixa}` → 200 `{ linha: "325", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.326 — Linha 326 (Terminal Leste ↔ Bairro 326)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/326?faixa={faixa}` → 200 `{ linha: "326", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.327 — Linha 327 (Terminal Leste ↔ Bairro 327)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/327?faixa={faixa}` → 200 `{ linha: "327", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.328 — Linha 328 (Terminal Leste ↔ Bairro 328)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/328?faixa={faixa}` → 200 `{ linha: "328", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.329 — Linha 329 (Terminal Leste ↔ Bairro 329)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/329?faixa={faixa}` → 200 `{ linha: "329", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.330 — Linha 330 (Terminal Leste ↔ Bairro 330)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/330?faixa={faixa}` → 200 `{ linha: "330", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.331 — Linha 331 (Terminal Leste ↔ Bairro 331)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/331?faixa={faixa}` → 200 `{ linha: "331", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.332 — Linha 332 (Terminal Leste ↔ Bairro 332)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/332?faixa={faixa}` → 200 `{ linha: "332", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.333 — Linha 333 (Terminal Leste ↔ Bairro 333)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/333?faixa={faixa}` → 200 `{ linha: "333", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.334 — Linha 334 (Terminal Leste ↔ Bairro 334)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/334?faixa={faixa}` → 200 `{ linha: "334", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.335 — Linha 335 (Terminal Leste ↔ Bairro 335)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/335?faixa={faixa}` → 200 `{ linha: "335", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.336 — Linha 336 (Terminal Leste ↔ Bairro 336)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/336?faixa={faixa}` → 200 `{ linha: "336", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.337 — Linha 337 (Terminal Leste ↔ Bairro 337)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/337?faixa={faixa}` → 200 `{ linha: "337", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.338 — Linha 338 (Terminal Leste ↔ Bairro 338)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/338?faixa={faixa}` → 200 `{ linha: "338", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.339 — Linha 339 (Terminal Leste ↔ Bairro 339)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/339?faixa={faixa}` → 200 `{ linha: "339", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.340 — Linha 340 (Terminal Leste ↔ Bairro 340)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/340?faixa={faixa}` → 200 `{ linha: "340", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.341 — Linha 341 (Terminal Leste ↔ Bairro 341)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/341?faixa={faixa}` → 200 `{ linha: "341", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.342 — Linha 342 (Terminal Leste ↔ Bairro 342)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/342?faixa={faixa}` → 200 `{ linha: "342", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.343 — Linha 343 (Terminal Leste ↔ Bairro 343)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/343?faixa={faixa}` → 200 `{ linha: "343", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.344 — Linha 344 (Terminal Leste ↔ Bairro 344)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/344?faixa={faixa}` → 200 `{ linha: "344", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.345 — Linha 345 (Terminal Leste ↔ Bairro 345)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/345?faixa={faixa}` → 200 `{ linha: "345", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.346 — Linha 346 (Terminal Leste ↔ Bairro 346)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/346?faixa={faixa}` → 200 `{ linha: "346", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.347 — Linha 347 (Terminal Leste ↔ Bairro 347)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/347?faixa={faixa}` → 200 `{ linha: "347", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.348 — Linha 348 (Terminal Leste ↔ Bairro 348)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/348?faixa={faixa}` → 200 `{ linha: "348", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.349 — Linha 349 (Terminal Leste ↔ Bairro 349)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/349?faixa={faixa}` → 200 `{ linha: "349", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.350 — Linha 350 (Terminal Leste ↔ Bairro 350)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/350?faixa={faixa}` → 200 `{ linha: "350", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.351 — Linha 351 (Terminal Leste ↔ Bairro 351)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/351?faixa={faixa}` → 200 `{ linha: "351", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.352 — Linha 352 (Terminal Leste ↔ Bairro 352)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/352?faixa={faixa}` → 200 `{ linha: "352", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.353 — Linha 353 (Terminal Leste ↔ Bairro 353)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/353?faixa={faixa}` → 200 `{ linha: "353", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.354 — Linha 354 (Terminal Leste ↔ Bairro 354)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/354?faixa={faixa}` → 200 `{ linha: "354", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.355 — Linha 355 (Terminal Leste ↔ Bairro 355)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/355?faixa={faixa}` → 200 `{ linha: "355", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.356 — Linha 356 (Terminal Leste ↔ Bairro 356)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/356?faixa={faixa}` → 200 `{ linha: "356", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.357 — Linha 357 (Terminal Leste ↔ Bairro 357)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/357?faixa={faixa}` → 200 `{ linha: "357", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.358 — Linha 358 (Terminal Leste ↔ Bairro 358)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/358?faixa={faixa}` → 200 `{ linha: "358", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.359 — Linha 359 (Terminal Leste ↔ Bairro 359)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/359?faixa={faixa}` → 200 `{ linha: "359", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.360 — Linha 360 (Terminal Leste ↔ Bairro 360)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/360?faixa={faixa}` → 200 `{ linha: "360", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.361 — Linha 361 (Terminal Leste ↔ Bairro 361)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/361?faixa={faixa}` → 200 `{ linha: "361", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.362 — Linha 362 (Terminal Leste ↔ Bairro 362)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/362?faixa={faixa}` → 200 `{ linha: "362", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.363 — Linha 363 (Terminal Leste ↔ Bairro 363)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/363?faixa={faixa}` → 200 `{ linha: "363", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.364 — Linha 364 (Terminal Leste ↔ Bairro 364)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/364?faixa={faixa}` → 200 `{ linha: "364", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.365 — Linha 365 (Terminal Leste ↔ Bairro 365)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/365?faixa={faixa}` → 200 `{ linha: "365", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.366 — Linha 366 (Terminal Leste ↔ Bairro 366)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/366?faixa={faixa}` → 200 `{ linha: "366", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.367 — Linha 367 (Terminal Leste ↔ Bairro 367)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/367?faixa={faixa}` → 200 `{ linha: "367", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.368 — Linha 368 (Terminal Leste ↔ Bairro 368)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/368?faixa={faixa}` → 200 `{ linha: "368", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.369 — Linha 369 (Terminal Leste ↔ Bairro 369)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/369?faixa={faixa}` → 200 `{ linha: "369", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.370 — Linha 370 (Terminal Leste ↔ Bairro 370)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/370?faixa={faixa}` → 200 `{ linha: "370", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.371 — Linha 371 (Terminal Leste ↔ Bairro 371)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/371?faixa={faixa}` → 200 `{ linha: "371", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.372 — Linha 372 (Terminal Leste ↔ Bairro 372)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/372?faixa={faixa}` → 200 `{ linha: "372", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.373 — Linha 373 (Terminal Leste ↔ Bairro 373)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/373?faixa={faixa}` → 200 `{ linha: "373", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.374 — Linha 374 (Terminal Leste ↔ Bairro 374)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/374?faixa={faixa}` → 200 `{ linha: "374", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.375 — Linha 375 (Terminal Leste ↔ Bairro 375)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/375?faixa={faixa}` → 200 `{ linha: "375", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.376 — Linha 376 (Terminal Leste ↔ Bairro 376)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/376?faixa={faixa}` → 200 `{ linha: "376", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.377 — Linha 377 (Terminal Leste ↔ Bairro 377)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/377?faixa={faixa}` → 200 `{ linha: "377", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.378 — Linha 378 (Terminal Leste ↔ Bairro 378)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/378?faixa={faixa}` → 200 `{ linha: "378", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.379 — Linha 379 (Terminal Leste ↔ Bairro 379)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/379?faixa={faixa}` → 200 `{ linha: "379", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.380 — Linha 380 (Terminal Leste ↔ Bairro 380)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/380?faixa={faixa}` → 200 `{ linha: "380", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.381 — Linha 381 (Terminal Leste ↔ Bairro 381)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/381?faixa={faixa}` → 200 `{ linha: "381", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.382 — Linha 382 (Terminal Leste ↔ Bairro 382)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/382?faixa={faixa}` → 200 `{ linha: "382", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.383 — Linha 383 (Terminal Leste ↔ Bairro 383)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/383?faixa={faixa}` → 200 `{ linha: "383", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.384 — Linha 384 (Terminal Leste ↔ Bairro 384)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/384?faixa={faixa}` → 200 `{ linha: "384", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.385 — Linha 385 (Terminal Leste ↔ Bairro 385)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/385?faixa={faixa}` → 200 `{ linha: "385", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.386 — Linha 386 (Terminal Leste ↔ Bairro 386)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/386?faixa={faixa}` → 200 `{ linha: "386", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.387 — Linha 387 (Terminal Leste ↔ Bairro 387)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/387?faixa={faixa}` → 200 `{ linha: "387", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.388 — Linha 388 (Terminal Leste ↔ Bairro 388)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/388?faixa={faixa}` → 200 `{ linha: "388", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.389 — Linha 389 (Terminal Leste ↔ Bairro 389)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/389?faixa={faixa}` → 200 `{ linha: "389", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.390 — Linha 390 (Terminal Leste ↔ Bairro 390)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/390?faixa={faixa}` → 200 `{ linha: "390", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.391 — Linha 391 (Terminal Leste ↔ Bairro 391)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/391?faixa={faixa}` → 200 `{ linha: "391", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.392 — Linha 392 (Terminal Leste ↔ Bairro 392)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/392?faixa={faixa}` → 200 `{ linha: "392", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.393 — Linha 393 (Terminal Leste ↔ Bairro 393)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/393?faixa={faixa}` → 200 `{ linha: "393", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.394 — Linha 394 (Terminal Leste ↔ Bairro 394)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/394?faixa={faixa}` → 200 `{ linha: "394", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.395 — Linha 395 (Terminal Leste ↔ Bairro 395)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/395?faixa={faixa}` → 200 `{ linha: "395", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.396 — Linha 396 (Terminal Leste ↔ Bairro 396)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/396?faixa={faixa}` → 200 `{ linha: "396", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.397 — Linha 397 (Terminal Leste ↔ Bairro 397)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/397?faixa={faixa}` → 200 `{ linha: "397", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.398 — Linha 398 (Terminal Leste ↔ Bairro 398)

- Operadora (tenant): TransNorte
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/398?faixa={faixa}` → 200 `{ linha: "398", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.399 — Linha 399 (Terminal Leste ↔ Bairro 399)

- Operadora (tenant): Expresso Sul
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/399?faixa={faixa}` → 200 `{ linha: "399", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos

### A.400 — Linha 400 (Terminal Leste ↔ Bairro 400)

- Operadora (tenant): Viação Leste
- Tarifa base: 4.40 (float); faixa noturna (23h-5h): 4.90
- Endpoint: `GET /v1/tarifas/linhas/400?faixa={faixa}` → 200 `{ linha: "400", valor: 4.4 }`
- Faixa pico (6h-9h e 17h-20h): mesma tarifa base, sem desconto
- Integração temporal: sim, janela de 90 minutos


## Schema / Modelo de Persistência

```sql
CREATE TABLE tabela_tarifa (
  linha_id UUID PRIMARY KEY,
  valor_tarifa FLOAT NOT NULL,
  vigencia_inicio DATE NOT NULL
);
```

## Testes

- Testes unitários do cálculo.

## Referências

- `docs/product/modules/tarifacao/requirements.md`
