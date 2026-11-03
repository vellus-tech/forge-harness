# Design — extend-kb-corpus-sources

> Design técnico do change `extend-kb-corpus-sources`.

## 1. Contexto e restrições

- Zero-dependency inegociável (ADR 0004/0005, NFR-01 deste change): nenhuma lib nova, só `node:*` e
  módulos do próprio harness (`yaml-lite.mjs`, `liaison-trust.mjs`, `untrusted-render.mjs`).
- `kb-corpus.mjs` é função pura sobre o filesystem (não grava nada) — `collect()`/`sourceFiles()`/
  `fingerprint()`/`quickFingerprint()` já existem e são genéricos sobre `docs[]`/arquivos; a
  extensão deste change é ADICIONAR fontes aos dois enumeradores, nunca criar mecanismo paralelo.
- `forge.schema.json` usa `additionalProperties: false` em todo bloco — convenção a preservar no
  bloco `kb` novo.
- Este change reverte deliberadamente REQ-FHT-072/SCN-FHT-072-A do baseline (specs ativas nunca
  indexadas) — supersessão formal via `spec-delta.yaml` no archive, não uma contradição silenciosa.
- Calibração existente de `kb-fuse.mjs` (RRF, pesos, re-rank) é um investimento caro (REQ-11 do
  change `add-unified-knowledge-search`, holdout versionado) — nenhuma decisão deste change pode
  alterar ranking/fusão sem reabrir essa calibração. Isso elimina qualquer alternativa que reordene
  resultados por status/kind.

## 2. Decisão técnica

### 2.1 `active-spec` — mesma função, root nova (REQ-01)

Em `kb-corpus.mjs::collect()`, imediatamente após a linha de `archived-spec`:

```js
for (const f of walk(join(docRoot, '.forge/specs/archived'), ['.md', '.yaml', '.yml'])) addFile('archived-spec', docRoot, f);
for (const f of walk(join(docRoot, '.forge/specs/active'), ['.md', '.yaml', '.yml'])) addFile('active-spec', docRoot, f);
```

E simetricamente em `sourceFiles()` (mesmo array `files`), para que `quickFingerprint()` enumere os
mesmos arquivos (REQ-06). Nenhuma outra função muda — `chunk()` já trata qualquer `kind !== 'ledger'
&& kind !== 'liaison'` como markdown/yaml por extensão, `active-spec` cai no mesmo ramo que
`archived-spec` hoje.

### 2.2 `extra_paths` — leitura de config + allowlist + glob mínimo (REQ-02, REQ-03)

**Leitura de config:** nova função `readExtraPaths(docRoot)` em `kb-corpus.mjs`, reusando
`parseYamlSubset` (já importado): lê `<docRoot>/.forge/forge.yaml` (caminho correto, confirmado em
`budget-preflight.mjs:56` e `validate-rules.mjs:38` — **não** `<docRoot>/forge.yaml`, achado do
`yolo-gate` na rodada 1 de `design_reviewed`) se existir, extrai `kb.extra_paths` (array de
string); ausência de arquivo ou de chave → `[]` (retrocompatibilidade, critério 1 do REQ-02).

**Sintaxe de glob suportada — UMA definição só, deliberadamente mínima, não um glob engine
(achado da iteração 1 do `yolo-gate`: havia duas definições divergentes entre esta seção e o
schema — corrigido para uma única fonte de verdade, citada aqui e replicada ipsis verbis na
descrição do schema em §2.2 "Schema"):**

```
^[^*?{}]+/\*\*(?:/\*\.(?:md|yaml|yml))?$
```

— prefixo sem caractere especial de glob, seguido de `/**` e, opcionalmente,
`/*.(md|yaml|yml)` (ex.: `docs/adr/**`, `docs/runbooks/**`, `docs/adr/**/*.md` — este último
exigido pelo critério 5 do REQ-02). **A extensão em `/**/*.<ext>` é restrita à MESMA lista
`md|yaml|yml` das demais fontes — nunca uma extensão arbitrária** (achado da iteração 2: a
primeira correção aceitava `*.<qualquer coisa>`, o que teria permitido `*.pem`/`*.env`/`*.jsonl`,
violando REQ-02 e o risco (b) da proposal). `/**` (sem sufixo) e `/**/*.<ext>` resolvem para a
MESMA chamada de `walk()` já existente, variando só o array de extensões — sem reimplementar um
matcher de glob completo.

**Causa raiz da rodada 3 (escalada ao humano, decisão registrada): checagem sobre o TEXTO do
config, não sobre o caminho FÍSICO resolvido.** As regras da rodada 2 (segmento `.`/`..`, prefixo
`.forge`/`.forge/*`, confinamento por `relative()`) todas liam o texto declarado em
`kb.extra_paths` ou o caminho obtido por `join(docRoot, prefix)` — nunca o caminho depois de
resolver symlink. Um symlink commitado (`docs/lnk → .forge/liaison`, ou `docs/root → ..`) atravessa
as duas pontas sem contradição nenhuma entre elas: o texto declarado (`docs/lnk/**`) passa a regra
de prefixo, e o `join()` ingênuo também "começa por `docRoot`" — porque nenhum dos dois nunca olhou
para onde o symlink realmente aponta. Em macOS (filesystem case-insensitive), `.FORGE/liaison/**`
é o mesmo furo por outra porta textual. **Esta é a mesma regra de ouro já aplicada nesta sessão a
SEC-001 (traversal por symlink no hub do liaison) e NODE-201 (`import --from` seguindo symlink de
blob): validação de confinamento de path sempre sobre o caminho FÍSICO resolvido, nunca sobre o
texto declarado.** Correção, substituindo TODA a lógica de prefixo da rodada 2 por uma sequência
única que resolve antes de validar:

1. **Sintaxe do texto declarado — grafia E as duas regras textuais que a troca para checagem
   física não pode descartar (achado do `yolo-gate`, série nova, aprovação com notas de
   convergência que NÃO reabrem o ciclo, mas são obrigatórias nas tasks):**
   `^[^*?{}]+/\*\*(?:/\*\.(?:md|yaml|yml))?$`, **E** nenhum segmento do prefixo é `.`/`..`, **E** o
   prefixo não começa por `/` (absoluto). Estas duas últimas continuam necessárias mesmo com a
   resolução física da etapa 2 — medido na implementação de referência do gate: sem elas,
   `/etc/**` resolve para `join(docRoot, '/etc')` que o Node trata como `docRoot/etc` (válido!) em
   vez de rejeitar por sintaxe, e `docs/../docs/adr/**` passa a etapa 1 anterior e só seria pego
   por acidente na etapa 3. A checagem textual (etapa 1) e a física (etapas 2-3) são CAMADAS
   complementares, não uma substituindo a outra — uma rejeita pela forma do texto, a outra pelo
   destino físico; um glob pode ser sintaticamente limpo e ainda escapar via symlink (por isso a
   etapa 2-3 existe), e pode ser sintaticamente sujo sem envolver symlink nenhum (por isso a etapa
   1 continua).
2. **Resolução física, SEMPRE depois da etapa 1 e antes de qualquer regra de segurança adicional:**
   `realDocRoot = realpathSync.native(docRoot)`; para o prefixo, caminha pelos segmentos a partir de
   `docRoot` resolvendo o MAIOR ancestral existente com `realpathSync.native`, parando e tratando
   como "ainda não existe" **somente** quando o erro é `ENOENT` (qualquer outro erro —
   `EACCES`/`ELOOP`/erro de dispositivo — é falha real e vira `skip('extra-path')` com o motivo do
   erro, nunca tratado como "ainda não existe"); concatena os segmentos restantes (inexistentes,
   só no caso `ENOENT`) sem resolver. `realpathSync.native` (não a variante JS) é obrigatório — é o
   que devolve a grafia canônica do disco, fechando o caso de maiúsculas do macOS como efeito
   colateral de usar a MESMA função dos dois lados da comparação, não como regra textual separada.
   **A varredura (`walk()`) parte exatamente deste caminho validado/resolvido** — nunca de um
   `path.resolve`/`join` recalculado sobre o texto cru depois da validação (evita que uma segunda
   resolução, feita de outro jeito, reabra a mesma lacuna de divergência texto-vs-físico que
   motivou esta correção).
3. **Todas as regras de segurança adicionais passam a operar sobre o caminho resolvido da etapa 2,
   nunca sobre o texto de `kb.extra_paths`:**
   - `rel = relative(realDocRoot, realResolvido)`; vazio, começando por `..`, ou absoluto →
     rejeita (fecha `docRoot-x` da rodada 2 E `docs/root → ..` desta rodada, pela mesma checagem).
   - `rel.split(sep)[0] === '.forge'` → rejeita (fecha `.forge/liaison` direto E via symlink —
     mesma checagem, porque agora opera sobre o caminho já resolvido).
   - `rel` igual a, **ancestral de, OU DESCENDENTE de** qualquer raiz já coletada por outro `kind`
     (`.forge/product/current`, `.forge/specs/archived`, `.forge/specs/active`, `.forge/ledger`,
     `.forge/liaison`, `.forge/kb`, `docs/plans`) → rejeita. "Descendente" é o reforço pedido pelo
     gate: `docs/plans/sub/**` (dentro de uma raiz já coletada) também duplicaria documento sob dois
     `kind` — mesma checagem de `relative()` nos dois sentidos (nem `rel` nem a raiz coletada podem
     começar um pelo outro depois de split por segmento), sem custo adicional de implementação.
4. **Allowlist:** `.forge/kb-extra-paths-allowlist.txt` no `docRoot`, comparada pelo TEXTO
   declarado em `kb.extra_paths` (a allowlist é sobre a intenção configurada, não sobre o caminho
   físico — isso é correto porque a resolução física já aconteceu nas etapas 2-3 antes de chegar
   aqui; a allowlist nunca é a única linha de defesa contra escape de symlink). Mesmo
   formato/parser do PADRÃO já usado em `gate-universe.mjs::universeWaiver` (reaproveita o padrão
   de linha `<glob>  # motivo: <texto>`, não o código — ver nota de acoplamento abaixo). Entrada
   ausente ou sem `# motivo:` → glob ignorado, nunca indexado.

Cada falha em qualquer etapa gera `skip('extra-path')` com aviso em stderr (nunca lança).
`tests/w309-kb-corpus-gate.sh` ganha, no mínimo, estes casos negativos — cada um com o glob de
config E a entrada de allowlist exatos, para eliminar a ambiguidade apontada em rodadas anteriores:
- `./**`, `/etc/**` (absoluto), `docs/../docs/adr/**` (segmento `..`), `.forge/**`,
  `.forge/liaison/**` — todos como texto declarado direto, sem symlink envolvido (prova da etapa
  1, sintaxe).
- Symlink commitado `docs/lnk-liaison → ../.forge/liaison`, com `docs/lnk-liaison/**` declarado em
  `kb.extra_paths` E a mesma string `docs/lnk-liaison/**` na allowlist com `# motivo:` — prova de
  que a resolução física (etapas 2-3) rejeita o que a checagem textual sozinha deixaria passar.
- Symlink commitado `docs/lnk-root → ..` (caminho relativo resultante vazio), mesmo padrão de
  config+allowlist que o caso anterior.
- Symlink INTERNO a um diretório já aceito: `docs/adr/` existe de verdade (allowlisted,
  `docs/adr/**`), mas contém um arquivo `docs/adr/lnk-liaison.md` que é na verdade um symlink para
  um arquivo dentro de `.forge/liaison` — prova de que `walk()` (confirmado em
  `kb-corpus.mjs:29-38`) não segue symlink de ARQUIVO interno, só a pasta de partida é resolvida
  pela etapa 2 (achado de reprodução do `yolo-gate`, série nova).
- `docs/plans/sub/**` (subpasta de uma raiz já coletada, `docs/plans`) e um symlink
  `docs/lnk-plans → docs/plans` com `docs/lnk-plans/**` — prova de que a checagem de overlap
  rejeita também o caso "descendente", não só igualdade/ancestral.
- Maiúsculas no macOS: fixture que cria o diretório físico com grafia `.forge` (minúscula, como
  sempre) e declara o glob em `kb.extra_paths` com grafia `.FORGE/liaison/**` — em filesystem
  case-insensitive (macOS padrão, CI local) a etapa 2 resolve as duas grafias para o mesmo
  `realpathSync.native`, provando a rejeição; em filesystem case-sensitive (Linux CI), o mesmo
  glob simplesmente não encontra `.FORGE` (`ENOENT`) e cai no mesmo `skip` — o teste permanece
  determinístico nos dois ambientes porque a asserção é "nunca indexado", não "rejeitado pela
  regra X especificamente".
- Casos positivos de controle (precisam continuar passando): `docs/adr/**`, `docs/adr/**/*.md`.

Resultado: `docs: [...]` com `kind: 'extra-path'`, mesmos `addFile()`/`walk()`. Em `sourceFiles()`,
mesma leitura+validação (função compartilhada `resolveExtraPathDirs(docRoot)` chamada por ambas,
para não duplicar a lógica de validação entre `collect()` e `sourceFiles()` — duplicá-la seria o
mesmo erro de origem do gap de REQ-06, risco de uma rota enumerar e a outra não).

**Nota de acoplamento (sem mudança):** `gate-universe.mjs::universeWaiver` continua fora de reuso
direto — acoplado a `root`/`gate`/semântica de gate, usado por `check-authz.mjs`/
`check-observability.mjs`/`check-data-governance.mjs` em produção; `kb-corpus.mjs` implementa seu
próprio parser de 3 linhas no mesmo formato, por consistência visual, não por import cruzado
(decisão inalterada desde a versão original desta seção).

**Schema (`forge.schema.json`, REQ-03):** bloco novo em `forgeManifest`:

```json
"kb": {
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "extra_paths": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Globs extras indexados por /forge:kb, formato <prefixo>/** ou <prefixo>/**/*.<md|yaml|yml> (prefixo sem caractere de glob, sem segmento '.'/'..' , fora de .forge/), cada um exigindo entrada em .forge/kb-extra-paths-allowlist.txt com # motivo:."
    }
  }
}
```

### 2.3 Contagem por fonte em `status`/`build` (REQ-04)

**Função compartilhada `countKinds(docs, extraPathsConfigured)`** (nova, em `kb-cli.mjs`): computa
`kinds[d.kind]++` sobre qualquer lista de docs (`{ id, kind }` basta) e força
`kinds['extra-path'] = kinds['extra-path'] || 0` quando `extraPathsConfigured` (resultado de
`readExtraPaths`) não está vazio — usada pelos DOIS comandos abaixo, para não repetir a lógica do
`extra-path=0` em dois lugares (um deles ficando desatualizado é exatamente o tipo de gap que
REQ-06 já existe para evitar, agora na contagem, não no fingerprint).

- **`cmdStatus`** (`kb-cli.mjs:233`) já constrói `kinds` a partir de `docs[]` — passa a chamar
  `countKinds(docs, readExtraPaths(a.docRoot))` em vez do loop inline.
- **`cmdBuild` NÃO reporta por fonte hoje — achado confirmado do `yolo-gate` rodada 1.** O código
  real (`kb-cli.mjs:215-219`) só imprime `${idx.docs.length} documentos` (total) e, se houver,
  `pulados: ${sk}` — nunca uma contagem por `kind`. Mudança: `cmdBuild` passa a chamar
  `countKinds(idx.docs, readExtraPaths(a.docRoot))` (sobre `idx.docs`, que já tem `kind` propagado —
  ver §2.4) e anexar o resultado à linha de saída, ex.: `OK índice lexical: N documentos
  (baseline=X active-spec=Y extra-path=Z ...), M trechos (...)` — mesmo formato `chave=valor` já
  usado para `skipped`, por consistência visual.

### 2.4 Status MADR + `kind` de origem no resultado de busca (REQ-07, REQ-01 último critério)

**Extração:** nova função pura `madrStatus(text)` em `kb-corpus.mjs` — regex
`/^-?\s*\*\*Status:\*\*\s*(\S+)/mi` (captura só o PRIMEIRO termo após "Status:", não a linha
inteira — achado confirmado do `yolo-gate` rodada 1: valores reais trazem sufixo, ex.: ADR 0004
deste próprio repositório tem `- **Status:** accepted — gate \`design_reviewed\` aprovado...`, e a
convenção MADR usa `Superseded by [ADR-0012]`; comparar a linha inteira por igualdade nunca
casaria "superseded"/"accepted" como palavra isolada) nas primeiras ~20 linhas do texto. O termo
capturado tem pontuação final removida (`.replace(/[.,;:]+$/, '')` — achado da iteração 2:
"superseded," com vírgula colada não bateria no mapeamento) antes de normalizar para minúsculas e
mapear variantes PT-BR conhecidas (`aceito`→`accepted`, `suplantado|substituído`→`superseded`,
`depreciado`→`deprecated`, `rejeitado`→`rejected`); retorna `null` quando não casa. Chamada em
`addFile()` só quando `kind` é
`baseline`/`active-spec`/`extra-path` (as três fontes que podem conter ADR) e o `id` contém `/adr/`
(evita custo de regex em todo documento não-ADR); resultado vai no doc:
`{ id, kind, text, sha256, madr_status }` (`madr_status: null` quando não aplica — compatível com
documentos existentes, campo novo opcional).

**Propagação — decisão fechada, confirmada por leitura do código:** `kb-lexical.mjs::buildIndex`
(linha 113) hoje mapeia explicitamente só três campos por documento:
`docs: docs.map((d) => ({ id: d.id, kind: d.kind, sha256: d.sha256 }))` — ou seja, `kind` já
propaga (sem mudança para REQ-01), mas `madr_status` NÃO propaga hoje e precisa ser adicionado a
esse mapeamento: `({ id: d.id, kind: d.kind, sha256: d.sha256, madr_status: d.madr_status ?? null })`.
Nenhuma mudança em `kb-fuse.mjs` (fusão/ranking intocados, decisão da seção 3).

**Bump de `INDEX_FORMAT` (achado confirmado do `yolo-gate` rodada 1).** `INDEX_FORMAT` hoje é `3`
(`kb-lexical.mjs:17`). Um índice serializado ANTES deste change (sem `madr_status` em nenhum doc)
continua batendo com `idx.format === INDEX_FORMAT` e com `quickFingerprint`/`fingerprint` (que
comparam `(id, sha256)` de conteúdo, não o shape do índice) — `indexState()` o classificaria como
`atual`, e os rótulos do REQ-07 só apareceriam depois que ALGUMA fonte mudasse e disparasse
reconstrução, nunca retroativamente num projeto já indexado. Correção: `INDEX_FORMAT` sobe para
`4`. Isso já é o mecanismo existente de invalidação por formato (`indexState()` trata
`idx.format !== INDEX_FORMAT` como `'defasado'`) — reconstrução automática de todo índice antigo no
próximo `kb.sh build`/`query`, sem lógica nova de migração.

**Exibição em `kb-cli.mjs`:** o resultado de busca hoje só traz o `doc` (id) por item — `search()`
precisa buscar `kind`/`madr_status` no índice por esse id (`idx.docs.find((d) => d.id === r.doc)`,
ou um `Map` pré-computado para evitar O(n²) quando `idx.docs` crescer) antes de montar cada
resultado. Campo JSON **fixado como `status`** (não `madr_status` — nome único, consistente com o
REQ-07 tal como escrito; `madr_status` é só o nome interno do doc/índice). `printText()`/`cmdQuery`
passam a incluir, por resultado, `kind` (sempre) e `status` (quando não-null). Rótulo visível em
texto: prefixo `[SUPERSEDED] `/`[DEPRECATED] `/`[REJECTED] ` antes do `doc` quando `status` ∈
{superseded, deprecated, rejected} — `accepted`/`proposed`/outros valores não reconhecidos não
geram rótulo (comportamento atual preservado). Em `--json`, o campo `status` é sempre emitido
quando presente, nunca só embutido em string livre — consumidor automatizado não faz parsing de
rótulo.

## 3. Alternativas consideradas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Filtrar/ocultar ADR superseded do resultado por default | Resposta "mais limpa" | Esconde fato histórico relevante ("já decidimos isso antes, e depois mudamos" é informação útil); muda contrato de `kb.sh query` (menos resultados) sem flag explícita | Descartada — rótulo visível preserva recall e deixa a decisão de ignorar com quem lê o resultado (REQ-07, decisão fixada nos requirements) |
| Reordenar ranking para penalizar status não-vigente (ex.: multiplicador no RRF) | Resultado "mais útil" top-N | Reabre a calibração cara de `kb-fuse.mjs` (holdout/constantes do REQ-11 anterior); risco de regressão sem novo ciclo de medição, fora do orçamento de um change scale 2 | Descartada — risco/custo desproporcional ao ganho; rótulo visível sem reordenar é suficiente para o REQ |
| Glob engine completo (minimatch-like) para `extra_paths` | Mais flexível (`*.md`, `{a,b}`, negação) | Nova dependência OU reimplementação não-trivial zero-dep; superfície de validação de segurança muito maior (muitos jeitos de escapar `docRoot`) | Descartada — sintaxe mínima `<prefixo>/**` cobre o caso real (Payments) com validação simples e auditável |
| Subcomando novo `kb.sh note add` para fato/decisão ad-hoc | Resposta direta ao pedido do usuário | Segunda trilha de auditoria paralela ao ledger (mesmo propósito); exigiria validação de segurança própria (trust, segredo em texto livre) do zero | Descartada — `ledger-ops.sh add --type follow-up` já resolve, já indexado, já auditável (ver requirements.md) |
| Reimplementar o parser de allowlist chamando `gate-universe.mjs::universeWaiver` | Reuso de código, uma fonte de verdade | `universeWaiver` é parametrizado por `gate`/`root` com semântica de "chave == nome de gate"; adaptar para "chave == glob" exigiria mudar a assinatura de um módulo usado por `authz`/`observability`/`data-governance` já em produção, risco fora de escopo | Descartada — reuso do PADRÃO (formato de linha, exigência de `# motivo:`), parser próprio de 3 linhas em `kb-corpus.mjs` |

## 4. Contratos e integrações afetados

- `kb.sh query --json`: ganha campos novos por resultado (`kind`, `status` opcional) — aditivo,
  não remove nem renomeia campo existente; consumidor atual que ignora campos desconhecidos não
  quebra.
- `kb.sh status --json`: `kinds` pode conter `active-spec`/`extra-path` — mesmo contrato aditivo.
- `forge.schema.json`: bloco `kb` é opcional (ausência = comportamento atual); projeto que já
  valida `forge.yaml` contra o schema antigo sem `kb` continua válido.
- `spec-delta.yaml` deste change (autorado no `/forge:tasks`/preenchido até o `/forge:archive`):
  `modify_requirement` full-replacement de REQ-FHT-072 — o `verification.md` precisa confirmar que
  o texto novo do REQ cobre exatamente o comportamento implementado antes do archive.

## 5. Plano de migração / rollout

Sem migração de dado — mudança é só no corpus builder/CLI/schema. `kb.sh build` já reconstrói
automaticamente quando o fingerprint diverge (mecanismo existente); nenhum projeto consumidor
precisa de ação manual além de, opcionalmente, declarar `kb.extra_paths` + a allowlist se quiser
usar a fonte nova. `active-spec` passa a ser indexado automaticamente no próximo `kb.sh build` de
qualquer projeto já usando `/forge:kb` — comportamento novo sem flag, documentado em REQ-05.
Adicionalmente, o bump de `INDEX_FORMAT` (3→4, §2.4) força exatamente UMA reconstrução completa do
índice lexical no primeiro `kb.sh build`/`query` depois do upgrade do harness, em qualquer projeto
— mesmo sem `active-spec`/`extra_paths` configurados — para que os rótulos de status MADR (REQ-07)
passem a existir mesmo sobre o corpus já indexado hoje, não só sobre fontes que mudarem depois.
Custo: um rebuild completo (segundos a poucos minutos, dependendo do corpus), uma única vez.

## 6. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação / detecção |
|---|---|---|---|
| `extra_paths` indexa segredo fora do controle do harness | Baixa (exige glob + allowlist deliberados) | Alto (dado sensível em texto buscável) | Allowlist com `# motivo:` obrigatório + confinamento a `docRoot` + filtro de extensão `.md`/`.yaml`/`.yml` (não `.env`/`.pem`/etc.) |
| Ruído de rascunho de spec ativa incompleta no resultado | Média (specs ativas mudam rápido) | Baixo (rotulado, não escondido) | Rótulo `kind: active-spec` sempre visível no resultado (REQ-01/REQ-07) |
| Regex de `madrStatus` casa falso positivo em documento não-ADR com uma linha parecida | Baixa | Baixo (rótulo espúrio) | Regex só aplicada a `id` contendo `/adr/`, dentro das ~20 primeiras linhas |
| `w309` desatualizado quebra silenciosamente outro change que dependa do comportamento antigo | Baixa (só este change toca REQ-FHT-072) | Médio | `spec-delta.yaml` formaliza a supersessão; `CHANGELOG.md` registra a reversão no archive |
| Symlink commitado em `extra_paths` escapa `docRoot` ou aponta para `.forge/liaison` (conteúdo de peer) por checagem textual não notar o alvo físico — achado real da rodada 3 de `design_reviewed`, reproduzido pelo gate | Baixa (exige symlink deliberado + config + allowlist) | Alto (vazamento de conteúdo de peer/liaison no índice, violação da regra "nunca indexa peer") | Toda regra de confinamento/exclusão passa a operar sobre o caminho resolvido via `realpathSync.native` (mesmo padrão de SEC-001/NODE-201 desta sessão), nunca sobre o texto declarado — §2.2 etapas 2-3; `w309` ganha caso de symlink commitado como prova |

## 7. Rastreabilidade

| REQ | Seção do design que o atende |
|---|---|
| REQ-01 | §2.1, §2.4 (rótulo de kind) |
| REQ-02 | §2.2 |
| REQ-03 | §2.2 (schema) |
| REQ-04 | §2.3 |
| REQ-05 | documentação (fora do código — TASK dedicada, sem seção de design própria: é edição de prosa) |
| REQ-06 | §2.1, §2.2 (ambas as fontes somadas a `sourceFiles()`) |
| REQ-07 | §2.4 |
| NFR-01 (zero rede) | §1 (zero-dep inegociável) — nenhuma decisão de §2 importa módulo fora de `node:*`/harness: `readExtraPaths`/parser de allowlist são leitura de arquivo local (`readFileSync`), `madrStatus` é regex pura; `w313`/`w318` já iteram `lib/kb-*.mjs` por glob (confirmado por leitura, não lista fixa), então cobrem o código novo SEM edição — método de medição é reexecutar os dois, não modificá-los (manifest.yaml não lista esses arquivos em `affected_paths` por isso) |
| NFR-02 (custo proporcional de build) | §2.1/§2.2 — custo adicional é O(arquivos novos): um `walk()` extra por `extra_paths` configurado (tipicamente 0-3 diretórios) e um `walk()` fixo para `active-spec`; `madrStatus()` só roda sobre documentos cujo `id` contém `/adr/`, não sobre o corpus inteiro — nenhuma decisão itera o corpus mais de uma vez por fonte; medição em `time kb.sh build` antes/depois registrada em `verification.md`, sem meta numérica rígida (conforme NFR-02) |
