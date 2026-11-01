# Requirements — add-migration-review-rule

> Requisitos do change `add-migration-review-rule`. Rastreiam à proposal (issue #241).

## REQ-01 — Rule `migration-review.md` segue a convenção do template

- **Quando** o template for consumido por `/forge:sync-adapters` ou `validate-rules.sh`, **o sistema deve** reconhecer `template/.forge/rules/data/migration-review.md` como rule válida: frontmatter com `title`, `applies_to` (incluindo `relational-database`, `migrations`), `priority`, `last_reviewed` e `based_on: []`.
- **Critérios de aceite:**
  - [ ] `validate-rules.sh` passa sem erro sobre o arquivo novo.
  - [ ] `based_on: []` (rule não herda de outra; é a decisão explícita da issue).
  - [ ] A rule referencia `schema-evolution.md` e `data-governance.md` sem duplicar o conteúdo deles (complementa, não repete o "como migrar").
- **Rastreia:** proposal §2.1
- **Notas:** convenção verificada em `regression-red-first.md` e demais rules de `template/.forge/rules/`.

## REQ-02 — Exigência de revisão especializada antes do merge

- **Quando** um PR tocar arquivo de migration, **o sistema deve** (via rule, norma aplicada por quem conduz o change/PR) exigir revisão do agente `data-engineer` ou do especialista `data-relational`, executada sobre um clone da head do PR, adicional à revisão geral de código.
- **Critérios de aceite:**
  - [ ] A rule declara explicitamente quem executa a revisão (data-engineer ou data-relational) e sobre o quê (clone da head do PR, não a branch local do autor).
  - [ ] A rule declara que a revisão de código geral não substitui esta revisão.
  - [ ] A rule declara que **quem clona a head do PR e entrega o path ao especialista é o orquestrador/pipeline que conduz o PR**, nunca o próprio agente especialista: `data-relational` só tem `Bash` para `scan.sh` e `check-data-governance.sh --path` (`data-agent-bash-guard.sh`), não para `git clone`/`gh pr checkout`. O especialista revisa por `Read`/`Grep`/`Glob` sobre o path já materializado, e roda `check-migration-review.sh` **não** é responsabilidade dele — é um gate separado (REQ-05), rodado pelo orquestrador/CI.
- **Rastreia:** proposal §2.1

## REQ-03 — Checklist de 13 itens, objetivo e verificável

- **Quando** a revisão especializada for executada, **o sistema deve** fornecer um checklist de exatamente 13 itens, enumerados literalmente abaixo (fonte: issue #241, sem fusão nem split), cada um redigido como condição verificável.
- **Critérios de aceite — os 13 itens, um a um:**
  - [ ] **1.** Cabeçalho da migration com fase (`expand`\|`contract`\|`data`), referência de issue, role de dono e `lock_timeout`/`statement_timeout` declarados.
  - [ ] **2.** RLS com `ENABLE` e `FORCE` em toda tabela com chave de tenant, política restrita à role do serviço, `NULLIF(current_setting(...), '')` no predicado, ou exceção formal com prazo — a exceção de RLS segue o mecanismo de `data-config-sql.md` (ADR ou registro formal), não o mecanismo mais leve do REQ-04; o PR referencia esse ADR/registro.
  - [ ] **3.** Nenhuma política para `PUBLIC`; o serviço fixa o GUC de tenant dentro da transação (`SET LOCAL`/`set_config(..., true)`), nunca GUC de sessão com pool.
  - [ ] **4.** Privilégio mínimo: `GRANT` por tabela à role do dono, sem `BYPASSRLS`, sem `ON ALL TABLES` e sem `ALTER DEFAULT PRIVILEGES` de grupo.
  - [ ] **5.** Chave única de negócio sempre prefixada pelo `tenant_id` (nunca índice único global sobre CPF/CNPJ/e-mail).
  - [ ] **6.** Índice em tabela existente com `CREATE INDEX CONCURRENTLY` em arquivo de migration próprio (nunca junto de outro DDL transacional); constraint com `NOT VALID` seguido de `VALIDATE CONSTRAINT` em migrations separadas.
  - [ ] **7.** Nenhuma FK entre tabelas de donos/serviços diferentes; nenhum `ON DELETE CASCADE` sobre dado financeiro ou de identidade.
  - [ ] **8.** Dinheiro em inteiro de centavos — referencia `rules/domain/money-as-cents.md` (não redige a regra de novo).
  - [ ] **9.** Coluna sensível classificada no mesmo PR: quando existir `data-classification.json` no projeto, é a autoridade sobre quais colunas são PAN/PII (mesma convenção do `data-relational`); hash de identificador só com HMAC chaveado (chave em KMS), nunca hash sem chave.
  - [ ] **10.** Backfill e expurgo com commit por lote, idempotentes e com retomada após falha — referencia `rules/data/schema-evolution.md` §"Migrate/backfill" (não redige a regra de novo); proíbe expurgo em bloco único (`DO $$` sem lotes) sobre tabela grande.
  - [ ] **11.** Contract só depois do expand promovido (todos os produtores/consumidores migrados); `down` que destruiria dado recusa execução, exigindo exceção explícita.
  - [ ] **12.** Tabela append-only revoga `UPDATE`, `DELETE` e `TRUNCATE` da role de aplicação e usa trigger de proteção com `ENABLE ALWAYS` (não desativável por `SET session_replication_role`).
  - [ ] **13.** Suíte de integração com RLS ligado provando três casos: (a) positivo — tenant correto lê suas linhas; (b) outro tenant — zero linhas; (c) GUC de tenant vazio/ausente — zero linhas e escrita recusada.
- **Rastreia:** proposal §2.2
- **Notas:** a issue cita `rules/data/migrations.md` como rule existente; esse arquivo não existe no template (`template/.forge/rules/data/` tem `schema-evolution.md`, não `migrations.md`) — tratado como imprecisão da issue, registrado aqui para não repetir a referência errada na rule nova.

## REQ-04 — Exceção por item, só com registro explícito e backlog associado

- **Quando** um item do checklist não puder ser atendido, **o sistema deve** exigir que a exceção seja registrada por item, no arquivo de evidência (REQ-05), com o id/link do backlog que resolve a pendência — nunca uma exceção genérica para o PR todo. Para o item 2 (RLS), a exceção exige também o ADR/registro formal que `data-config-sql.md` já cobra (REQ-03 item 2); os outros 12 itens exigem só o registro no arquivo de evidência com backlog.
- **Critérios de aceite:**
  - [ ] A rule proíbe exceção tácita (sem registro) e exceção de PR inteiro sem apontar o item específico (1 a 13).
  - [ ] A rule exige backlog associado (id de issue/ticket) para toda exceção; o prazo da exceção é o do próprio item de backlog (sem campo de prazo redundante).
  - [ ] Para o item 2, a rule exige citar o ADR/registro formal de `data-config-sql.md` além do backlog.
- **Rastreia:** proposal §2.3

## REQ-05 — Gate mecânico de detecção de migration em push/PR

- **Quando** um `git push` incluir commit(s) que tocam arquivo de migration por convenção de path, **o sistema deve** reportar via script (`check-migration-review.sh`) a ausência de evidência de parecer de revisão com saída não-zero e mensagem clara, sem depender de rede/`gh` (NFR-01).
- **Correção de round de design:** o mecanismo genérico `runtime.gates` (lido por `lib/forge-runtime.sh`) sempre invoca o script com `--path "$ROOT"` (repositório inteiro, sem range), tanto no `pre-push` quanto no `run-gates.sh` — não há como declarar este gate ali e obter escopo de diff. Este gate precisa do padrão já usado por `check-ai-attribution.sh` (modo `range <rev-range>`, hook `pre-push` calcula o range por ref exatamente como já faz para `no-ai-attribution`): sem isso, o gate trataria **toda migration já existente no histórico** como pendente de parecer em todo push, inviável em repositório brownfield.
- **Modos do script:**
  - `check-migration-review.sh range <rev-range>` — modo de push/CI: resolve os arquivos tocados via `git diff --name-only base..head` (forma `base..head`) ou `git diff-tree --root -r --name-only <sha>` (forma de sha/ref único, sem pai conhecido — nunca `git diff --name-only <sha>`, que compara contra a árvore de trabalho e reintroduziria a dependência do disco local que o modo `range` existe para evitar), filtra pelos padrões de migration, e cobra evidência só para eles.
  - `check-migration-review.sh --path <dir>` — modo ad-hoc/manual (revisão de um diretório específico): lista todo arquivo de migration sob o diretório (caminhamento próprio, não pelo `collect()` de `source-scan.mjs`, que filtra só por extensão) e cobra evidência para todos eles.
- **Fonte única da evidência:** um arquivo committed, nome e localização fixos (sem leitura de bloco do `FORGE.md` — `forge_get_runtime` só lê chave escalar direta sob `runtime:`, não bloco aninhado; nenhuma leitura de `FORGE.md` dentro do `.mjs`): **`migration-review.md`** na raiz do repositório (`--evidence <path>` para apontar outro local, uso ad-hoc). Formato de linha, por migration tocada: `- [x] <path-da-migration>` (revisada) ou `- [exception] <path-da-migration> item=<1-13> backlog=<ref>` (e, se `item=2`, também `adr=<ref>`). O script só confere presença/forma da linha — não avalia a qualidade do parecer, isso é humano/agente (REQ-02).
- **Padrões de path de migration (default, fixos no script; sem leitura de config externa nesta entrega):** `db/migrate/**`, `db/migrations/**`, `migrations/**`, `**/Migrations/*.cs` (EF Core), `src/main/resources/db/migration/**` (Flyway), `alembic/versions/**`. Lista extensível só editando a constante do script (documentado na rule); ledger para configuração externa futura se um projeto adotante precisar.
- **Integração no ciclo:** bloco novo no `pre-push`, modelado no bloco existente de `no-ai-attribution` (mesmo cálculo de `range` por ref de `$INPUT`, mesmo `resolve_delegated`) — **não** via `runtime.gates` (que não dá escopo de diff). Dois cenários distintos de ausência: (a) projeto sem `.forge/scripts/` nenhum (harness não instalado) — bloco não executa, rc 0, rule vale só como norma (fallback da decisão 2); (b) `.forge/scripts/` presente mas `check-migration-review.sh` especificamente ausente (atualização parcial do harness) — `resolve_delegated` retorna rc 1 e o push é **bloqueado** ("delegação em alvo ausente"), mesmo comportamento já existente para `check-ai-attribution.sh` hoje, não um modo de falha novo deste gate.
- **Não usa `gate-universe.mjs`:** "zero migration no range" é o caso comum (a maioria dos pushes não toca migration) — tratar como universo vazio suspeito geraria `FAIL` em todo push sem migration, o oposto do comportamento desejado.
- **Critérios de aceite:**
  - [ ] `range <rev-range>`: resolve arquivos via `git diff --name-only <rev-range>`.
  - [ ] `--path <dir>`: caminha o diretório (walker próprio) e lista todo arquivo cujo path casa algum padrão de migration.
  - [ ] Sem arquivo de migration no escopo: saída `PASS (sem migration)`, exit 0.
  - [ ] Com migration e sem linha de evidência (nem revisada nem exceção) para ela no arquivo de evidência: saída `FAIL` nomeando o(s) arquivo(s) de migration pendentes, exit 1.
  - [ ] Com migration e linha `- [x] <path>` no arquivo de evidência: saída `PASS`, exit 0.
  - [ ] Com migration e linha `- [exception] <path> item=<N> backlog=<ref>` válida (e `adr=<ref>` quando `item=2`): saída `PASS (exceção item <N>, backlog <ref>)`, exit 0.
  - [ ] Linha de exceção sem `backlog=` (ou, quando `item=2`, sem `adr=`): tratada como evidência ausente — `FAIL`, exit 1 (não é exceção válida).
  - [ ] `range` com rev-range inválido: `FAIL (range inválido)`, exit 1 — nunca `PASS` silencioso.
  - [ ] Script não analisa o SQL em si (isso é tarefa do especialista) — só verifica presença/forma da linha de evidência.
  - [ ] Teste automatizado cobre: sem migration; com migration sem evidência; com migration revisada; com exceção válida (item ≠ 2); com exceção do item 2 sem `adr=`; `range` com rev-range inválido; `--path` em diretório sem migration; `range <sha-único>` (commit raiz/sem pai) resolvendo via `git diff-tree --root -r --name-only`, não via working tree.
- **Rastreia:** proposal §2.4, §5 (decisão 2)
- **Notas:** decisão 2 da proposal — gate mecânico com fallback de norma textual na rule (a rule vale mesmo em repositório sem o script instalado). O bloco novo no `pre-push` é consequência direta da decisão 2: sem ele, o gate seria um script que ninguém chama — o mesmo modo de falha que a decisão rejeitou.

## REQ-06 — `check-data-governance.sh` passa a ler `.sql` (revisão da decisão 3)

- **Contexto:** a leitura de `template/.forge/scripts/lib/check-data-governance.mjs` mostrou que o verificador já foi estendido (REQ-12, issue anterior) para ler código (`CODE_EXTS = .go/.kt/.ts/.rego/.py`), não só `.md` — a premissa da issue #241 ("hoje só lê .md") está parcialmente desatualizada. Adicionar `.sql` a `CODE_EXTS` e o comentário de linha `--` ao `SENSITIVE_MARKER_RE` é uma extensão pequena e aditiva sobre uma estrutura já existente, não um parser novo — por isso a decisão 3 da proposal **muda de "não fazer" para "fazer"**, restrita a este escopo mínimo.
- **Quando** um arquivo `.sql` contiver o marcador `-- forge:sensitive-field="<campo>"` sem entrada correspondente em `data-classification.json` no mesmo escopo examinado, **o sistema deve** reportar `CONFLICT` (mesmo contrato do REQ-12b), e **quando** um arquivo `.sql` contiver PAN/CPF/e-mail em chamada de log na mesma linha, **o sistema deve** reportar `CONFLICT` (mesmo contrato do REQ-12a) — sem alterar o comportamento hoje existente para `.go/.kt/.ts/.rego/.py/.md`.
- **Critérios de aceite:**
  - [ ] `.sql` entra em `CODE_EXTS`.
  - [ ] `SENSITIVE_MARKER_RE` aceita `--\s*forge:sensitive-field` além de `//` e `#`.
  - [ ] Teste novo: arquivo `.sql` com marcador sem `data-classification.json` correspondente → `CONFLICT`; com entrada correspondente → `OK`.
  - [ ] Teste novo: arquivo `.sql` com PAN/CPF/e-mail na mesma linha de uma chamada `log.*(`/`logger.*(` → `CONFLICT` (mesma regra `LOG_TAINT`, aplicada automaticamente a qualquer extensão em `CODE_EXTS`); `.sql` sem esse padrão (DDL comum) → `OK`, sem falso positivo.
  - [ ] Suíte existente (`tests/gw3-data-governance-gate.sh` e fixtures `.go`) permanece verde sem alteração (NFR-04 do REQ-12 original).
- **Rastreia:** proposal §5 (decisão 3, revisada)
- **Notas:** este REQ é uma extensão pequena e isolada; não cobre parsing de DDL (tipo de coluna, DDL walker) — só o marcador de comentário convencional, mesmo mecanismo já usado nas outras linguagens.

## Requisitos não funcionais do change

- **NFR-01 —** O script novo é determinístico e não depende de rede (mesmo padrão de `check-data-governance.sh`); método de medição: execução repetida com mesma entrada produz mesma saída.

## Checklist de cobertura de superfície

| REQ | Parâmetro/config exposto | Superfície (tela/endpoint/CLI) | Coberto por task |
|---|---|---|---|
| REQ-05 | `--path`, `range` | CLI `check-migration-review.sh` | TASK-02, TASK-03, TASK-04 |
| REQ-01 a REQ-04 | — | sem parâmetro exposto (rule é documento normativo lido por agente/humano) | TASK-01 |

## Fora de escopo (reafirmação)

- Checklist equivalente para NoSQL/outros bancos relacionais (decisão 1).
- Reescrita de `schema-evolution.md`.
