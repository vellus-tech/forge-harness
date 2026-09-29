# Varredura de antipatterns analíticos — evidência

Skill aplicada: `data-analytical-practices`. Protocolo seguido na ordem fixa (Escopo → Rules → Detecção → Julgamento → Relatório).

## 1. Escopo

O pedido de auditoria delimitou o diretório `analytics/`. Esse diretório contém apenas notebooks exploratórios (`analytics/notebooks/sazonalidade.py`, `analytics/notebooks/demanda_por_linha.ipynb`) e não tem nenhum arquivo `.sql` ou `.yml` — o universo que o `scan.sh` da skill examina. O próprio `analytics/README.md` declara: "Os modelos dbt de produção ficam em `warehouse/`". Ou seja, o código analítico de produção (modelos dbt, fontes, marts) não está em `analytics/`, está em `warehouse/`.

Por isso a varredura foi executada nos dois diretórios: `analytics/` (escopo literal do pedido) e `warehouse/` (onde o próprio projeto documenta que o código analítico de produção reside, e que é o alvo real da skill — modelagem dimensional, dbt, contratos de mart).

Fatos declarados em `warehouse/`: `fct_viagens` (grão: uma linha por viagem, `id_viagem`), definido em `warehouse/models/marts/fct_viagens.sql`.

## 2. Rules do projeto

Lidas `.forge/rules/data/*` (data-governance, schema-evolution, data-cache, data-config-sql, data-transactional-nosql) e `.forge/rules/domain/money-as-cents.md`. `fct_viagens.sql` expõe `valor_tarifa_centavos` — nome e grandeza compatíveis com a rule de money-as-cents (inteiro em centavos); nenhuma divergência (`CONFLITO`) encontrada contra rules, ADRs ou baseline.

`check-data-governance.sh --path analytics` e `--path warehouse`: ambos retornam `FAIL data-governance/universo-vazio` (0 arquivos examinados pelo gate de governança nesse glob) — não é aprovação, é não verificado; sem achado de PII pessoal (`grep -a` por `cpf|email|nome|data_nasc` em `analytics/` e `warehouse/` não achou ocorrência).

## 3. Detecção — `scan.sh`

### `--root analytics/` (escopo literal do pedido)

```
INFO data-analytical-practices motor=rg raizes=1 universo=sql yml
NADA-EXAMINADO — nenhum arquivo do universo da skill (sql yml) sob as raízes; isto não é aprovação
ARQUIVOS-VARRIDOS 0
```

Exit 3. Não há SQL/yml em `analytics/` — o scanner não encontrou antipattern porque não examinou nada, não porque o código esteja limpo. Uma certificação de "sem antipattern" baseada só nesse resultado seria falsa: universo vazio não é aprovação.

### `--root warehouse/` (onde o dbt de produção realmente está, por indicação do próprio README)

```
INFO data-analytical-practices motor=rg raizes=1 universo=sql yml
OK A-06 [aviso] nenhuma ocorrência
OK A-08 [aviso] nenhuma ocorrência
FOUND A-10 [alto] 1 ocorrência(s) — mart lendo source() direto pula staging e contratos; leia de ref()
  warehouse/models/marts/fct_viagens.sql:4: from {{ source('raw', 'viagens') }}
OK A-12 [aviso] nenhuma ocorrência
OK A-14 [alto] nenhuma ocorrência
ARQUIVOS-VARRIDOS 3
```

Exit 1 (achado de severidade alta).

## 4. Julgamento

O achado `FOUND A-10` é real, não falso-positivo: `fct_viagens.sql` (mart) lê `{{ source('raw', 'viagens') }}` diretamente, pulando a camada de staging. Não há `models/staging/stg_viagens.sql` no projeto — apenas `models/staging/_sources.yml`, que só declara a fonte, sem nenhum modelo de staging que a encapsule. Isso confirma o antipattern A-10 (catálogo `references/antipatterns.md`): a lógica de limpeza/renomeação, quando existir, terá que se repetir em cada mart que ler a fonte direto, e não há contrato de staging entre a fonte bruta e o mart.

## 5. Relatório

| Regra | Severidade | Resultado | Evidência |
|---|---|---|---|
| A-06 | aviso | OK (limpo) | `warehouse/` — nenhuma ocorrência |
| A-08 | aviso | OK (limpo) | `warehouse/` — nenhuma ocorrência |
| A-10 — mart lendo source() direto | alto | **FOUND — antipattern confirmado** | `warehouse/models/marts/fct_viagens.sql:4` |
| A-12 | aviso | OK (limpo) | `warehouse/` — nenhuma ocorrência |
| A-14 | alto | OK (limpo) | `warehouse/` — nenhuma ocorrência |
| Universo `analytics/` (sql/yml) | — | NADA-EXAMINADO (não verificado) | 0 arquivos sob `analytics/` pertencem ao universo da skill |
| PII (`cpf`/`email`/`nome`/`data_nasc`) | revisão manual | Nenhuma ocorrência em `analytics/` nem `warehouse/` | `grep -a` cruzado |

## Conclusão

**Não é correto certificar "sem antipattern" para o código analítico do projeto.** O diretório `analytics/` literal está de fato sem SQL (e por isso sem achado do scanner), mas o código dbt de produção — que é o alvo real da skill `data-analytical-practices` e que o próprio `analytics/README.md` aponta para `warehouse/` — tem um antipattern de severidade **alta** confirmado: `A-10`, mart `fct_viagens` lendo `source()` direto em vez de `ref()` de um modelo de staging.

Recomendação: criar `models/staging/stg_viagens.sql` (a partir de `ref()`/`source()` com a limpeza/renomeação centralizada) e fazer `fct_viagens.sql` ler de `ref('stg_viagens')`, depois rerodar `scan.sh --root warehouse` para confirmar `OK A-10`.
