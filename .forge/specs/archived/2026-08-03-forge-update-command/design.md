# Design — forge-update-command

## 1. Contexto e restrições

- `bin/forge.mjs` é o entrypoint npm, **zero-dep** (só node builtins), que reimplementa o `install.sh`
  em JS — o `update` deve ser JS puro aí, não shell-out.
- Peças reutilizáveis já no arquivo: `walk()` (L247), `scanProductContent()` (L123), `pkgVersion()`
  (L41), backup `.forge.bak-N` (L208), gitignore patch (L264), hooksPath wiring (L272), chamada
  `sync-adapters.mjs --root` (L294), `installPlugin()` (L149), `TEMPLATE_FORGE` (L35).
- Fronteira maquinaria×dados validada por grep: nenhum arquivo de maquinaria tem `<PROJECT_*>`.
- `sync-adapters.mjs` é idempotente (`writeIfChanged`) e aceita `--adapter all` (reconcilia contra a
  lista ativa sem alterá-la).

## 2. Decisão técnica

### 2.1 `update` no dispatch (REQ-01)
`case 'update': cmd = 'update'` no loop de argv (~L54). Novas flags: `--dry-run`, `--no-backup`
(`--no-plugin` já existe). Em `main()`, liberar `cmd === 'update'` do ramo de HELP e chamar
`updateHarness()` antes do ramo `init`.

### 2.2 `updateHarness()` (REQ-01..06)
```
target = resolve(--target|cwd); forge = target/.forge
if !exists(forge): fail("use `init` — .forge não existe", 3)
work = scanProductContent(forge)                 // só para relatar
src  = --source ? resolve : TEMPLATE_FORGE
MACHINERY = [agents, commands, hooks, schemas, scripts, skills, templates, rules]
// dry-run: computa paths que mudariam (walk src vs forge, compara conteúdo) e imprime; return
if !--no-backup && !dry: renameSync? NÃO — cp: copiar forge → .forge.bak-N (preserva original in place)
for d in MACHINERY: cpSync(src/d, forge/d, {recursive:true, force:true, filter: !.DS_Store})
cpSync(src/README.md → forge/README.md)
// adapters: só *.yaml, nunca *.lock.yaml
for f in readdir(src/adapters) where /\.yaml$/ && !/\.lock\.yaml$/: cpSync(f → forge/adapters/f)
orphanCheck(walk(forge overlaid dirs))           // fail se <PROJECT_*> aparecer
patchForgeYaml(forge/forge.yaml)                 // regex só template_version → pkgVersion()
ensureGitignore(target); ensureHooksPath(target) // reusa lógica do init (idempotente)
execFileSync(node, [syncMjs, --root, target, --adapter, all])
if claude ativo && !--no-plugin: installPlugin('')
run doctor.sh --report (post-check); print relatório
```
Backup: como o `update` **não** move o `.forge` (edita in place), o backup é uma **cópia**
`cpSync(forge → forge.bak-N)` antes de escrever (não `renameSync` como o init, que substitui a árvore).

### 2.3 `patchForgeYaml` (REQ-04)
Regex cirúrgica: `s/^(\s*template_version:\s*).*$/$1"<pkgVersion>"/m` no `forge.yaml`. Nada mais é
tocado — `adapters:` e flags preservados. Se a chave não existir (projeto muito antigo), inserir sob
`harness:`.

### 2.4 `--dry-run` (REQ-06)
Percorre a maquinaria comparando `readFileSync` template vs projeto; lista `~ modificado` / `+ novo`;
inclui a linha de `template_version` se mudaria. Não escreve; exit 0.

### 2.5 `/forge:upgrade` (REQ-07)
`template/.forge/commands/harness/upgrade.md` (frontmatter `description`+`argument-hint`). Protocolo:
(1) roda `npx forge-harness@latest update --dry-run` e mostra; (2) confirma; (3) roda sem `--dry-run`;
(4) resume. Nome evita colisão com `/forge:update` (grafo). Rebuild do plugin + contagem 50→51 em
`docs/refer/slash-commands.md`.

### 2.6 Correção do doctor (REQ-08)
`template/.forge/scripts/doctor.sh` (~L97): o `grep -rl '\.claude/'` e o check de placeholders passam a
`grep -vE '/(adapters|scripts)/|/commands/harness/|/(specs|worktrees|product|evals|custom)/'` —
excluindo conteúdo do usuário. Deixa o post-check do update limpo e conserta o falso-positivo real.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| `install.sh --update` (bash) | reusa o .sh | forge.mjs não chama o .sh; .sh é linear sem funções | JS é o entrypoint npm |
| Manifesto de hash + prune de órfãos | remove órfãos, detecta drift | change grande, novo artefato versionado | evolução futura (decisão travada) |
| `rules/` preservado (não overlay) | zero risco de sobrescrever custom | rules base nunca recebem melhorias | design: `custom/rules/**` é o override |
| Backup via `renameSync` (como init) | reusa padrão | move o `.forge` → teria que reinstalar | update edita in place; cópia é o certo |

## 4. Contratos e integrações afetados

- **CLI**: novo subcomando `update` + flags. `init`/`install-plugin` inalterados. HELP atualizado.
- **`forge.yaml`**: `harness.template_version` passa a ser escrito também pelo `update` (schema já
  define o campo; sem mudança de schema).
- **`doctor.sh`**: varredura mais estrita (menos falsos-positivos) — comportamento observável melhora.
- **plugin/marketplace**: +1 comando (`upgrade`); regenerado e commitado.

## 5. Plano de migração / rollout

Aditivo. O comando só chega aos projetos quando publicado no npm (rc9). Até lá, `--source` aponta o
template local (como o script ad-hoc fez). Nenhum projeto existente muda até rodar `update`.

## 6. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação / detecção |
|---|---|---|---|
| `rules/` overlay apaga rule editada in-place | Baixa | Médio | backup `.forge.bak-N` + `--dry-run`; doc do anti-padrão |
| Regex de `template_version` corrompe `forge.yaml` | Baixa | Alto | regex ancorada + gate w63 assere `adapters:` intacto |
| Órfão de maquinaria fica inerte | Média | Baixo | documentado; manifesto futuro |
| Backup por cópia infla disco | Baixa | Baixo | `--no-backup` (git é o backup real) |
| doctor loosening esconde vazamento real de maquinaria | Baixa | Médio | exclui só dirs de dado; maquinaria (agents/commands/…) segue varrida |

## 7. Rastreabilidade

| REQ | Seção do design |
|---|---|
| REQ-01 | §2.1, §2.2 |
| REQ-02 | §2.2 |
| REQ-03 | §2.2 (preserve list) |
| REQ-04 | §2.3 |
| REQ-05 | §2.2 |
| REQ-06 | §2.2, §2.4 |
| REQ-07 | §2.5 |
| REQ-08 | §2.6 |
| REQ-09 | §4, verificação via `npm test` |
