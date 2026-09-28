# Módulo tarifacao

## Identificação

- Nome: tarifacao
- Bounded context: tarifacao
- Tipo de subdomínio: Core

## Responsabilidade

Publica e versiona a tabela tarifária aprovada pelo poder concedente e expõe a tarifa vigente como Open Host Service.

## Ownership de dados

- tabelas_tarifarias (dono)

## Dependências

- Saída: nenhuma.
- Entrada: recarga (OHS/PL `TarifaVigente`).

```mermaid
graph LR
  recarga -->|OHS/PL gRPC TarifaVigente| tarifacao
```

## Integrações

- Expõe gRPC `TarifaVigente.Obter` (contrato `contracts/proto/tarifacao/v1/tarifa.proto`).

## Deployable

- tarifacao-service (TRD §Deployables) — Kotlin/Spring Boot + PostgreSQL.

## Compliance

- Fora de escopo PCI DSS: não toca dado de cartão. Fora de escopo LGPD: não trata PII.

## Arquitetura interna

```mermaid
graph TD
  api[gRPC TarifaVigente] --> app[Casos de uso] --> dom[Domínio Tabela] --> repo[(tabelas_tarifarias)]
```

## Integração

```mermaid
sequenceDiagram
  recarga->>tarifacao: TarifaVigente.Obter(linha)
  tarifacao-->>recarga: tarifa, versão
```

---
Cross-refs: BC `ddd/bounded-contexts/tarifacao`, deployable tarifacao-service (TRD), RF-05, ADR-0001.
