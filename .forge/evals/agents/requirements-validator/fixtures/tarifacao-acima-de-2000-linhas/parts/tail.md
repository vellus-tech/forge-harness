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
