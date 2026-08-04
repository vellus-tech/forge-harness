# Proposal — gate-assert-visibility

> Change `gate-assert-visibility` (type: `bugfix`, scale 2) — criado em 2026-08-04 por Milton Antonio da Silva Jr.

## 1. Por quê (problema / motivação)

Gates de teste em `tests/*.sh` usam o padrão `[ cond ] && cmd` como asserção sob `set -e`. Esse padrão tem dois modos de falha silenciosa: quando a última cláusula da lista `&&` falha, `set -e` mata o script na hora, sem nenhuma mensagem `FAIL` explicando o motivo; quando uma cláusula não-final falha, ela é isenta de `set -e` (regra POSIX/bash) e o script segue como se tivesse passado — passagem silenciosa, mais grave, porque nem o código de saída sinaliza o problema. Origem: `LDG-0012` no ledger durável, registrado após um diagnóstico custoso em que o `w32-archive-gate` morreu no meio de um cenário sem indicar qual asserção falhou.

## 2. O que muda

52 sites de asserção bare em 20 arquivos de `tests/*.sh` convertidos para o idioma `cond || { echo "FAIL [n]: <motivo>"; exit 1; }`, já dominante na suíte (idioma A, 713+ ocorrências em 40 arquivos antes desta correção). Nenhum veredito de gate muda para entrada já coberta pela suíte hoje — a mudança é exclusiva de visibilidade da reprovação.

## 3. O que NÃO muda (fora de escopo)

- Os 9 sites de controle-de-fluxo legítimo (constroem estado condicional, não verificam invariante) permanecem intocados.
- Os sites já no idioma A ou B (também seguros) permanecem intocados.
- Lógica de negócio dos gates: o que hoje reprova continua reprovando, o que hoje passa continua passando (exceto onde a conversão revelou uma passagem silenciosa pré-existente e incorreta — ver achados incidentais abaixo, tratados como bug real, não como mudança de escopo).

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template`.
- **Paths afetados:** `tests/` (as 20 conversões + o novo teste Red `gate-assert-visibility-gate.sh`), `template/.forge/scripts/spec-transition.sh` + `template/.forge/scripts/lib/validate-spec.mjs` (fix incidental do `LDG-0030`, achado durante o gate `design_reviewed` deste próprio change), `tools/validate-forge.mjs` (ponteiro de dogfood).
- **Dependências:** nenhuma spec/código externo.
- **Riscos:** a conversão poderia, em tese, revelar violações reais previamente mascaradas (o próprio motivo do bugfix). Mitigado por: suíte completa antes/depois, investigação individual de cada reprovação nova (aconteceu 1 vez, em `w43-c4-gate.sh`, tratada como achado incidental — `LDG-0031` — não como regressão).

## 5. Próximos passos

Change já percorreu o ciclo completo nesta sessão: `/forge:requirements` (bugfix.md, 3 iterações de validação adversarial) → `/forge:tasks` (24 tasks, 2 iterações) → `/forge:implement` → `/forge:verify` (APROVADO) → `verified`. Revisão por `code-evaluator` (adaptado) rodando em PR #42 antes do merge em `develop`.
