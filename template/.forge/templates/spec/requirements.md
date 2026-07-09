# Requirements — <CHANGE_ID>

> Requisitos do change `<CHANGE_ID>`. Cada requisito é verificável e rastreável à proposal.
> Marque incertezas com `NEEDS CLARIFICATION` — o change só atinge `requirements-ready` quando não restar nenhuma (resolvidas via `/forge:clarify`).

## REQ-01 — <título curto>

- **Quando** <gatilho/condição>, **o sistema deve** <comportamento observável>.
- **Critérios de aceite:**
  - [ ] <condição verificável 1>
  - [ ] <condição verificável 2>
- **Rastreia:** proposal §2
- **Notas:** <restrições, dados, limites>

## Requisitos não funcionais do change (quando houver)

- **NFR-01 —** <meta mensurável com unidade> (método de medição; fonte de dados)

## Checklist de cobertura de superfície

> Preencha para **todo** parâmetro/configuração/flag exposto por este change (tela, endpoint,
> CLI, variável de ambiente, campo de config). O objetivo é detectar em `/forge:analyze` — antes
> do marco, não depois — parâmetros implementados sem superfície de acesso mapeada (ou
> vice-versa). Uma auditoria pós-marco já encontrou lacunas desse tipo tarde demais.

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-01 | <nome do parâmetro> | <ex.: `PATCH /settings`, tela Configurações, `--flag`> | TASK-NN |

- Nenhuma linha "N/A" sem justificativa — se o requisito não expõe parâmetro configurável, diga
  explicitamente "sem parâmetro exposto" em vez de omitir a linha.
- Todo parâmetro sem superfície mapeada é `NEEDS CLARIFICATION` até ser resolvido.

## Fora de escopo (reafirmação)

- <item herdado da proposal §3>
