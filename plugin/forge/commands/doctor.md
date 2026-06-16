---
description: Valida o harness Forge e a tooling do projeto (stacks, adapters, symlinks, drift de lockfile, placeholders orfaos). Use apos init/sync, ao suspeitar de drift, ou antes de abrir PR.
---

# /forge:doctor

Execute o validador determinista e reporte o resultado de forma compacta:

1. Rode `bash .forge/scripts/doctor.sh --report` (saída completa em `/tmp/forge-doctor.log` se longa; leia só o necessário).
2. Se exit code = 0: responda em 1-3 linhas confirmando harness e diagnósticos OK.
3. Se exit code = 1: liste APENAS os itens `✗` (miss) com a ação sugerida de cada um (ex.: "rode `.forge/scripts/sync-adapters.sh`"). Não despeje a saída inteira.
4. Se o usuário pedir correção automática (`--install` para tooling de stack), confirme antes — o doctor nunca instala nada sozinho.

Checks de harness cobertos (§19.1): FORGE.md/forge.yaml presentes, AGENTS.md é projeção gerada, symlinks CLAUDE/QWEN/GEMINI.md → AGENTS.md (ou cópia gerada), fonte canônica sem refs legadas ao diretório do adapter Claude, sem placeholders `<PROJECT_*>` órfãos, lockfile do adapter sem drift.
