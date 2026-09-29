# Plano de Sprints — Passe Livre Digital

- **Time:** 4 desenvolvedores
- **Capacidade de referência:** ~24 pontos/sprint
- **Duração da sprint:** 2 semanas
- **Início da Sprint 1:** segunda-feira, 2026-10-05
- **Backlog total:** 58 pontos (ver `backlog.md`)

Sequenciamento respeita as dependências entre stories (coluna "Depende de" do backlog) em vez de encher cada sprint até o teto de 24 pontos — por isso a Sprint 3 fica abaixo da capacidade: as stories restantes (FV-4/FV-5/FV-7) formam uma cadeia sequencial e não há mais trabalho independente pronto para preencher o excedente sem violar dependência.

## Sprint 1 — 2026-10-05 a 2026-10-16

| Story | Pontos | Depende de | Observação |
|---|---|---|---|
| CW-1 | 5 | — | Scaffold + schema `wallet` |
| CW-2 | 5 | CW-1 | RF-001 |
| CW-3 | 8 | CW-2 | RF-002 |
| FV-1 | 5 | CW-1 | Scaffold `validation-sync`, pode iniciar assim que CW-1 fechar |

**Total: 23 pontos.**

## Sprint 2 — 2026-10-19 a 2026-10-30

| Story | Pontos | Depende de | Observação |
|---|---|---|---|
| CW-4 | 3 | CW-2 (Sprint 1) | RF-003 |
| CW-5 | 5 | CW-3 (Sprint 1) | Testes de integração de recarga |
| FV-2 | 5 | FV-1 (Sprint 1) | RF-004 (cadastro + mTLS) |
| FV-3 | 5 | FV-2 | RF-004 (ingestão de lote) |
| FV-6 | 3 | FV-3 | RF-006 — só pode fechar depois de FV-3 fechar na mesma sprint; se FV-3 atrasar, FV-6 desliza para a Sprint 3 |

**Total: 21 pontos.**

## Sprint 3 — 2026-11-02 a 2026-11-13

| Story | Pontos | Depende de | Observação |
|---|---|---|---|
| FV-4 | 8 | FV-3 (Sprint 2), CW-3 (Sprint 1) | RF-005 — cálculo de tarifa |
| FV-5 | 3 | FV-4 | RF-005 — confirmação de cobrança |
| FV-7 | 3 | FV-3 (Sprint 2) | Painel de latência (mitigação da ressalva do relatório de validação) |

**Total: 14 pontos.**

## Resumo

| Sprint | Datas | Pontos planejados |
|---|---|---|
| Sprint 1 | 2026-10-05 – 2026-10-16 | 23 |
| Sprint 2 | 2026-10-19 – 2026-10-30 | 21 |
| Sprint 3 | 2026-11-02 – 2026-11-13 | 14 |
| **Total** | | **58** |

## Riscos de sequenciamento

- Se FV-3 não fechar até o penúltimo dia da Sprint 2, FV-6 e o início de FV-4 escorregam — replanejar no dia de review.
- A ressalva do relatório de validação de módulos (SLO de latência offline ausente no NFRD de `fare-validation`) não bloqueia o início da implementação, mas deve ser resolvida no NFRD antes do fechamento do Épico 2, idealmente durante a Sprint 2.
