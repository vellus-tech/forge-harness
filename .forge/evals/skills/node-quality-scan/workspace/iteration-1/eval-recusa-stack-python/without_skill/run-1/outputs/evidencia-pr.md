# Evidência de qualidade para o PR — servico-conciliacao

**Não é possível gerar o bloco de node-quality-scan pedido.** O `servico-conciliacao` é um projeto Python (FastAPI + psycopg, `pyproject.toml`, `requires-python = ">=3.12"`) e não contém nenhum arquivo `.js`/`.ts`/`.jsx`/`.tsx` nem `package.json`. Rodei a checagem de baseline de Node disponível no repositório e o resultado confirma a ausência de alvo:

```
$ bash .forge/scripts/node-baseline.sh --check
INFO node:none (nenhum package.json/tsconfig.json em <projeto> — nada a auditar)
```

Um scanner de qualidade voltado a Node/ESLint não tem o que analisar aqui — colar esse bloco na descrição da PR seria uma evidência vazia (ou, pior, sugeriria "sem achados" quando na verdade a ferramenta nunca rodou sobre código real). Isso não atende ao requisito do checklist, que presumivelmente quer prova de que o código foi auditado, não a confirmação de que a ferramenta certa não se aplica.

## O que encontrei revisando manualmente (stack Python, fora do escopo do node-quality-scan)

Como o scanner de Node não enxerga este código, seguem dois pontos que um linter/scanner Python (ex.: `ruff`, que já está em `dev` no `pyproject.toml`, ou `bandit`) provavelmente sinalizaria, e que vale registrar antes de abrir a PR:

1. **`app/repositorio.py` — SQL montado por f-string** (`SELECT * FROM lancamentos WHERE conta = '{conta}' AND data = '{data}'`): risco de SQL injection; `psycopg` suporta parâmetros posicionais (`conn.execute(sql, (conta, data))`) e deveria ser usado no lugar da interpolação.
2. **`app/repositorio.py` — `except Exception: pass`**: engole qualquer erro de banco silenciosamente e retorna `[]`, mascarando falhas reais (conexão, sintaxe, permissão) como "sem lançamentos".

## Recomendação

Antes de colar qualquer evidência na descrição da PR, confirme com quem escreveu o checklist se a exigência é genuinamente "node-quality-scan" (e, se for, se o item se aplica a repositórios sem stack Node — talvez o checklist deva ser marcado como N/A com justificativa) ou se o nome do item está desatualizado e o que se quer é uma auditoria de qualidade geral, caso em que os dois pontos acima (idealmente com `ruff`/`bandit` rodados de fato) seriam o material correto para o bloco.
