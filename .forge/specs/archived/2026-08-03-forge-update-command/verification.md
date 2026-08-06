# Verification — forge-update-command

**Veredito global: PASS.** 9/9 REQ e 3/3 NFR verificados contra o código real em
`ab0c695`. Suíte completa verde (`npm test` → PASS=36 FAIL=0 SKIP=0). `validate-spec`
aprova com o `verification.yaml` presente. Idempotência confirmada manualmente
(2º `update --dry-run` = 0 mudanças).

## Tabela REQ-a-REQ

| REQ | Status | Evidência |
|---|---|---|
| REQ-01 — subcomando `update` | PASS | Dispatch `bin/forge.mjs:55`; `updateHarness()` `:218`; guarda `.forge` ausente → exit 3 `:221-222`; `--target` `:219`, `--source` `:224`; relatório atualizado/preservado/backup `:306-309`; HELP `:84,111-112`. Gate w63 `[0]` (exit 3). |
| REQ-02 — overlay aditivo | PASS | `MACHINERY_DIRS` `:176`; `machineryFiles()` `:179-199`; loop `cpSync` sem qualquer remoção `:256-261` (aditivo); `*.lock.yaml` excluído `:193`. Órfão preservado — gate w63 `[d]`; maquinaria nova chega `[e]`. |
| REQ-03 — preservação dos dados | PASS | Cópia restrita a `MACHINERY_DIRS` + `adapters/*.yaml` + `README.md`; `specs/product/custom/evals/runners.yaml/FORGE.md/constitution.md/context.md` nunca entram na lista `machineryFiles` `:179-199`. Gate w63 `[a]` (manifest/notes/ADR byte-idênticos), `[b]` (runners.yaml sha inalterado). |
| REQ-04 — merge campo-a-campo do forge.yaml | PASS | `bumpTemplateVersion()` `:202-216`; regex ancorada por linha `^(\s*)template_version:.*$` com flag `/m` (só a linha, preserva indentação) `:207-208`; `adapters:` intacto — gate w63 `[c]` compara lista antes/depois; chave ausente → insere sob `harness:` `:209-211`, senão retorna `false` sem tocar o arquivo `:212`. |
| REQ-05 — reconciliação de adapters/ambiente | PASS | `sync-adapters --adapter all` `:294`; `core.hooksPath .forge/hooks/git` `:283-290`; bloco managed do `.gitignore` `:276-278`; plugin re-materializado quando claude ativo `:297-301`; `--no-plugin` respeitado `:298`. Doctor pós-check `:304`. |
| REQ-06 — `--dry-run` e backup | PASS | Ramo dry-run computa `+ novo`/`~ modificado` e **retorna antes de qualquer escrita** `:229-243` (nenhum `cpSync`/`writeFileSync`/backup no caminho); backup é **cópia** `cpSync(forge → .forge.bak-N)` `:248-252` (não `renameSync`, que moveria o `.forge`). Gate w63 `[3]` (dry-run não altera disco) e `[f]` (backup no 1º run; `--no-backup` não cria `.bak-2`). |
| REQ-07 — slash `/forge:upgrade` | PASS | `template/.forge/commands/harness/upgrade.md` com frontmatter `description`+`argument-hint` válido; nome distinto de `/forge:update` (grafo) — ambos coexistem (`graph/update.md` + `harness/upgrade.md`). Plugin rebuildado: `plugin/forge/commands/upgrade.md` presente; contagem = 51 comandos; `plugin-sync-gate` verde; `docs/refer/slash-commands.md` diz "51 commands". |
| REQ-08 — falso-positivo do doctor | PASS | `doctor.sh:99` `USER_DATA='/(specs\|worktrees\|product\|evals\|custom)/'` aplicado às duas varreduras (`.claude/` `:100`; placeholders `:104`). Só adiciona exclusões → não pode gerar novos falsos-negativos de maquinaria; `agents/commands/hooks/schemas/rules` seguem varridos para placeholders (exclui apenas `/templates/` + USER_DATA). Sem auto-detecção em projeto instalado: em fixtures init'd (constitution/context/FORGE preenchidos) o doctor roda limpo — gates w13/w14/npx-pack verdes. Gate w63 `[g]` (spec citando `.claude/` não vira leak). |
| REQ-09 — suíte verde + tarball | PASS | `tests/w63-forge-update-gate.sh` cobre preservação (a–d), órfão (d), dry-run (3), doctor (g), idempotência (5); `tests/npx-pack-gate.sh [6]` exercita init+update do **tarball empacotado**. `npm test` → PASS=36. |
| NFR-01 — zero-dep | PASS | `bin/forge.mjs` importa apenas `node:*` builtins (`grep` de imports não-`node:` = vazio). Nenhuma dependência npm nova. |
| NFR-02 — idempotência | PASS | Teste manual: init → update → `update --dry-run` reporta "(nada a atualizar — já na versão do template)" / "0 mudança(s)". Também gate w63 `[5]`. |
| NFR-03 — reversibilidade | PASS | Toda escrita precedível por `--dry-run` `:229-243` e coberta por `.forge.bak-N` (cópia) `:248-252`, salvo `--no-backup` `:248`. |

## Notas de ceticismo (checagens que poderiam falhar e não falharam)

- **Órfão não deletado:** o overlay é estritamente `cpSync` arquivo-a-arquivo sobre paths da
  maquinaria; não há nenhum `rm`/`rmSync` em `updateHarness()`. Um `.md` extra do usuário em
  `commands/harness/` sobrevive (gate `[d]`).
- **Regex de `template_version`:** ancorada por linha e sem flag `g` — só a primeira ocorrência,
  sem `.` multiline, então não engole linhas seguintes nem toca `adapters:`. Verificado por diff da
  lista de adapters no gate `[c]`.
- **dry-run sem efeito colateral:** `return` na linha 242 precede backup e overlay; SHA do
  `manifest.yaml` e `forge.yaml` inalterados no gate `[3]`.
- **Falso "3 placeholders" do doctor:** ocorre apenas ao rodar `template/.forge/scripts/doctor.sh`
  diretamente (seu `ROOT=../..` resolve para `template/`, cujos `constitution/context/FORGE.md`
  carregam placeholders por design, preenchidos no init). Não é caminho de execução real nem
  regressão desta mudança — o doctor roda em projetos instalados, onde esses arquivos já estão
  preenchidos (fixtures init'd verdes).
