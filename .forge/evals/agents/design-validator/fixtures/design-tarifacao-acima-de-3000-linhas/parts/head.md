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

