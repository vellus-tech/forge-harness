# Módulo tarifacao

Cálculo do valor debitado em cada Validação, conforme Perfil Tarifário do Passageiro e Integração Temporal, a partir do Decreto 18.442/2026 (Tarifa Base R$ 4,85 a partir de 2026-11-01).

## Lista canônica de Perfis Tarifários

Comum, Estudante (meia tarifa, limite de 60 Validações/mês civil), Idoso (65+, Gratuidade), PcD (Gratuidade).

## Personas

Passageiro, Validador, Operadora, SEMOB.

## Restrições críticas

- Money como inteiro em centavos (nunca `float`/`double`), arredondamento NBR 5891 ToEven.
- Registro de auditoria append-only, retido por 5 anos, consultável pela Operadora e pela SEMOB.
- Número do Cartão Transporte nunca aparece completo em logs.
- Latência do cálculo: até 150 ms (p95) sob 3.000 Validações/minuto.

## Fora do escopo do MVP

Tarifa diferenciada por linha ou por distância; bilhete único mensal.

## Status dos artefatos

| Artefato | Status | Versão | Data |
|----------|--------|--------|------|
| requirements.md | Rascunho para revisão | 0.1.0 | 2026-09-26 |
| design.md | Não iniciado | — | — |
| tasks.md | Não iniciado | — | — |
