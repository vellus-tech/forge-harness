# TRF — Tarifação

Requirements

- Versão: 1.0.0
- Data: 2026-09-05
- Status: Aprovado para desenvolvimento

## Requisitos Funcionais

### REQ-01 — Calcular tarifa do embarque
Dado linha, faixa horária e perfil do passageiro, o sistema retorna o valor da tarifa em centavos.

### REQ-02 — Aplicar integração temporal
Um segundo embarque em linha diferente dentro de 90 minutos do primeiro tem tarifa zero; o terceiro é cobrado integralmente.

### REQ-03 — Manter tabela de tarifas por linha
O gestor da operadora cadastra e versiona a tabela de tarifas das suas linhas, com vigência futura.

## Requisitos Não Funcionais

- RNF-01: Cálculo de tarifa com p95 menor que 20 ms (cache em memória).
- RNF-02: Tabela de tarifas segregada por operadora (`tenant_id`).

## Propriedades (PBT)

- PBT-01: A tarifa calculada nunca é negativa.
- PBT-02: Dentro da janela de 90 minutos, no máximo um embarque integrado é gratuito.
