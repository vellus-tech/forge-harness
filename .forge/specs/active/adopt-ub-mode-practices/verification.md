# Verification — adopt-ub-mode-practices

## Resultado: APROVADO

## Evidências por requisito

| REQ | Implementado em | Verificado por | Status |
|---|---|---|---|
| REQ-01 | `template/.forge/commands/specs/implement.md` (parágrafo "Premissa nomeada" + pré-condição de retomada no passo 1), `template/.forge/agents/coding/task-coder.md` §3.7 (bloco acumulativo + chamada ao script + preflight) | `tests/adopt-ub-mode-practices-gate.sh` grupos `implement-wiring` (4 cenários), `coding-loop-wiring` (4 cenários), `premise-mutation` (mutação cobrindo os dois pontos de chamada e os dois de pré-condição) | VERIFICADO |
| REQ-02 | `template/.forge/scripts/check-attack-premise.sh` (gramática dos dois formatos, `--list`) | `tests/adopt-ub-mode-practices-gate.sh` grupo `script` (12 cenários) + `premise-mutation` (checagem interna mutada e morta pelo cenário `premise-mutation-1`) | VERIFICADO |
| REQ-03 | `template/.forge/scripts/check-suppression-reference.sh` (gramática de referência, exclusão de gerado/`.forge/`, exclusão do consumidor com motivo obrigatório), higiene em `red-evidence-ops.mjs`/`scan-native-controls.py` (LDG-0232), `template/.forge/rules/testing/quality-gates.md` (linha de enforcement) | `tests/adopt-ub-mode-practices-gate.sh` grupo `suppression-grammar` (11 cenários, inclui autoteste de universo não-vazio) | VERIFICADO |
| REQ-04 | `template/.forge/commands/git/ship.md` (passo 3, `--staged`), `template/.forge/hooks/git/pre-push` (bloco ancorado, `--range`, reuso de `_redfirst_resolve_base`), `template/.forge/skills/gate-runner/SKILL.md` (receita) | `tests/adopt-ub-mode-practices-gate.sh` grupos `suppression-wiring` (4 cenários, inclui comportamental extraindo o bloco real do pre-push) e `suppression-mutation` (4 cenários) | VERIFICADO |
| REQ-05 | `tools/spike-complexity-duplication.mjs` (roteiro executável) + `spike-result.md` (execução real sobre `Payments.DevPortal`, só-leitura) | `tests/adopt-ub-mode-practices-gate.sh` grupo `spike` (4 cenários, oráculo fixo de complexidade e duplicação) + execução manual registrada em `spike-result.md` (universo real: 50 arquivos, 429 funções, confirmado via `git status --short` no alvo antes/depois) | VERIFICADO |
| REQ-06 | `design.md` §2.4 (seção Decision/Consequences preenchida) + `.forge/product/current/adr/0006-complexidade-duplicacao-sinal-nao-bloqueante.md` + índice `README.md` atualizado | Spot-check manual: ADR cita o resultado real do spike (50%/33,3%/0% de falso-positivo nos limiares 10/15/20), decide Opção 2 com justificativa, lista as 4 opções descartadas com motivo | VERIFICADO |
| REQ-07 | `LDG-0233` (`.forge/ledger/ledger.json`/`LEDGER.md`), texto literal de `design.md` §2.5 | Spot-check manual: entrada presente em `LEDGER.md` após `ledger-ops.sh render`; verificado contra LDG-0021 (escopo diferente — fuzzing/corpus, não mutação de consumidor — sem `--ref`, item nasce separado) | VERIFICADO |
| NFR-01 | Nenhuma TASK rodou fora desta sessão de implementação — todo o diff fica sob `.forge/specs/active/adopt-ub-mode-practices/` mais os paths declarados nas TASKs (`template/.forge/...`, `tools/...`, `.forge/ledger/...`, `.forge/product/current/adr/...`) | `git diff --stat` da branch contra `develop` (checagem manual, sem path fora do esperado) | VERIFICADO |
| NFR-02 | Os dois gates novos (REQ-02/REQ-04) nasceram com nome, cenários e mutação já desenhados em `design.md` antes da implementação — nenhuma decisão de design nova precisou ser tomada durante `/forge:implement` | Spot-check: a implementação seguiu literalmente os cenários descritos em `design.md` §2.1/§2.2, sem desvio de escopo | VERIFICADO |

## Checks deterministas

`spec-verify.sh adopt-ub-mode-practices` — `OK adopt-ub-mode-practices (verification.yaml written)`. `FORGE.md runtime:` não declara check de stack (projeto não tem `test`/`typecheck`/`lint` padronizado nessa chave) — fase de check pulada pelo próprio script (`no checks declared`), não por omissão minha. Logs: nenhum (`skipped`).

Suíte própria do change: `bash tests/adopt-ub-mode-practices-gate.sh` — **PASS, 53/53 cenários**, todos os 9 grupos (`script`, `implement-wiring`, `coding-loop-wiring`, `human-wiring`, `premise-mutation`, `suppression-grammar`, `suppression-wiring`, `suppression-mutation`, `spike`). `plugin-sync-gate.sh` e `w242-implement-red-mecanismo-gate.sh` — PASS (espelhos do plugin sincronizados após TASK-02/04/05/10, achado real corrigido durante a implementação). Badge de contagem do README corrigido (218→219) após a adição do gate novo.

`run-all.sh` completo foi rodado uma vez durante a Wave 1 (173 PASS / 48 FAIL iniciais) e as 48 falhas foram investigadas e atribuídas a causa ambiental (duas causas reais, não relacionadas a este change: `node_modules` ausente no worktree, e `FORGE_ROOT` exportado indevidamente vazando para dentro dos fixtures dos `tests/*-gate.sh`) — confirmado por reprodução independente contra o commit pré-change (`a7a750d3`) nas mesmas condições. Não re-rodei a suíte completa de 1h+ ao final desta verificação; a suíte própria do change (53/53) e os dois gates estruturais (`plugin-sync-gate.sh`, `w242`) cobrem o que este change efetivamente toca.

## Desvios e observações

- **Desvio 1 (TASK-13):** a 1ª versão do fallback de `@babel/parser` para consumidor externo (`npx -p <pkg> node -e script`) não funciona — comprovado que `npx -p` não injeta `NODE_PATH` no processo `node` filho. Corrigido para `npm install --no-save --prefix <tmp>` + `createRequire`. Achado durante a prova de vermelho/verde via `red-evidence.sh` (worktree efêmero sem `node_modules`), não durante revisão de código — exatamente o tipo de achado que a prova por execução existe para capturar.
- **Desvio 2 (plugin sync, Waves 1/2):** cada edição de `template/.forge/commands/*.md` (TASKs 02, 04, 05, 10) exigiu sincronizar manualmente `plugin/forge/commands/*.md` via `node template/.forge/scripts/lib/plugin-build.mjs` — não documentado explicitamente no design, mas exigido pelo gate `plugin-sync-gate.sh` já existente no repositório. Registrado aqui porque não é mencionado em nenhuma TASK individual, só descoberto durante a implementação.
- **Desvio 3 (REQ-05, universo de duplicação):** `jscpd` com limiares padrão (`--min-lines 5 --min-tokens 50`) não encontrou NENHUM clone em `Payments.DevPortal` — resultado inconclusivo, não "duplicação resolvida". Registrado explicitamente em `spike-result.md` e herdado pela ADR 0006 como débito (item 3 das Consequências), não escondido.
- **Observação:** REQ-01/02 não cobrem o caminho `/forge:red replay`, por decisão de design explícita e registrada (replay reproduz o defeito original, não uma correção) — fora de escopo desde o `requirements.md`, não um corte feito durante a verificação.

## Premissas atacadas

`check-attack-premise.sh --list --file tasks.md`: **0 premissa(s) atacada(s)** — nenhuma TASK deste change sofreu `[!]` por "gate falha após 2 tentativas de correção" (nem por qualquer outra causa); todas as 16 TASKs fecharam `[X]` na primeira tentativa de implementação. Resultado normal, registrado como tal (zero não é omissão). Este change não usou `coding-loop`, então não há `PROGRESS-TRACKING.md` a consultar.
