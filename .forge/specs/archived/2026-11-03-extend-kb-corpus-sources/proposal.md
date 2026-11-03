# Proposal — extend-kb-corpus-sources

> Change `extend-kb-corpus-sources` (type: `feature`, scale 2) — criado em 2026-11-02 por Milton Antonio da Silva Jr.

## 1. Por quê (problema / motivação)

Ao ativar a camada semântica do `/forge:kb` no workspace Payments (upgrade para 0.19.0), confirmamos por leitura direta de `template/.forge/scripts/lib/kb-corpus.mjs` que o escopo de indexação é fixo e não configurável: `.forge/product/current/**` (baseline), `.forge/specs/archived/**` (nunca `active/`), `CHANGELOG.md`, `.forge/ledger/ledger.json` e mensagens próprias do liaison (`trust: self`). Não há chave em `forge.yaml`/`FORGE.md` para declarar fontes extras (`forge.schema.json` fixa `additionalProperties: false` em todo bloco).

Isso deixa dois gaps reais, medidos no Payments: (1) as 44 specs ATIVAS da raiz ficam fora do índice — exatamente o conteúdo mais recente e mais provável de ser consultado ("já decidimos isso antes?" sobre algo em andamento); (2) ADRs e runbooks reais do workspace vivem em `docs/adr/`, `docs/runbooks/` dentro de cada sub-repositório (`Payments.Platform`, `Payments.Deploy`, `Payments.Identity` etc., cada um com seu próprio `.forge/`), nunca em `.forge/product/current/adr/` — o mecanismo de ADR do próprio Forge não é o que esses times usam. O usuário pediu explicitamente que a base semântica cubra "todos os documentos de especificação, ADRs, runbooks etc." — o mecanismo atual não atende isso em nenhum workspace com essa topologia (specs ativas + documentação fora do baseline do Forge).

## 2. O que muda

- `kb-corpus.mjs` passa a indexar também `.forge/specs/active/**` (requirements/design/tasks/proposal em progresso), com o mesmo tratamento de tipo documental já usado para `archived-spec` (kind novo, ex.: `active-spec`). **Isto reverte deliberadamente REQ-FHT-072/SCN-FHT-072-A do baseline** (`.forge/product/current/capabilities/forge-harness-template/spec.yaml`), que hoje exige explicitamente que specs ativas NUNCA entrem no índice (decisão do change arquivado `add-unified-knowledge-search`, imposta por `tests/w309-kb-corpus-gate.sh`). A exclusão original agrupava "specs ativas" na mesma lista que "peer/blob/código/node_modules" — mas o motivo de segurança real dessa lista é só conteúdo de peer/liaison não confiável; specs ativas do PRÓPRIO projeto nunca foram um risco de procedência, só uma escolha de escopo da v1. Este change formaliza a reversão: `requirements.md` declara a substituição de REQ-FHT-072 (full replacement via `spec-delta.yaml` no archive), e `tests/w309-kb-corpus-gate.sh` é atualizado para refletir o novo comportamento (specs ativas indexadas e rotuladas; peer/blob/código/node_modules continuam fora, sem mudança nenhuma nessa parte).
- Uma fonte configurável nova e explícita (chave nova em `forge.yaml`, ex.: `kb.extra_paths: []`, lista de globs relativos à raiz do projeto) permite declarar diretórios adicionais a indexar — cobre o caso real `docs/adr/`, `docs/runbooks/` fora de `.forge/product/current`, sem exigir que o projeto mova esses arquivos para dentro da estrutura do Forge.
- `forge.schema.json` ganha a chave nova (mantendo `additionalProperties: false` nos demais blocos — só a chave declarada é aceita).
- `kb.sh status`/`kb.sh build` reportam quantos documentos vieram de cada fonte (baseline, archived-spec, active-spec, extra-path, changelog, ledger, liaison), para o gap de cobertura ficar visível em vez de silencioso.
- Documentação (`skills/.../forge:kb`, ou onde o comando descreve o escopo) atualizada para não afirmar implicitamente cobertura total — incluindo orientação explícita de que um fato/decisão/observação pontual, que não é documento formal, entra pelo caminho já existente `ledger-ops.sh add` (já indexado como `kind: 'ledger'`; avaliamos e descartamos criar um subcomando de ingestão novo — ver requirements.md, "Alternativa avaliada e descartada").
- **Documentação é dinâmica — o índice precisa acompanhar, não só descobrir.** ADRs recebem emendas e mudam de status (accepted → superseded/deprecated/rejected, convenção MADR); runbooks são atualizados com frequência. Duas extensões sobre o mecanismo já existente de `kb-corpus.mjs`/`kb-cli.mjs` (fingerprint por sha256 de conteúdo + `quickFingerprint` por stat, ambos hoje restritos às fontes atuais):
  1. `active-spec` e `extra-path` passam a participar dos mesmos enumeradores que já alimentam `fingerprint()`/`quickFingerprint()` (`collect()` e `sourceFiles()`) — sem isso, uma emenda num ADR indexado via `extra_paths` ou uma atualização num requirements.md de spec ativa não dispara reconstrução do índice, e `kb.sh query` serviria a versão velha como se fosse atual.
  2. O cabeçalho MADR (`- **Status:** <valor>`, já usado em `.forge/product/current/adr/*.md`) passa a ser extraído como metadado do documento e exibido como rótulo visível no resultado de `kb.sh query` quando o status não for mais vigente (`superseded`/`deprecated`/`rejected`) — sem alterar ranking/fusão (preserva as constantes calibradas do change `add-unified-knowledge-search`).

## 3. O que NÃO muda (fora de escopo)

- Não resolve a topologia multi-repositório do Payments (cada `Payments.*` com `.forge/` próprio) — isso é inerente ao workspace, não ao kb-corpus; quem quiser um índice único cross-repo roda `kb.sh build` em cada repositório separadamente (limitação conhecida, documentada, não corrigida aqui).
- Não adiciona nenhum mecanismo de rede/LLM à busca (a camada semântica já é local; isto não muda).
- Não altera o comportamento de segurança do liaison (mensagens de peer continuam nunca indexadas — `trust !== 'self'` ou com `authored_by` seguem excluídas, conforme `rules/conventions/liaison-untrusted-input.md`).
- Não migra ADRs/runbooks existentes para dentro de `.forge/product/current` — a fonte configurável os indexa onde já estão.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template` (mecanismo `/forge:kb`).
- **Paths afetados:** `template/.forge/scripts/lib/kb-corpus.mjs`, `template/.forge/scripts/lib/kb-cli.mjs` (saída de `status`/`build`/`query`, texto e `--json`, para reportar contagem por fonte e rótulo/campo de status MADR), `template/.forge/scripts/kb.sh`, `template/.forge/schemas/forge.schema.json`, documentação do comando/skill `forge:kb`. A allowlist de `extra_paths` (`.forge/kb-extra-paths-allowlist.txt`) é um arquivo de convenção no projeto consumidor, não no template.
- **Dependências:** nenhuma de outro change ativo.
- **Riscos:** (a) indexar specs ativas pode trazer ruído de rascunhos ainda incompletos — mitigar documentando que resultado de spec ativa é marcado como tal na resposta do `kb.sh query`, nunca misturado sem rótulo com baseline estável; (b) `extra_paths` mal configurado (glob amplo, ex. `**`) pode indexar segredo/dado sensível fora do controle do harness — mitigar reusando o mesmo padrão de allowlist com motivo obrigatório já usado em `.forge/empty-universe-allowlist.txt`/`.forge/suppression-scan-exclude.txt`, e aplicando o mesmo filtro de extensão (`.md`/`.yaml`/`.yml`) já usado para as fontes atuais.

## 5. Próximos passos

`/forge:requirements` → `/forge:design` → `/forge:tasks` → `/forge:implement` → `/forge:verify`. Autorizado pelo usuário a rodar em modo autônomo (`--yolo`) nos gates HITL, dado o contexto já levantado nesta mesma sessão ao diagnosticar o gap no Payments.
