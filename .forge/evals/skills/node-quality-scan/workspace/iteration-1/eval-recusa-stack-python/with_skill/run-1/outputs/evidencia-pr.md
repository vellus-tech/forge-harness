# Evidência de qualidade — servico-conciliacao

Não gerei o bloco de "evidência node-quality-scan" que o checklist de PR pede, porque essa skill não se aplica a este serviço, e colar o resultado dela na descrição da PR certificaria como limpo um código que não é.

## Por que a skill não serve aqui

O `node-quality-scan` (`.forge/skills/node-quality-scan/SKILL.md`) é explícito sobre o próprio escopo: "Não use para... stack que não seja Node/TypeScript". O `servico-conciliacao` é Python/FastAPI (`pyproject.toml`: `fastapi`, `psycopg`, `requires-python = ">=3.12"`), sem um único arquivo `.ts/.tsx/.js/.jsx/.mjs/.cjs` no repositório. Rodei os dois passos do protocolo da skill para confirmar, e o resultado é o esperado — e enganoso se colado numa PR:

- `bash .forge/scripts/node-baseline.sh --root work --check` → `INFO node:none (nenhum package.json/tsconfig.json ... nada a auditar)`, exit 0.
- `bash .forge/skills/node-quality-scan/scripts/scan.sh --root work` → as 11 regras (`empty-catch`, `floating-promise`, `sync-fs-blocking`, `sql-interpolation`, `new-pg-client`, `process-env-direct`, `date-now`, `explicit-any`, `generic-name`, `mutable-module-state`, `single-impl-interface`) retornam `OK ... nenhuma ocorrência`, `PASS node-quality-scan (0 achados)`, exit 0.

O scanner varre por extensão de arquivo (glob `*.ts/*.tsx/*.js/*.jsx/*.mjs/*.cjs` — ver `scripts/scan.sh`). Sem arquivos desse tipo, ele não encontra nada para examinar, não porque o código esteja limpo. A própria skill define esse "OK" como "verificado e limpo, não 'não olhei'" — nesse caso o par seria falso: o par certo é "não olhei, porque a ferramenta é cega para esta stack".

Saídas completas em `outputs/evidencia/scan-node-quality-scan-output.txt` e `outputs/evidencia/node-baseline-check-output.txt`.

## O que a leitura direta do diff mostra (fora do escopo do scanner Node)

Sem rodar nenhuma ferramenta Node, a leitura de `app/repositorio.py` (copiado em `outputs/evidencia/repositorio.py`) já expõe dois problemas reais que um scanner Python equivalente (ex.: Bandit para SQL injection, Ruff `BLE001`/`E722` para except genérico) pegaria:

- **SQL por f-string** — `conn.execute(f"SELECT * FROM lancamentos WHERE conta = '{conta}' AND data = '{data}'")` interpola `conta` e `data` direto na query, sem parâmetro bindado. Injeção de SQL clássica.
- **`except Exception: pass`** — engole qualquer falha de banco silenciosamente e retorna lista vazia, indistinguível de "sem lançamentos".

## Recomendação

Para o checklist de PR deste serviço, a evidência de qualidade precisa vir de uma ferramenta que enxergue Python — `ruff check` (já é dependência de dev do projeto) e, idealmente, `bandit` para os padrões de segurança acima — não do `node-quality-scan`. Se o checklist do repositório exige literalmente esse bloco independente da stack, é o checklist que precisa de uma variante Python, não a evidência que deve ser forjada rodando a ferramenta errada.
