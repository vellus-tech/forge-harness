# Design — add-migration-review-rule

> Design técnico do change `add-migration-review-rule` (issue #241).

## 1. Contexto e restrições

- O template já tem `rules/data/schema-evolution.md` (como migrar: expand/migrate/contract) e `rules/data/data-config-sql.md` (RLS obrigatório, exceção só por ADR/registro formal, `tenant_id`, centavos). A rule nova não repete essas normas — exige **revisão** antes do merge.
- Agentes de dados existentes (`data-engineer`, `data-relational`) não têm `Write`/`Edit`/`Agent` fora da lista permitida, e `data-relational` só tem `Bash` para `scan.sh` e `check-data-governance.sh --path` (`data-agent-bash-guard.sh`). O design não altera esses agentes nem o guard.
- Gates mecânicos existentes (`check-authz`, `check-observability`, `check-data-governance`) são scripts zero-dependência em `.forge/scripts/*.sh` + `.forge/scripts/lib/*.mjs`, registráveis em `runtime.gates` do `FORGE.md` e lidos por `lib/forge-runtime.sh` (CSV escalar ou block-sequence com `phase`). **Este gate não usa esse mecanismo** (§2.4 explica por quê — `runtime.gates` sempre chama `--path "$ROOT"`, sem range, o que não serve a um gate que precisa saber "o que este push tocou"); ele reusa, em vez disso, o padrão já usado por `check-ai-attribution.sh range` + o bloco dedicado de `no-ai-attribution` no `pre-push`.
- NFR-01 exige determinismo sem rede — o script não pode depender de `gh`/API do PR.

## 2. Decisão técnica

### 2.1 Rule `template/.forge/rules/data/migration-review.md`

Frontmatter: `title`, `applies_to: [relational-database, migrations]`, `priority: high`, `last_reviewed`, `based_on: []`. Seções:

1. **Quando se aplica** — todo PR que toca arquivo de migration (lista de padrões, mesma do script §2.2).
2. **Quem revisa** — `data-engineer` ou `data-relational`, sobre um clone da head do PR materializado pelo orquestrador/pipeline que conduz o PR (nunca pelo próprio especialista — ele não tem `git clone` liberado). A revisão de código geral não substitui esta.
3. **Checklist de 13 itens** — os itens literais do REQ-03, com referência a `schema-evolution.md` (item 10), `money-as-cents.md` (item 8) e `data-config-sql.md` (item 2, mecanismo de exceção de RLS).
4. **Exceção** — por item, registrada em `migration-review.md` (arquivo de evidência, §2.2) com backlog; item 2 exige também ADR/registro formal de `data-config-sql.md`.
5. **Gate mecânico (opcional, recomendado)** — chega junto com `npx forge-harness update` (script + bloco no `pre-push`, §2.4); a rule vale como norma mesmo em projeto com harness mais antigo, sem o gate.

### 2.2 Script `check-migration-review.sh` + `lib/check-migration-review.mjs`

Mesmo padrão de `check-ai-attribution.sh`/`.mjs` (não `check-data-governance.sh`, cuja invocação `--path $ROOT` sem range não serve para este gate — ver §2.4): wrapper bash resolve `FORGE_ROOT`, delega ao `.mjs` zero-dependência.

```
check-migration-review.sh range <rev-range> [--evidence <arquivo>]
check-migration-review.sh --path <dir> [--evidence <arquivo>]
```

Fluxo do `.mjs`:

1. **Resolver arquivos tocados.**
   - `range <rev-range>`: `base..head` → `git diff --name-only base..head`; **sha/ref único** (ref nova sem pai conhecido, caso do `pre-push` sem remote anterior) → `git diff-tree --root -r --name-only <sha>`, não `git diff --name-only <sha>` (ressalva do round 3: este último compara o commit ao working tree, não ao pai — dependeria da árvore de trabalho, o mesmo defeito que a leitura via `git show` no passo 4 evita). `--root` resolve também o commit raiz, sem pai algum. Ambos spawnSync, sem rede — os commits já existem localmente no momento do `pre-push`.
   - `--path <dir>`: caminhamento recursivo próprio (função pequena, não o `collect()` de `source-scan.mjs` — ele filtra só por `extname`, não por glob de path; reusa o mesmo `DEFAULT_SKIP` de diretórios ignorados por valor, não por import, para não acoplar à API de extensão dele).
2. **Filtrar por padrão de migration.** Lista default, fixa no script (globs → regex derivada, zero-dependência):
   - `db/migrate/**`, `db/migrations/**`, `migrations/**` (dbmate, Rails, node-pg-migrate)
   - `**/Migrations/*.cs` (EF Core)
   - `src/main/resources/db/migration/**` (Flyway)
   - `alembic/versions/**` (Alembic)
   Sem leitura de `FORGE.md` — `forge_get_runtime` (bash) só lê chave escalar direta sob `runtime:`; um bloco aninhado (`runtime.migration_review.patterns:` como array) não tem leitor e o `.mjs` não sourcea bash. Extensão da lista, se um projeto precisar, é editar a constante do script (documentado na rule) — ledger para configuração externa futura.
3. **Nenhum arquivo casado:** `PASS (sem migration)`, exit 0. Este gate **não** passa por `gate-universe.mjs`: "zero migration no range" é o caso comum (a maioria dos pushes não toca migration), diferente do universo de `check-data-governance` (arquivos `.md`/código, sempre não-vazio num repo normal) — tratar como vazio-suspeito faria `FAIL` em todo push sem migration.
4. **Ler arquivo de evidência.** Fixo: `migration-review.md` na raiz do repositório. A fonte depende do modo, porque o hook valida o que está sendo **enviado**, não a árvore de trabalho:
   - `range <rev-range>`: lê o conteúdo do blob no commit de destino do range via `git show <head>:migration-review.md` — nunca do disco. `<head>` é derivado do próprio `<rev-range>`: para `base..head`, a parte à direita de `..`; para um único ref/sha (ref nova, sem pai — caso do `pre-push`), o próprio valor. Um `migration-review.md` editado e não commitado, ou pertencente a outra branch checked-out, não deve fazer o gate passar (achado do round 2: ler do disco permite isso). Blob ausente naquele commit é tratado igual a arquivo ausente.
   - `--path <dir>` (modo ad-hoc/manual): lê do disco, `<dir>/migration-review.md` — aqui não há "commit sendo enviado", é inspeção direta de um diretório materializado (ex.: o clone que o especialista está revisando).
   `--evidence <path>` força um path/blob diferente do default nos dois modos. Ausente ⇒ todas as migrations do passo 2 ficam pendentes.
5. **Casar cada migration com uma linha de evidência.** Regex por linha:
   - `^\s*-\s*\[x\]\s+(?<path>\S+)` → revisada.
   - `^\s*-\s*\[exception\]\s+(?<path>\S+)\s+item=(?<item>\d{1,2})\s+backlog=(?<backlog>\S+)(?:\s+adr=(?<adr>\S+))?` → exceção; válida só com `backlog` presente, e com `adr` presente quando `item=2`.
   Path da linha comparado ao path do arquivo tocado (normalizado, relativo à raiz do repo).
6. **Resultado.** Migration sem linha casada, ou com linha de exceção inválida (sem `backlog`, ou `item=2` sem `adr`) → `FAIL` listando arquivo:motivo, exit 1. Todas casadas → `PASS` (ou `PASS (exceção item N, backlog X)` quando aplicável), exit 0.
7. **`range` com rev-range inválido:** `git diff` falha (exit ≠ 0) → captura o stderr, `FAIL (range inválido: <range>)`, exit 1 — nunca interpreta stderr/stdout vazio como "sem migration".

O script **não** lê/interpreta o SQL — só a forma da linha de evidência. A qualidade do parecer é responsabilidade humana/agente (REQ-02).

### 2.3 Extensão de `check-data-governance.mjs` (REQ-06)

Duas edições pontuais, sem mudar comportamento existente:

```js
const CODE_EXTS = new Set(['.go', '.kt', '.ts', '.rego', '.py', '.sql']);
const SENSITIVE_MARKER_RE = /(?:\/\/|#|--)\s*forge:sensitive-field\s*[:=]\s*"?([A-Za-z0-9_.]+)"?/i;
```

`LOG_CALL`/`PAN_DIGITS`/`CPF`/`EMAIL` continuam valendo para `.sql` automaticamente (já operam sobre qualquer `codeFiles`). Teste novo: fixture `.sql` com `-- forge:sensitive-field="cpf"` sem `data-classification.json` → `CONFLICT`; com entrada → `OK`. Suíte existente (fixtures `.go`) não muda.

### 2.4 Wiring no ciclo

**Por que não `runtime.gates`:** esse mecanismo (lido por `lib/forge-runtime.sh`) é CSV escalar de nomes, e tanto o `pre-push` (linha ~678: `bash '$gate_script' --path '$ROOT'`) quanto o `run-gates.sh` (linha ~103: idem) sempre invocam o gate com `--path "$ROOT"` — o repositório inteiro, sem range de commits. Para um gate cuja pergunta é "o que ESTE push tocou", isso faria todo push reprovar por causa de migrations antigas, nunca revisadas sob esta rule (que não existia quando elas foram criadas). `check-data-governance`/`check-authz` toleram esse contrato porque sua pergunta ("este arquivo contradiz a matriz?") é sobre o estado atual, não sobre o que mudou — a pergunta deste gate é inerentemente outra.

**Solução: mesmo padrão de `no-ai-attribution`.** O `pre-push` já resolve este problema para outro gate que também precisa de range por push: o bloco `AI_CHECK` (hook, por volta da linha 126) lê `$INPUT` (as refs do push, uma por linha: `local_ref local_sha remote_ref remote_sha`), calcula `range="$rsha..$lsha"` por ref (ou, em ref nova, `"$oldest~1..$lsha"`/`"$lsha"` quando não há pai), e chama `bash "$AI_CHECK" range "$range"`. Um bloco novo, imediatamente após o de `no-ai-attribution`, faz o mesmo para este gate:

```bash
MIGRATION_REVIEW_CHECK="$(resolve_delegated check-migration-review.sh scripts/check-migration-review.sh)"; _rc=$?
if [ "$_rc" -eq 1 ]; then
  echo "pre-push BLOQUEADO: .forge/scripts/ existe mas check-migration-review.sh não — delegação em alvo ausente" >&2
  exit 1
fi
if [ -n "$MIGRATION_REVIEW_CHECK" ]; then
  while read -r _lref lsha _rref rsha; do
    [ -n "${lsha:-}" ] || continue
    case "$lsha" in *[!0]*) : ;; *) continue ;; esac
    if [ -z "${rsha:-}" ] || [ "$rsha" = "0000000000000000000000000000000000000000" ]; then
      oldest="$(git rev-list "$lsha" --not --remotes 2>/dev/null | tail -1)"
      if [ -n "$oldest" ] && git rev-parse --verify --quiet "$oldest~1" >/dev/null 2>&1; then
        range="$oldest~1..$lsha"
      else
        range="$lsha"
      fi
    else
      range="$rsha..$lsha"
    fi
    if ! bash "$MIGRATION_REVIEW_CHECK" range "$range"; then
      echo "pre-push BLOQUEADO: migration sem parecer de revisão (rule data/migration-review.md)" >&2
      exit 1
    fi
  done <<EOF_MR
$INPUT
EOF_MR
fi
```

Roda incondicionalmente quando o script existe — mesmo critério do `AI_CHECK` — não como item de `runtime.gates`. **Correção do round 2:** `resolve_delegated` só devolve vazio (rc 0, no-op) quando `.forge/scripts/` está ausente nas duas árvores (projeto sem harness nenhum); com `.forge/scripts/` presente e o script especificamente ausente, devolve rc 1 e o hook **bloqueia** o push ("delegação em alvo ausente"), igual ao `AI_CHECK`. Na prática isso não é um modo de falha novo: o bloco do `pre-push` e `check-migration-review.sh` chegam juntos no mesmo `npx forge-harness update`, e o único cenário de "`.forge/scripts/` presente mas o script ausente" é uma atualização parcial manual — o mesmo risco que já existe para `check-ai-attribution.sh` hoje. Uso manual/CI próprio do projeto adotante: `bash .forge/scripts/check-migration-review.sh --path <dir>` ou `range <rev-range>` direto, fora do hook.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Gate só-norma (sem script) | Zero código, zero manutenção | Repete o modo de falha da issue: depende do orquestrador lembrar, a revisão geral de código já existia e não pegou os 5 bloqueantes | Rejeitada — decisão 2 da proposal |
| Ler o corpo do PR via `gh pr view --json body` | Fiel à redação original da issue ("parecer anexado ao PR") | Quebra NFR-01 (rede), exige token/autenticação, não funciona em `pre-push` local nem em projeto sem `gh` configurado | Rejeitada — evidência em arquivo committed é determinística e funciona local e em CI |
| Parser de DDL real para o item 9 (AST SQL) | Detecção mais forte de coluna sensível | Projeto grande, falsos positivos/negativos a calibrar, fora do "principalmente a rule" da issue | Rejeitada para esta entrega — extensão mínima de marcador (REQ-06) resolve o caso concreto sem o custo do parser |
| Checklist genérico multi-banco (PG + NoSQL) nesta entrega | Cobertura mais ampla | Itens de RLS/`CONCURRENTLY`/`DEFAULT PRIVILEGES` não existem fora de SQL; generalizar dilui a objetividade que a issue pede | Rejeitada — decisão 1, ledger para NoSQL futuro |

## 4. Contratos e integrações afetados

- Nenhuma API/evento de produto. Superfície nova: só o arquivo `migration-review.md` (contrato textual, formato de linha definido em §2.2) — sem bloco novo no `FORGE.md` (decisão §2.2/§2.4: sem leitor para config aninhada, defaults fixos no script).
- `check-data-governance.mjs` ganha uma extensão aditiva (REQ-06); contrato de saída (`OK`/`CONFLICT`) inalterado.

## 5. Plano de migração / rollout

Sem dado em produção para migrar — é maquinaria do template. Rollout: projeto adotante atualiza via `npx forge-harness update` (ou cópia manual da rule/script/bloco do `pre-push`) e o gate mecânico já vem ativo — nenhuma declaração extra em `FORGE.md` é necessária (diferente dos gates que passam por `runtime.gates`). Projeto que só copiar a rule, sem atualizar o `pre-push`/script, continua com a norma textual valendo — não há "big bang".

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| Padrão de path de migration não cobre a stack do projeto adotante | Média | Falso negativo (migration não detectada, gate não cobra) | Lista default cobre as 4 stacks mais comuns; extensão é editar a constante no script (sem leitor de config externa nesta entrega — ledger para o futuro); rule textual continua valendo independente |
| Linha de evidência malformada aceita por engano (regex frouxa) | Baixa | Falso `PASS` | Regex exige `backlog=` não vazio para exceção; teste cobre exceção sem `backlog` e item 2 sem `adr` → `FAIL` |
| Extensão `.sql` em `check-data-governance.mjs` gera falso positivo em comentário `--` genérico (não é o marcador) | Baixa | Ruído, não bloqueio incorreto (regex exige o literal `forge:sensitive-field`) | Regex ancorada no literal; teste de regressão com `.sql` sem o marcador deve continuar `OK` |
| Gate de migration registrado via `runtime.gates` por engano (convenção dos outros 3 gates) em vez do bloco dedicado no `pre-push` | Média | Gate roda com `--path $ROOT` sem range, reprova por migrations históricas em todo push | Rule documenta explicitamente que este gate NÃO usa `runtime.gates`; script não implementa um modo `--path $ROOT`-sem-range-é-tudo (o único modo `--path` existe para uso ad-hoc explícito, nunca é o que o hook chama) |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1 |
| REQ-02 | §2.1 (item 2), §1 |
| REQ-03 | §2.1 (item 3) |
| REQ-04 | §2.1 (item 4), §2.2 passo 5 |
| REQ-05 | §2.2, §2.4 |
| REQ-06 | §2.3 |
