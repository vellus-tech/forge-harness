Passo a passo da execução

1. Li o prompt.md da tarefa e a skill impact-scan (.forge/skills/impact-scan/SKILL.md).
2. Inspecionei o estado: manifest.yaml do change 2026-09-estorno-parcial (affected_paths: src/billing/), impact.json antigo (seeds apenas invoice.ts e tax.ts, graph_fingerprint 511fd603...), e graph.json (7 nós, incluindo src/billing/refund.ts e src/api/routes/refunds.ts; fingerprint do grafo atual 7c38d7d8... após o último codegraph).
3. Li .forge/scripts/lib/impact-scan.mjs. O script expande prefixos de diretório (src/billing/) para os nós do grafo, então o affected_paths atual já cobre refund.ts.
4. Executei: node .forge/scripts/lib/impact-scan.mjs --graph .forge/graph/graph.json --change .forge/specs/active/2026-09-estorno-parcial (rc=0). Resultado: 3 seeds (invoice.ts, refund.ts, tax.ts) -> 6 impactados (payments.ts, refunds.ts, invoice.ts, refund.ts, tax.ts, daily.ts). impact.json regravado.
5. Verifiquei frescor: node .forge/scripts/lib/impact-freshness.mjs <change-dir> <raiz> -> "fresh" (rc=0).
6. Não toquei no manifest, no grafo, em código-fonte nem em specs. O archive não foi disparado (decisão do usuário).

Observação: git status da worktree de trabalho mostra muitos arquivos deletados em .claude/agents/ (cópia de trabalho divergente do HEAD). Não foi alterado nesta execução e não interfere no impact.json.
