---
description: Atualiza o grafo com reconstrução completa determinística; grava cada artefato quando seu conteúdo muda. O índice de símbolos inclui mtime e tamanho dos arquivos e pode ser regravado após edições cosméticas.
argument-hint: ""
---

# /forge:graph update — atualização incremental

## Execução

```bash
bash .forge/scripts/graph.sh update
```

Refaz o walk e a extração por completo (determinístico, nunca um atalho) e compara o resultado
contra o que já está em disco antes de gravar — `--if-changed` grava só o que divergiu:

- **Sem mudança estrutural** (só comentários/whitespace/reindentação) → "graph up to date (zero tokens)" — summaries cacheados são preservados; o índice de símbolos pode ser regravado por mudança de mtime ou tamanho.
- **Mudança estrutural** (novo import, nova declaração, arquivo novo/removido) → grafo regenerado; summaries dos nós alterados marcados stale para recuradoria sob demanda.
- **`symbols.json`/`symbols.idx.tsv`** regravam sempre que `{mtime,size}` de algum arquivo-fonte divergir do que foi registrado — mesmo quando o fingerprint estrutural do arquivo não mudou (editar só o corpo de uma função não altera o fingerprint, mas muda size/mtime).

## Quando rodar

- Após implementar tasks que tocaram código (antes de `/forge:impact` ou `/forge:archive`).
- O `doctor` avisa staleness quando arquivos grafados mudaram desde o último build.

## Regras

- É idempotente e barato — pode rodar sempre; não consome tokens de LLM (§16.2).
- Summaries só são regenerados (LLM) por decisão explícita via `file-analyzer`, nunca automaticamente no update.
