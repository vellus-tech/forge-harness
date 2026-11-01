# Verification — add-migration-review-rule

## Resultado: APROVADO

Checkpoint de verify guiado, conferido REQ a REQ contra o código real (não contra os relatórios dos implementadores), em duas rodadas: a primeira achou um BLOCKER de regressão e 5 MINOR; a segunda, após correção (commit `7536b1ec`), confirmou **VERIFIED** sem achado novo.

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 | `template/.forge/rules/data/migration-review.md` (frontmatter + 5 seções) | `bash template/.forge/scripts/validate-rules.sh` + `tests/migration-review-gate.sh#[1]-[2]` (grep dos 13 itens, exceção, quem revisa, referências — `based_on: []` faz `validate-rules.mjs` pular validação de conteúdo, por isso o grep explícito) | VERIFICADO |
| REQ-02 | `template/.forge/rules/data/migration-review.md` §"Quem revisa" | `tests/migration-review-gate.sh#[2]` | VERIFICADO |
| REQ-03 | `template/.forge/rules/data/migration-review.md` §"Checklist (13 itens)" | `tests/migration-review-gate.sh#[2]` (grep item a item) | VERIFICADO |
| REQ-04 | `template/.forge/rules/data/migration-review.md` §"Exceção" + `check-migration-review.mjs:evaluate()` | `tests/migration-review-gate.sh#[6]` (exceção válida), `#[7]` (item 2 sem `adr=` → FAIL) | VERIFICADO |
| REQ-05 | `template/.forge/scripts/check-migration-review.sh` + `lib/check-migration-review.mjs` (modos `range`/`--path`) + bloco `MIGRATION_REVIEW_CHECK` em `template/.forge/hooks/git/pre-push` | `tests/migration-review-gate.sh#[3]-[14]` (14 casos: sem migration, sem evidência, revisada, exceção válida/inválida, range inválido, sha único via `diff-tree --root`, evidência só no disco não passa no modo `range`, `--path` ad-hoc, wiring real no `pre-push` com push simulado determinístico) | VERIFICADO |
| REQ-06 | `template/.forge/scripts/lib/check-data-governance.mjs` (`.sql` em `CODE_EXTS`, `--` em `SENSITIVE_MARKER_RE`) | `tests/req12-pii-log-gate.sh#[6]-[9]` + retrocompat `#[5]` (chama `gw3-data-governance-gate.sh`) | VERIFICADO |

## Checks deterministas

Nenhum check declarado em `FORGE.md runtime:` deste repositório de template (dogfood) — fase de check do `spec-verify.sh` pulada por ausência de declaração, comportamento esperado. Evidência real é a suíte de testes do próprio harness, rodada manualmente (ver histórico de execução abaixo) porque o dogfood não roda `/forge:verify` fim a fim.

Suítes relevantes, todas verdes na rodada final (commit `7536b1ec`):

- `tests/migration-review-gate.sh` — 14/14 casos OK.
- `tests/gw3-data-governance-gate.sh` — 8/8 OK (sem regressão).
- `tests/req12-pii-log-gate.sh` — 9/9 OK, incluindo os 4 casos novos do REQ-06.
- `tests/w223-delegacao-arvore-do-hook-gate.sh` — PASS (suíte estrutural do `pre-push`, ajustada para o 5º alvo delegado).
- `tests/w120-ai-attribution-gate.sh` — PASS (bloco irmão `AI_CHECK`, não regrediu).
- `tests/w135-push-refs-export-gate.sh`, `tests/w152-push-ahead-gate.sh`, `tests/w253-heavy-mutex-posse-gate.sh` — PASS após o fix de stub.
- `tests/w151-heavy-mutex-gate.sh` — PASS (56 cenários); uma falha intermitente de concorrência (`[48c]`) observada numa execução concorrente com outras suítes foi reproduzida e confirmada como pré-existente/não relacionada a este change (passou isolada antes e depois da correção).

`verification.yaml` gravado por `spec-verify.sh` com `commit` apontando para o HEAD no momento da verificação.

## Desvios e observações

- **BLOCKER achado e corrigido (round 1 de verify):** o bloco `MIGRATION_REVIEW_CHECK` novo no `pre-push` passou a bloquear 4 suítes pré-existentes (`w135`, `w151`, `w152`, `w253`) que montam `.forge/scripts/` parcial sem o stub do script novo — regressão fora do escopo que a implementação original havia testado. Corrigido adicionando `check-migration-review.sh` às listas de stub dos 4 arquivos, mesmo padrão já usado em `w223`.
- **5 MINOR achados e corrigidos (mesma rodada):** regex `item=` sem limite 1-13 (aceitava 0/99); ordem de campos (`item=`/`backlog=`/`adr=`) não documentada na rule; bug latente no split de range para a forma `a...b` (nunca acionado pelo `pre-push`, só manual); mensagem de `PASS` com exceção divergindo do texto exato do critério de aceite (tinha prefixo de path); quebra de linha manual a meio de frase na rule, violando a convenção de linha lógica contínua do repositório.
- **Decisão 3 da proposal revertida durante a execução:** a proposal original decidia por NÃO estender `check-data-governance.sh`; a leitura do código real mostrou que o verificador já lia `.go/.kt/.ts/.rego/.py` (extensão de uma issue anterior), tornando a extensão para `.sql` pequena e aditiva — decisão revisada para FAZER (REQ-06), registrada e justificada na proposal §5.
- **Nenhum desvio não resolvido.** Tudo que foi encontrado em qualquer rodada de revisão (requirements, design, tasks, verify) foi corrigido antes do fechamento desta fase.
