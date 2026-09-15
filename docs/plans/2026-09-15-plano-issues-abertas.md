# Plano de correção — as 36 issues abertas do forge-harness (rodada R02)

> Data: 2026-09-15 · Base: `origin/develop` @ `821178e` (0.15.0) · Universo: `gh issue list --state open` (36 issues, #101–#153) e as 26 entradas não encerradas de `.forge/ledger/ledger.json`.
> Progresso medido por `node tools/plan-progress.mjs --plan docs/plans/2026-09-15-plano-issues-abertas.md`, nunca por marcação manual neste documento.

## Sumário executivo

As 36 issues abertas reproduzem, total ou parcialmente, em `821178e`; nenhuma está inteiramente corrigida. Todos os vermelhos citados abaixo foram executados contra `821178e` nos clones `/tmp/fh-tri-A` e `/tmp/fh-tri-B` em 2026-09-15, e as linhas coladas são saída real dessas execuções. As bancadas ficaram em `/tmp/fh-R02-*.sh` e `/tmp/fh-A-*.sh` (efêmeras); o comando essencial de cada vermelho está escrito na seção da issue para ser reconstruído no PR.

A ordenação é por dano a terceiros, decisão do dono: a Onda 1 cobre o que o `forge update` e o gerador de adapters desarmam ou apagam na árvore de quem instalou o harness; a Onda 2, as ferramentas que destroem trabalho do consumidor com rc 0; a Onda 3, o que trava o trabalho dele (mutex, pre-push, hooksPath, doctor); a Onda 4, o que passa verde sem medir; a Onda 5, prosa, contrato de agente e interface. A Onda 6 lista, sem implementar, as 26 entradas de ledger não encerradas.

Planos anteriores foram usados como insumo, não como base: os spikes `docs/plans/spikes/backlog-onda-l1..l6-*.md` têm decisões fechadas que reaproveito onde ainda valem, e cada seção diz o que foi reaproveitado e o que mudou. A mudança mais importante em relação a eles é o critério de decisão do dono: onde o spike escolheu o comportamento mais forte (parar o update, recuperar posse de dono vivo por padrão, recusar regeneração), este plano implementa o default conservador retrocompatível e deixa a promoção como pergunta explícita ao dono dentro da seção.

## Invariantes de execução

Vermelho antes do verde: o implementador escreve o gate inteiro, executa-o contra a base do PR, cola a falha no corpo do PR e só então toca a produção. Um vermelho que já passa no estado defeituoso reprova o PR.

Asserção negativa nunca sozinha: todo "não produz X" vem pareado com uma asserção positiva observável que só existe depois da correção, no mesmo cenário.

Prova de mutação com controle e recontrole: a mutação é aplicada, o gate é observado falhando no cenário nomeado, o arquivo é restaurado byte a byte (`cmp -s`) e o gate volta a passar. Mutação por `perl` com aspas simples, nunca com `$` do lado direito interpolado (LDG-0164).

Ordinais `wNNN` são reservados pelo orquestrador (tabela abaixo, coluna vazia). Todo PR que cria gate atualiza o badge `gates-N` do README na mesma mudança (w200). Todo PR que toca `template/.forge/commands/` roda `npm run build:plugin`. Um PR por issue, salvo causa raiz comum provada por arquivo:linha na seção; `Closes #N` só no PR que fecha título e corpo inteiros.

## Onda 1 — o update e o gerador desarmam ou apagam o que o consumidor instalou

### #101 e #131 — o overlay sobrescreve maquinaria local e ignora exceções declaradas (um PR)

**#101** · **#131** · Closes #101 · Closes #131 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: as duas passam pelo mesmo ramo de `bin/forge.mjs`. `:352` define `ENRICHABLE_DIRS = ['agents','rules','skills','templates']`; `:623` só preserva quando `isEnrichable(rel)`; `:630` só avisa (`driftWarned.push`) quando existe `machinery.lock`, que o `init` não cria; `:633` faz `cpSync(srcAbs, dst)` incondicional para `scripts/` e `hooks/`. Nenhuma linha do updater lê `.forge/machinery-exceptions.txt` (`grep -rn machinery-exceptions bin` vazio). A #101 é o sintoma sem declaração, a #131 é o sintoma com declaração, e as duas correções editam as mesmas linhas 620–640 — separá-las garantiria conflito.

Desenho, reaproveitando L1 D2 e D3 com um desvio: `.forge/machinery-exceptions.txt` vira contrato do template no formato que o axis-fare-validator já opera (`<sha256 do template na declaração>  <caminho relativo a .forge/>  # razão`). Exceção viva (sha declarado igual ao sha do template novo) preserva o arquivo e o nomeia com a razão. Exceção ociosa (caminho fora do template, ou arquivo local idêntico ao template) é reportada sem efeito. Arquivo ilegível, linha malformada ou duas declarações do mesmo caminho param o update antes de escrever qualquer arquivo, nomeando a linha. Toda sobrescrita de arquivo que divergia do template novo, com ou sem lock, imprime uma linha por arquivo (`SOBRESCRITO (não declarado): <rel> — conteúdo anterior em <backup real>`). O desvio em relação a L1 D3: exceção expirada (sha declarado diferente do template novo) não para o update; preserva o arquivo e imprime `EXCEÇÃO EXPIRADA: <rel>` com os dois shas, rc 0. Parar seria rc novo na fronteira publicada do `update`.

Alternativa descartada: pôr `scripts`/`hooks` em `ENRICHABLE_DIRS` ou criar `PRESERVED_ON_DRIFT_DIRS` sem declaração. L1 D1 mediu congelamento: sem lock, o fallback preserva quem só estava defasado e a correção do template nunca chega (linhas com JWT depois do update = 0 contra 2 no recontrole).

Perguntas ao dono: (1) exceção expirada deve parar o update com rc próprio, como L1 D3 decidiu? (2) adotar preservação por deriva decidida por lock para `scripts/` (Onda C, `PRESERVED_ON_DRIFT_DIRS`) como default, aceitando o risco de congelamento medido?

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): `node bin/forge.mjs init --target $C -y --no-plugin`; anexar `# CONSERTO-LOCAL` a `.forge/scripts/lib/transports/_common.sh`; declarar a exceção com o sha do template; `node bin/forge.mjs update --target $C --no-backup --no-plugin`; esperado depois da correção: conserto presente e o caminho nomeado no stdout. Hoje:

```
  ANTES: hook stdin rc=2 settings=1 conserto=1
  update rc=0
  linhas do update citando _common.sh/exceptions/prevent-secrets: 0
  DEPOIS: hook stdin rc=0 settings=0 conserto=0
```

Gate que fica: `tests/w<NNN>-update-exceptions-gate.sh`, com cenários: viva preserva e nomeia (positiva: linha `PRESERVADO (exceção declarada)` presente e sha local intacto); não declarada sobrescreve e nomeia com caminho de backup existente; expirada preserva e nomeia; malformada e duplicada param com arquivo nenhum escrito (positiva: a linha da recusa nomeia o número da linha); ausência do arquivo não imprime nada novo além das linhas `SOBRESCRITO`. Revalidar w63, w101, w153 e w161, que executam o updater.

Propriedade PBT: para arquivos de exceção gerados (mistura aleatória de linhas vivas, expiradas, ociosas, malformadas e duplicadas sobre caminhos reais do template), o desfecho é uma função pura do conjunto: o update para se e somente se existe linha malformada ou duplicada; quando não para, cada arquivo local fica byte-idêntico se e somente se tem exceção viva ou expirada, e todo caminho declarado aparece exatamente uma vez no relatório.

Mutação: remover a chamada ao leitor de exceções no laço (a condição que antecede `:633`) faz o cenário "viva preserva" falhar com o sha local trocado; remover o `console.log` da linha `SOBRESCRITO` faz o cenário não declarado falhar pela contagem de linhas.

Arquivos: `bin/forge.mjs`, `template/.forge/machinery-exceptions.txt` (cabeçalho documentado, sem linhas), `template/.forge/commands/harness/upgrade.md` (+ espelho do plugin), gate novo, README, CHANGELOG.

### #125 — o detector de segredos nunca chega armado e o update desarma quem o armou

**#125** · Closes #125 · gate novo: sim · depende do PR de #101/#131 e do PR de #130

Causa raiz: três defeitos independentes. (1) `hooks/` cai no `cpSync` de `bin/forge.mjs:633` — fechado pelo PR de #101/#131, que torna a sobrescrita nominal e a exceção honrada; por isso este PR usa `Refs` para essa metade e só fecha a issue ao fim. (2) `template/.forge/scripts/lib/sync-adapters.mjs:233` monta `PreToolUse` com um único gancho literal (`enforce-worktree-location.sh`), então todo `sync` apaga a fiação armada à mão. (3) `template/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh:8-13` lê `$1`/`$2` e sai 0 com argv vazio, e o Claude Code entrega o payload por stdin: mesmo registrado, o gancho aprova.

Desenho, reaproveitando L1 D4, D4.5 e D5: a fiação `PreToolUse` passa a derivar do diretório `hooks/pre-tool-use/` (profundidade 1) com matcher e contrato vindos de `hooks.manifest.default` distribuído, lido pelo leitor canônico que já existe em `template/.forge/scripts/lib/hooks-manifest.mjs` (coberto por w208). Manifesto do consumidor em esquema não marcado resolve pelo mesmo leitor; esquema não reconhecido deixa o `settings.json` anterior byte-idêntico e nomeia LDG-0178. O semeador do `update` deriva ativação do que já está fiado: gancho hoje fiado nasce ativo, gancho não fiado nasce inativo e nomeado — nenhum consumidor ganha bloqueio novo sem saber. O gancho de segredos passa a ler o JSON de stdin quando argv vem vazio, bloqueia com exit 2 e é fail-closed com stdin vazio, como o Axis.PadSimulator mediu; os ganchos `argv` restantes recebem uma ponte em `hooks/pre-tool-use/lib/`.

Alternativa descartada: pôr a lista no `forge.yaml` (item 2 da issue). O merge do `forge.yaml` é por chave de topo ausente (`bin/forge.mjs:447-460`), então sub-chave nova nunca chega a quem já tem a chave. Descartada também a ativação de todos os ganchos no update: introduziria bloqueio não anunciado em consumidores que nunca armaram.

Pergunta ao dono: o esquema canônico da camada do consumidor (LDG-0178, dois esquemas de campo incompatíveis) — até decidir, a ativação por sobreposição do consumidor não é lida além do que w208 já lê.

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`), em duas partes. Sem armar nada: `printf '<payload Write com AKIAIOSFODNN7EXAMPLE>' | bash .forge/hooks/pre-tool-use/prevent-secrets-leak.sh; echo rc=$?` e `grep -c prevent-secrets-leak .claude/settings.json`; esperado rc 2 e contagem ≥1. Armado e depois `update`: esperado rc 2 e contagem ≥1 depois. Hoje:

```
  stdin rc=0
  settings.json registra prevent-secrets-leak? 0
  DEPOIS: hook stdin rc=0 settings=0 conserto=0
```

Gate que fica: `tests/w<NNN>-hook-wiring-derived-gate.sh`. Revalidar w12, w14, w62, w63, w153 e w208, que executam o gerador.

Propriedade PBT: para diretórios `pre-tool-use/` gerados (subconjuntos aleatórios de ganchos declarados, ativos e inativos, mais um arquivo não declarado), o conjunto de comandos emitidos em `PreToolUse` é igual ao conjunto de ganchos declarados ativos; arquivo não declarado reprova nomeando o arquivo; e para payloads gerados contendo um dos padrões de segredo em posição aleatória do `content`, o gancho via stdin sai 2.

Mutação: trocar a derivação pelo literal de `:233` faz o cenário de igualdade de conjunto falhar nomeando `prevent-secrets-leak.sh`; remover a leitura de stdin no gancho faz o cenário de payload sair rc 0.

Arquivos: `template/.forge/scripts/lib/sync-adapters.mjs`, `template/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh`, `template/.forge/hooks/pre-tool-use/hooks.manifest.default` (novo), `template/.forge/hooks/pre-tool-use/lib/` (ponte, nova), gate novo, README, CHANGELOG.

### #130 — importar o gerador reconcilia 70 arquivos do consumidor

**#130** · Closes #130 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/sync-adapters.mjs:352-372` (bloco `// ── entry ──`) roda incondicionalmente, sem guarda de módulo principal, e o `process.exit(1)` de nível de módulo mata o importador.

Desenho, reaproveitando L1 D6: guarda de principal por identidade de arquivo (`realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1])`), `process.exit` só dentro do galho principal, e exportação nomeada da função que monta a fiação (a #125 precisa lê-la). Alternativa descartada: o idioma de `plugin-build.mjs` (`import.meta.url === \`file://${process.argv[1]}\``), medido falso nas três invocações sob `$TMPDIR` no macOS (L1 §4.4), o que desarmaria também o caminho legítimo.

Vermelho, executado: anexar `// edicao-pendente` a um arquivo de `.claude/agents/` do consumidor sintético e rodar `node --input-type=module -e "await import('<C>/.forge/scripts/lib/sync-adapters.mjs')"`; esperado: arquivo intacto e nada impresso. Hoje:

```
  antes: 1
OK reconcile complete: 1 active [claude]
  depois: 0
```

Gate que fica: `tests/w<NNN>-module-import-side-effect-gate.sh`, com o par: importar não muda o sha de nenhum arquivo sob `.claude/` e expõe pelo menos uma exportação (positiva), e `node sync-adapters.mjs` direto continua imprimindo `OK reconcile complete` e restaura o arquivo editado (positiva do caminho legítimo). Propriedade PBT: não se aplica, a entrada é binária (importado ou principal). Mutação: remover a condição da guarda faz o cenário de import falhar com o sha alterado; inverter a condição faz o cenário de invocação direta falhar sem `OK reconcile`.

Arquivos: `template/.forge/scripts/lib/sync-adapters.mjs`, gate novo, README, CHANGELOG.

### #142 — o update introduz o nome default do lock em quem declarava outro caminho de serialização

**#142** · Closes #142 · gate novo: sim

Causa raiz, remedida: o update não reescreve `resource` declarado (caso 1 da triagem preserva `axis-heavy-suite`). A partição vem de `bin/forge.mjs:447-460` (`newForgeKeys`), que mescla o bloco `heavy_mutex` inteiro, com `resource: forge-heavy-suite`, em quem não tinha o bloco, sem uma linha sobre identidade do lock; a lib cai no mesmo nome sem yaml (`template/.forge/scripts/lib/heavy-mutex.sh:235`). Medido nas árvores desta máquina: axis-fare-validator declara `axis-heavy-suite` e axis-go-cloud declara `forge-heavy-suite`, com a mesma lib de 932 linhas — duas famílias de lock que não se serializam.

Desenho: quando o update mescla `heavy_mutex` ausente, ele resolve o recurso antes e depois pela mesma precedência da lib (env > yaml > default) e imprime uma linha nominal `heavy_mutex: recurso resolvido <antes> → <depois> (lock <caminho>)`, com `WARN` quando os dois diferem; o `doctor` passa a imprimir o recurso resolvido na linha `HEAVY-MUTEX` que já existe, e o gate trava L1 D8 (o update nunca reescreve `resource`, `root` e `enabled` declarados). Alternativa descartada: trocar o default para um nome neutro, que reparticionaria todos os consumidores no default atual. Descartada também a leitura dos `forge.yaml` de árvores irmãs (sugestão 2 da issue): exige varrer o disco a cada push.

Pergunta ao dono: implementar o registro de famílias em caminho fixo (L1 D10), que torna a partição visível de dentro de cada árvore, e qual nome default o harness deve publicar.

Vermelho, executado (`/tmp/fh-A-142.sh`, caso 2): remover o bloco `heavy_mutex` de um consumidor e rodar `update`; esperado: linha nominando o recurso resolvido. Hoje só a mescla aparece:

```
forge.yaml: 1 chave(s) de topo nova(s) do template mescladas: heavy_mutex
  bloco depois:   enabled: false   resource: forge-heavy-suite   timeout_s: 1800
```

Gate que fica: `tests/w<NNN>-heavy-mutex-partition-gate.sh`. Propriedade PBT: para `forge.yaml` gerados (bloco presente ou ausente, `resource` aleatório, `FORGE_HEAVY_MUTEX_RESOURCE` definido ou não), depois do update o recurso resolvido pela lib é igual ao de antes, ou o stdout do update contém os dois nomes numa linha `heavy_mutex:`; e `resource`, `root` e `enabled` declarados ficam byte-idênticos. Mutação: remover a impressão da linha nominal faz o caso "bloco ausente com env diferente" falhar; fazer o merge sobrescrever `resource` faz o cenário D8 falhar.

Arquivos: `bin/forge.mjs`, `template/.forge/scripts/doctor.sh`, gate novo, README, CHANGELOG.

**DoD da Onda 1:** num consumidor sintético criado por `init`, com conserto local em `scripts/`, gancho de segredos armado, exceção declarada e bloco `heavy_mutex` removido, um `update` seguido de `sync` deixa o conserto intacto e nomeado no stdout, o gancho sai 2 para payload com segredo via stdin e está registrado no `settings.json`, o import do gerador não altera `.claude/` enquanto a invocação direta ainda reconcilia, e o stdout nomeia o recurso de lock resolvido. Cada negativa ("não sobrescreveu", "não alterou") é provada junto com a positiva correspondente (linha nominal presente, rc 2 observado, `OK reconcile` impresso).

## Onda 2 — ferramentas que destroem trabalho do consumidor com rc 0

### #120 — handoff-gen troca o HANDOFF.md inteiro quando faltam marcadores

**#120** · Closes #120 · gate novo: não (amplia `tests/w60-handoff-gen-gate.sh`)

Causa raiz: `template/.forge/scripts/lib/handoff-render.mjs:56-60` só preserva quando o arquivo existente tem os marcadores `NARRATIVE-DELTA`; sem eles, `:70` (`writeFileSync(out, content)`) grava o template renderizado por cima, sem backup e com rc 0.

Desenho: quando o arquivo existente não tem os marcadores e difere do conteúdo novo, o renderizador copia o arquivo anterior para `.git/forge-backups/handoff-<timestamp>.md` (fora da árvore, mesmo destino de backup do update desde a #76; fallback `.forge/HANDOFF.md.bak-<timestamp>` fora de repositório git) antes de escrever, e imprime `WARN: HANDOFF.md sem marcadores NARRATIVE-DELTA — conteúdo anterior (<N> bytes) salvo em <caminho>` em stderr, rc 0. Alternativa descartada como default: recusar sem `--force`, que muda o contrato do `handoff-gen.sh` para o fluxo `/forge:handoff` e para o hook de sessão que o chamam esperando rc 0 (w62). Descartada também a guarda de proporção de tamanho: um limiar é heurística e deixaria passar a perda de um arquivo pequeno.

Pergunta ao dono: recusar por padrão (rc≠0 sem `--force`) e alinhar o fluxo `/forge:handoff`, que hoje escreve fora dos marcadores?

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): `.forge/HANDOFF.md` com 3.000 seções sem marcadores e change `c1` ativo; `FORGE_ROOT=$C bash .forge/scripts/handoff-gen.sh c1`; esperado: backup com os bytes anteriores. Hoje:

```
  antes=  111786 bytes
  rc=0
  depois=    2569 bytes; backups: 0
```

Gate que fica: cenários novos no w60 — sem marcadores: o backup existe e é byte-idêntico ao arquivo anterior (positiva) e o WARN nomeia o caminho; com marcadores: nenhum backup e o delta preservado (controle); arquivo idêntico ao render: nenhum backup. Propriedade PBT: para conteúdos anteriores gerados (com e sem marcadores, com bytes aleatórios fora deles), os bytes anteriores são sempre recuperáveis depois da geração — ou no próprio arquivo (delta preservado) ou num backup byte-idêntico. Mutação: remover a cópia de backup faz o cenário sem marcadores falhar por backup ausente.

Arquivos: `template/.forge/scripts/lib/handoff-render.mjs`, `tests/w60-handoff-gen-gate.sh`, CHANGELOG.

### #139 — `/forge:red record` sobrescreve a evidência anterior

**#139** · Closes #139 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/red-evidence.mjs:9` fixa um caminho único e `template/.forge/scripts/lib/red-evidence-ops.mjs:93-127` copia os escalares do topo (`const data = { ...ev.data }`), atribui campo a campo e grava com `writeJsonAtomic`: o segundo `record` apaga o primeiro, e um `record` parcial herda campos de outro defeito.

Desenho, reaproveitando L5 D12, D13 e D19: `red-evidence.json` ganha `entries[]` com um registro por defeito e `id` estável (`record --id`); `record` sobre `id` já declarado sem `--id` explícito recusa (fail-closed contra quimera); os escalares do topo passam a ser projeção da primeira entrada e o `status` do topo é derivado (observado só se todas as entradas estão observadas ou dispensadas). Leitores antigos continuam lendo o topo. O schema `red-evidence.schema.json` ganha `entries` como propriedade opcional. Alternativa descartada: um arquivo por defeito em `evidence/red/`, que obrigaria todo leitor (pre-push, spec-verify, CI) a descobrir o universo de arquivos e deixaria arquivo extra ignorado, que é o quarto sintoma medido. Separado da #138 porque o locus é outro (`red-evidence-ops.mjs:93-127` contra os predicados `type !== 'bugfix'` em `:69`, `:219` e `check-red-first.mjs:166`, `:350`, `:539`); a #138 vem depois e itera `entries`.

Vermelho, executado (`/tmp/fh-A-139.sh`): `record` de `DefeitoA` e depois `DefeitoB` no mesmo change `type: bugfix`; `grep -r DefeitoA <change> | wc -l` esperado ≥1; `record --failure-pattern PC` sem `--test-id` num change com duas entradas esperado rc≠0. Hoje:

```
  ocorrências de DefeitoA no change: 0
  topo: DefeitoB PB ["src/b.sh"] sem entries
  topo: DefeitoB PC
```

Gate que fica: `tests/w<NNN>-red-evidence-entries-gate.sh`; revalidar w106, w107 e w144, que escrevem o artefato à mão (L5 §6.4). Propriedade PBT: para sequências geradas de `record --id <k>` com campos aleatórios, cada `id` aparece exatamente uma vez em `entries`, a última declaração por `id` vence, nenhum campo de um `id` aparece na entrada de outro, e o topo é igual à projeção da primeira entrada. Mutação: trocar a escrita em `entries` pela atribuição no topo faz o cenário A+B falhar com contagem 0; remover a recusa sem `--id` faz o cenário da quimera sair rc 0.

Arquivos: `template/.forge/scripts/lib/red-evidence.mjs`, `red-evidence-ops.mjs`, `check-red-first.mjs` (leitura de `entries`), `template/.forge/schemas/red-evidence.schema.json`, `template/.forge/commands/testing/red.md` (+ plugin), gate novo, README, CHANGELOG.

### #107 — o corpo perdido de uma mensagem já conhecida nunca volta por sync

**#107** · Closes #107 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/liaison-import.mjs:197-198` conta mensagem já conhecida como `dup` e faz `continue` antes da cópia de blob, que mora em `:237-243`, dentro do laço das mensagens novas. Réplica que perde um blob nunca o recupera, com rc 0.

Desenho: uma passada própria, depois do merge, que percorre todas as mensagens locais com `body_ref` cujo blob falta localmente e o copia do bundle quando existe lá, contando `N blob(s) recuperado(s)`; blob ausente nos dois lados vira `WARN: <n> body_ref sem blob (local e hub)` com os ids. Alternativa descartada: tirar o `continue` e reprocessar mensagens conhecidas no laço de escrita, que reabriria a detecção de duplicata e de divergência já coberta por w111 e w195.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): réplica `qq` sincroniza uma mensagem com `--body-file`, apaga o blob local e roda `liaison-ops.sh sync ch`; esperado: 1 blob local. Hoje:

```
OK sync via fs — 0 nova(s), 2 duplicata(s) (no-op), 0 conflito(s), 0 em quarentena
  sync rc=0
  blobs em qq após sync: 0  hub: 1
```

Gate que fica: `tests/w<NNN>-liaison-blob-recovery-gate.sh`, com a positiva (blob de volta e byte-idêntico ao do hub, linha `recuperado` impressa) e o controle (sem perda, a linha de recuperação não aparece). Propriedade PBT: para subconjuntos gerados de blobs apagados localmente, depois de um `sync` o conjunto de blobs locais contém todo `body_ref` local cujo blob existe no hub. Mutação: remover a passada de recuperação faz o cenário principal falhar com 0 blobs.

Arquivos: `template/.forge/scripts/lib/liaison-import.mjs`, gate novo, README, CHANGELOG.

### #123 — worktree de branch antiga publica no hub com `_common.sh` destrutivo

**#123** · Closes #123 · gate novo: sim

Causa raiz: `template/.forge/scripts/liaison-ops.sh:101` resolve `ROOT` pelo checkout principal, mas `:103` resolve `LIBDIR` pela cópia da árvore que invoca; o único elo lido do tronco é a configuração, e `template/.forge/scripts/lib/liaison-config.mjs:27` não tem kind capaz de travar leitor antigo. Custo medido em 2026-09-15, somente leitura: 176 worktrees de consumidor (axis-fare-validator, axis-go-cloud, Axis.PadSimulator, azim-crm) têm `_common.sh`, e 146 delas não contêm `_dir_push_union` (predicado por nome; um fork com a união sob outro nome seria contado como antigo).

Desenho, a proposta da issue como opt-in por consumidor: `fs-union` entra em `TRANSPORT_KINDS` e no `liaison-config.schema.json`, com o mesmo backend de `fs` em `821178e` (push por união). A proteção vem do leitor antigo: `liaison-config.mjs:86` já recusa kind desconhecido (`kind inválido`), então uma árvore anterior ao kind que leia o `liaison.yaml` do tronco falha fechado antes de tocar o hub. Quem não troca o kind não muda nada — por isso não é quebra de contrato do produtor. Alternativa descartada como default: resolver `LIBDIR` pelo tronco, que muda qual código de reconciliação roda em toda worktree de todo consumidor. Descartado também o "campo de política" ao lado de `kind: fs`: não medi se o leitor antigo recusa campo desconhecido, e se ele ignorar, a opção não trava ninguém.

Pergunta ao dono: recomendar a troca para `fs-union` aos consumidores via liaison, sabendo que todas as worktrees anteriores ao kind (176 hoje, pelo censo acima) param de sincronizar até atualizar a maquinaria?

Vermelho, executado: `liaison-ops.sh transport set ch --kind fs-union --path <HUB>`; esperado rc 0. Hoje:

```
kind inválido: fs-union (use manual|fs|git|gh)
  rc=1
```

Gate que fica: `tests/w<NNN>-liaison-fs-union-gate.sh`: `transport set --kind fs-union` rc 0 e `sync` publica com união (positiva); uma árvore com o `liaison-config.mjs` de `821178e` (copiado como fixture) lendo esse yaml sai rc≠0 e o sha do hub fica idêntico antes e depois. Propriedade PBT: não se aplica, os estados são enumeráveis (kind novo ou antigo × leitor novo ou antigo). Mutação: remover `'fs-union'` de `TRANSPORT_KINDS` faz o `transport set` sair rc 1.

Arquivos: `template/.forge/scripts/lib/liaison-config.mjs`, `template/.forge/scripts/lib/transports/` (roteamento do kind), `template/.forge/schemas/liaison-config.schema.json`, gate novo, README, CHANGELOG.

**DoD da Onda 2:** um HANDOFF sem marcadores regenerado deixa backup byte-idêntico e o WARN com o caminho; dois `record` no mesmo change deixam as duas entradas legíveis por `check-red-first.mjs status`; um blob apagado volta depois de um `sync` com a linha de recuperação impressa; e `transport set --kind fs-union` sai rc 0 enquanto o leitor de `821178e` recusa o mesmo yaml sem alterar o hub. Toda asserção de "não perdeu" é provada pela presença do dado recuperado, nunca só pela ausência de erro.

## Onda 3 — o que trava o trabalho de quem instalou

### #144 e #137 — dono vivo nunca é reclamável (um PR)

**#144** · **#137** · Closes #144 · Closes #137 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: a política "dono vivo nunca é reclamável" mora num único ramo do laço de aquisição, `template/.forge/scripts/lib/heavy-mutex.sh:869-890`. Em `:877-880` o único reclaim é `if ! _fhm_alive "$holder" "$htok"; then _fhm_reclaim_orphan ...`, e `_fhm_alive` (`:274-286`) classifica como vivo qualquer processo com token coerente e estado diferente de Z — inclusive o dono reparentado para o PID 1 (#144). Em `:882-888` quem espera sai com 75 atrás de qualquer dono vivo, qualquer que seja a idade da posse, porque o template não tem teto de posse (`grep -c STALE_AFTER heavy-mutex.sh` → 0; o 3600 da #137 é do fork do Axis.PadSimulator). As duas correções inserem ramos novos entre `:880` e `:882` e compartilham o primitivo de encerramento `TERM → graça → KILL` com remoção só depois de morte confirmada (L2 D6); em PRs separados, o segundo reescreveria o primeiro.

Desenho, reaproveitando L2 D1, D2, D5, D6, D7, D8 e D9, com um desvio em D3: o lock grava `beneficiary` e `beneficiary_token` quando o chamador declara `--beneficiary <pid>`; o `pre-push` declara `--beneficiary "$PPID"` (`pre-push:245`), o `heavy-run.sh` não declara. Detentor vivo com beneficiário declarado morto é reclamado; campo ausente, vazio, não numérico ou ≤ 1 nunca é licença para reclamar. Ordem no laço: dono morto, beneficiário morto, idade acima do teto. O desvio: o teto de posse (`FORGE_HEAVY_MUTEX_STALE_AFTER_S` > `heavy_mutex.stale_after_s`) é opt-in, ausente significa desligado; quando declarado, vale a invariante de L2 D4 (`efetivo + reserva ≤ teto de espera`, rebaixando com aviso de três números). L2 D3 derivava o teto da metade da espera por padrão, o que passaria a matar dono vivo em todos os consumidores depois de 900 s.

Alternativas descartadas: reclamar quando `ppid == 1` (sugestão 1 da #144), que mata `nohup`, LaunchAgent, contêiner e runner daemonizado (L2 D1); derivar a espera do teto de posse (sugestão 1 da #137), que levaria um `git push` a esperar mais de uma hora e agrava a #144 (L2 D3).

Pergunta ao dono: ligar o teto de posse por padrão, derivado da metade do teto de espera, como L2 decidiu?

Vermelho, executado (`/tmp/fh-A-mutex.sh` e bancada R02 da #137, `FORGE_HEAVY_MUTEX_ROOT` em mktemp). #144: dono vivo com ppid 1 e esperante com timeout 4 s, esperado rc 0 depois de o beneficiário morrer. #137: dono vivo por 30 s, esperante com `FORGE_HEAVY_MUTEX_STALE_AFTER_S=2 FORGE_HEAVY_MUTEX_TIMEOUT_S=10`, esperado aquisição antes de 10 s. Hoje a variável não é lida e os dois saem 75:

```
  dono pid=22479 ppid=1 label=holder-orfao
  esperante rc=75 elapsed=6s
esperante rc=75 elapsed=17s
```

Gate que fica: `tests/w<NNN>-heavy-mutex-posse-gate.sh`, com contrafactuais obrigatórios: dono em `nohup` sem beneficiário declarado não é reclamado (e o esperante sai 75 nomeando o motivo); beneficiário vivo não é reclamado; recolhimento imprime o motivo (`beneficiário morto` ou `posse acima do teto`) e o censo de descendentes (positiva). Revalidar w151 e w154, que exportam `FORGE_HEAVY_MUTEX_TESTING` de formas diferentes.

Propriedade PBT: para teto de espera gerado em [0, 200] e teto de posse declarado gerado (ausente, 0, e valores entre 1 e 100000), o teto efetivo é 0 quando ausente, e quando positivo satisfaz `efetivo + reserva ≤ espera`; e para estados de campo gerados de `beneficiary` e `acquired_at` (ausente, vazio, não numérico, ≤ 0, futuro, válido), o lock só é reclamado nos estados válidos com beneficiário morto ou idade acima do efetivo.

Mutação: remover o ramo de beneficiário faz o cenário #144 sair 75; tratar `acquired_at` ausente como idade infinita faz o w151[49](c) sair rc 0 antes de 8 s (L2 D5, M13); remover a confirmação de morte antes de `_fhm_reclaim_orphan` faz o cenário de detentor imortal (outro uid simulado) remover o lock com o detentor vivo.

Arquivos: `template/.forge/scripts/lib/heavy-mutex.sh`, `template/.forge/hooks/git/pre-push`, `template/.forge/schemas/forge.schema.json` (`stale_after_s` e a paridade de `root` de L2 D12), `template/.forge/forge.yaml` (comentário da chave, sem valor), gate novo, README, CHANGELOG.

### #146 — SIGINT não aciona `_hr_sig` quando INT nasce ignorado

**#146** · Closes #146 · gate novo: sim

Causa raiz: bash não interativo não arma `trap` sobre sinal ignorado na entrada. `template/.forge/scripts/heavy-run.sh:191` (`trap "_hr_sig $s" "$s"`) vira no-op quando o wrapper é lançado com `SIGINT=SIG_IGN` herdado (`( nohup ... & ) &`), e a carga herda a mesma disposição.

Desenho: depois de armar, o wrapper confere `trap -p INT`; se veio vazio, ele se reexecuta uma vez com a disposição resetada por um processo não bash (`perl -e '$SIG{INT}=$SIG{TERM}="DEFAULT"; exec @ARGV'`, com uma variável de guarda contra laço), e a carga é lançada com INT e TERM na disposição padrão. HUP fica de fora do reset, herdado como veio: resetar HUP também mataria, no fechamento do terminal, o processo que o lançamento em `nohup` do campo existe para proteger — exatamente o invariante que a Onda 3/#144 exige preservar (dono em `nohup` sem beneficiário declarado não é reclamado). Se HUP precisar de tratamento próprio no wrapper, é decisão separada, fora deste PR. Sem `perl`, recusa com rc 70 e diagnóstico em vez de rodar sem trap. Alternativa descartada: ignorar o problema e documentar o lançamento, que é exatamente o modo `nohup` do campo; e `set -m` no wrapper, que não reverte `SIG_IGN` herdado (medido na triagem).

Vermelho, executado (`/tmp/fh-A-146.sh`, `FORGE_HEAVY_MUTEX_ROOT` em mktemp): `bash -c "trap '' INT; exec bash heavy-run.sh --resource r -- sleep 12" &` e `kill -INT` aos 2 s; esperado rc 130 em menos de 3 s. Hoje:

```
[controle] set -m, INT padrão na entrada : rc=130 elapsed=2s lock_restante=0 sleep_12_vivo=0
[caso] set -m, INT IGNORADO na entrada   : rc=0 elapsed=13s lock_restante=0 sleep_12_vivo=0
```

Gate que fica: `tests/w<NNN>-heavy-run-signal-disposition-gate.sh`, positiva rc 130 e `sleep` morto em menos de 3 s no caso ignorado, e controle idêntico no caso padrão. Propriedade PBT: não se aplica; o espaço exercitado é {INT, TERM} × {padrão, ignorado}, quatro casos — HUP não entra no reset e por isso não faz parte deste espaço (ver desenho acima); um cenário à parte confirma que a disposição de HUP herdada (ignorada ou padrão) atravessa a reexecução sem ser alterada. Mutação: remover a reexecução faz o caso ignorado voltar a rc 0 com ~13 s.

Arquivos: `template/.forge/scripts/heavy-run.sh`, gate novo, README, CHANGELOG.

### #141 — hook do tronco procura o script delegado na worktree

**#141** · Closes #141 · gate novo: sim

Causa raiz: `bin/forge.mjs:211-247` grava `core.hooksPath` absoluto do tronco por decisão registrada (#41/#54, LDG-0042), mas `template/.forge/hooks/git/pre-commit:6` resolve `ROOT` por `git rev-parse --show-toplevel` da worktree, e `:74-77` bloqueia quando `.forge/scripts/` existe sem o script delegado. Um hook novo encontra scripts velhos na worktree e bloqueia o commit. A mesma classe tem 12 sítios medidos em L3 §0 (pre-push 6, pre-commit 1, commit-msg 1, post-merge 2, `hooks/git/lib/check-red-first.sh` 2).

Desenho, reaproveitando L3 D14: precedência de resolução do alvo delegado — primeiro a árvore que executa (`$ROOT/.forge/scripts/<alvo>`); se ausente lá, a árvore do hook (`$(dirname "$0")/../../scripts/<alvo>`), com uma linha `hook: <alvo> ausente em <worktree> — usando o do tronco (<caminho>); rode forge update na worktree`; bloqueio mantido quando o alvo falta nas duas. As recusas existentes ficam literais. Alternativas descartadas: voltar ao `hooksPath` relativo (reverte #41/#54 e LDG-0042) e degradar a recusa para WARN (afrouxa a política da #49 de que delegação em alvo ausente é erro).

Vermelho, executado (`/tmp/fh-A-141.sh`): worktree com `.forge/scripts/` sem `check-secrets.sh`, hook do tronco novo; esperado rc 0 com a linha que nomeia o tronco. Hoje:

```
pre-commit BLOQUEADO: .forge/scripts/ existe mas check-secrets.sh não — a delegação aponta para um alvo ausente
  rc=1
```

Gate que fica: `tests/w<NNN>-delegacao-arvore-do-hook-gate.sh` com a matriz de L3 §4.3 ([a] worktree sem alvo e tronco com: passa e nomeia; [b] as duas sem: continua bloqueando — contrafactual; [d] worktree com alvo próprio: usa o próprio); cenário de auto-ironia sobre os 12 sítios. Revalidar w97, w137, w147 e w191. Propriedade PBT: não se aplica; o espaço são os quatro estados da matriz, exaustivos. Mutação: remover o fallback num sítio faz [a] bloquear; aplicar o fallback também quando o alvo falta nas duas faz [b] passar.

Arquivos: `template/.forge/hooks/git/pre-push`, `pre-commit`, `commit-msg`, `post-merge`, `lib/check-red-first.sh`, gate novo, README, CHANGELOG.

### #132 e #134 — push de deleção pura roda a suíte inteira (um PR)

**#132** · **#134** · Closes #132 · Closes #134 · gate novo: sim (um gate para o PR)

Causa raiz comum, provada: no template, o único teste de `lsha` zero fica dentro dos laços de varredura (`template/.forge/hooks/git/pre-push:79` e `:272`); `run_check "typecheck"` e `run_check "test"` (`:324-325`), os gates (`:431`) e `harness-tests` (`:478`) rodam incondicionalmente. As duas issues descrevem a ausência do mesmo curto-circuito; a sentinela `_viu_ref` da #132 é patch local do Axis.DevicePlatform (0 ocorrências no template e em cinco consumidores), e o manifesto órfão da #134 não existe no template (o pre-push do template não carimba manifesto). A contribuição da #132 que vale aqui é a propriedade de três entradas.

Desenho, reaproveitando L3 D1–D6: antes de `:324`, classificar a entrada do stdin em três estados — vazia, só deleções, mista — e, em só deleções, pular typecheck, test, gates e harness-tests com a linha `pre-push: push de deleção pura (<n> ref(s)) — checks de árvore não se aplicam`. Entrada vazia e entrada mista continuam rodando tudo. Alternativa descartada: tratar entrada vazia como deleção, que é o colapso da `_viu_ref` que a #132 mede. Pergunta ao dono: deleção de ref protegida (tronco, release) merece política própria, como a #134 sugere?

Vermelho, executado (`/tmp/fh-A-134.sh`): `runtime.test` e `runtime.typecheck` gravam num marker; stdin `(delete) 000…0 refs/heads/x <sha>`; esperado marker vazio e a linha de deleção pura. Hoje, e o controle com stdin vazio mostra o mesmo marker:

```
pre-push: typecheck OK
pre-push: test OK
  marker: RODOU-TYPECHECK RODOU-TEST
```

Gate que fica: `tests/w<NNN>-prepush-delecao-pura-gate.sh`, com a positiva (linha de deleção pura presente) e os dois contrafactuais (vazia e mista gravam o marker). Ajustar a fixture de `w97:38` para `local_sha` não zero (L3 §7.1 mediu o w97 vermelho sem isso); revalidar w135, w146, w147, w151, w152 e w160. Propriedade PBT: para listas geradas de linhas de ref (0 a 6 linhas, cada uma deleção ou publicação, em ordem aleatória), a suíte roda se e somente se a lista é vazia ou contém ao menos uma linha com `lsha` não zero. Mutação: remover o curto-circuito faz o caso só-deleções gravar o marker; tratar vazia como deleção faz o contrafactual vazio ficar sem marker.

Arquivos: `template/.forge/hooks/git/pre-push`, `tests/w97-hook-portability-gate.sh`, gate novo, README, CHANGELOG.

### #135 — `run_check` sem teto e suíte muda

**#135** · Refs #135 · gate novo: sim

Causa raiz: `template/.forge/hooks/git/pre-push:204-222` executa `eval "$cmd"` com saída redirecionada até o fim e sem teto, enquanto `forge_run_gate` (`template/.forge/scripts/lib/forge-runtime.sh:20` e `:49`) tem `perl alarm` de 300 s; `template/.forge/scripts/tests/run-all.sh:66-92` só imprime o nome do teste depois que ele termina.

Desenho, reaproveitando L3 §3.4: teto opt-in por valor (`FORGE_PREPUSH_CHECK_TIMEOUT_S`, sem default) aplicado por `perl alarm`; estourado, o hook sai rc≠0 com `pre-push BLOQUEADO: <label> excedeu o teto de <n>s (morto por teto, não reprovado)`; e `run-all.sh` do template anuncia o nome do teste antes de executá-lo. Alternativa descartada: reusar os 300 s de `forge_run_gate` como default, que mataria suítes legítimas de consumidor medidas em mais de dez minutos. Fica `Refs` porque o terceiro item do corpo (manifesto em `running`) é maquinaria do consumidor e a distinção "morto por teto" no runner é LDG-0181, fora desta rodada. Pergunta ao dono: qual default de teto publicar, se algum.

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `runtime.test: sleep 8` e `FORGE_PREPUSH_CHECK_TIMEOUT_S=2`; esperado rc≠0 nomeando `test` e o teto. Hoje a variável é ignorada:

```
  rc=0 elapsed=43s
pre-push: test OK
pre-push OK
```

Gate que fica: `tests/w<NNN>-prepush-teto-de-check-gate.sh`: com teto, rc≠0 e a linha "morto por teto" presente; sem teto, `sleep 3` passa (contrafactual); `run-all.sh` com teste `sleep 5` tem o nome impresso antes do término (positiva por timestamp da linha). Propriedade PBT: para pares gerados (duração d, teto t) com |d − t| ≥ 2 s e d, t ≤ 6, o desfecho é "morto por teto" se e somente se d > t. Mutação: remover o `perl alarm` faz o cenário com teto sair rc 0.

Arquivos: `template/.forge/hooks/git/pre-push`, `template/.forge/scripts/tests/run-all.sh`, gate novo, README, CHANGELOG.

### #127 — o doctor desce em worktrees e mede menção como configuração

**#127** · Closes #127 · gate novo: sim

Causa raiz: `template/.forge/scripts/doctor.sh:115` e `:119` fazem `grep -rl` sobre `$ROOT/.forge` inteiro e filtram só a saída; o filtro `USER_DATA` (`:114`) não exclui `liaison/` nem `ledger/`, onde `.claude/` aparece como texto de conversa.

Desenho, reaproveitando L6 D (§2.3): universo por inclusão da fonte canônica — `rules/`, `agents/`, `skills/`, `commands/`, `templates/` e os arquivos canônicos de topo de `.forge/` — passado explicitamente ao `grep`, com contador de arquivos examinados e terceiro estado quando o universo é vazio. Alternativa descartada: ampliar a denylist com `liaison|ledger|worktrees`, que continua pagando a descida quando o filtro é de saída e deixa entrar o próximo diretório de dados que alguém criar.

Vermelho, executado (`/tmp/fh-R02-Bupdate.sh`): menção a `.claude/settings.json` só em `.forge/liaison/ch/log/p.jsonl` e numa worktree; esperado `✓ fonte canônica sem refs`. Hoje:

```
  ✗ harness: 1 arquivo(s) da fonte canônica com refs .claude/
  varredura bruta desce em worktrees? 1
```

Gate que fica: `tests/w<NNN>-doctor-scan-universe-gate.sh`: menção só em liaison/ledger/worktrees dá ✓ e o contador de examinados é maior que zero (positiva); menção plantada em `rules/` dá ✗ (contrafactual); um shim de `grep` em PATH registra argv e nenhum caminho contém `/worktrees/`. Revalidar w158. Propriedade PBT: para colocações geradas de menções em diretórios aleatórios (canônicos e de dados), a contagem reportada é igual ao número de arquivos com menção dentro do universo de inclusão. Mutação: voltar `$ROOT/.forge` como universo faz o cenário do liaison dar ✗.

Arquivos: `template/.forge/scripts/doctor.sh`, gate novo, README, CHANGELOG.

### #129 — a isenção .NET não alcança caminho relativo

**#129** · Closes #129 · gate novo: sim

Causa raiz: `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh:51` exige `/` antes de `src|tests|services|deploy`; caminho relativo que começa no segmento não casa e o `elif` reprova PascalCase.

Desenho: âncora `(^|/)(src|tests|services|deploy)(/|$)`. Alternativa descartada: absolutizar o caminho no início do hook, que muda o que é impresso nas mensagens e depende do cwd de quem chama.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `bash validate-naming-conventions.sh "src/Axis.T.Infrastructure/Communications/BanklyCommunication.cs"`; esperado rc 0. Hoje:

```
  relativo rc=1
  absoluto rc=0
  controle mysrc rc=1
```

Gate que fica: `tests/w<NNN>-naming-path-provenance-gate.sh`, positiva relativo rc 0 e contrafactual `mysrc/Communications/X.cs` rc 1. Propriedade PBT: para caminhos gerados com o segmento isento em profundidade aleatória, diretórios PascalCase aleatórios e prefixo absoluto presente ou ausente, o veredito com prefixo é igual ao veredito sem prefixo; e segmento com prefixo colado (`mysrc`, `srcx`) nunca isenta. Mutação: voltar a âncora a `/` faz o caso relativo sair rc 1.

Arquivos: `template/.forge/hooks/pre-tool-use/validate-naming-conventions.sh`, gate novo, README, CHANGELOG.

**DoD da Onda 3:** um esperante atrás de dono vivo com beneficiário morto adquire com rc 0 e a linha do motivo, e o contrafactual `nohup` sem beneficiário continua 75; `heavy-run.sh` lançado com INT ignorado sai 130 em menos de 3 s; um commit numa worktree com scripts velhos passa com a linha que nomeia o tronco, e o contrafactual sem alvo nas duas árvores continua bloqueando; um push de deleção pura imprime a linha própria e deixa o marker vazio, enquanto entrada vazia e mista gravam o marker; um check que excede o teto declarado sai rc≠0 com "morto por teto"; o doctor dá ✓ com menção só em dados e contador de examinados maior que zero; e o hook de nomes aceita `src/...` relativo e continua reprovando `mysrc/...`.

## Onda 4 — o que passa verde sem medir

### #119 — lib antiga com gates CSV imprime "0 gate(s)" e passa

**#119** · Closes #119 · gate novo: não (amplia `tests/w190-pre-push-gate-reader-gate.sh`)

Causa raiz: a guarda de leitor indisponível em `template/.forge/hooks/git/pre-push:418` só dispara quando `_gates_inline` é vazio (forma mapeada); com CSV declarado, `:431` (`forge_runtime_gate_entries "$ROOT" || true`) engole o `command not found` e `:437-440` imprime NO-GATES com rc 0.

Desenho, a forma (b) da issue: se o frontmatter declara `gates:` com valor e o leitor devolve zero entradas, bloquear com `pre-push BLOQUEADO: runtime.gates declara <valor> e o leitor devolveu ZERO gate(s)`, nomeando a causa quando a função não existe (`type forge_runtime_gate_entries`). Alternativa descartada: mover a guarda para antes da forma, sem olhar o valor, que recusaria o primeiro push de todo projeto novo com `gates:` vazio (o comentário de `:410-417` registra isso).

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `gates: check-aa,check-bb`, os dois scripts presentes, função renomeada na lib e `gate-phase.mjs` removido; esperado rc≠0 com "leitor devolveu ZERO". Hoje:

```
.forge/hooks/git/pre-push: line 431: forge_runtime_gate_entries: command not found
pre-push: runtime.gates NO-GATES — 0 gate(s) declarado(s) no FORGE.md
pre-push OK
```

Gate que fica: cenários novos no w190 — lib antiga + CSV bloqueia com a mensagem nominal (positiva), lib nova + CSV imprime "2 gate(s) de fase 'source'" (controle), `gates:` vazio segue NO-GATES com rc 0 (contrafactual). Propriedade PBT: não se aplica; o espaço é {função presente, ausente} × {CSV, mapeada, vazia}, seis casos exercitados. Mutação: remover a contradição "declarou e leu zero" faz o cenário da lib antiga sair rc 0.

Arquivos: `template/.forge/hooks/git/pre-push`, `tests/w190-pre-push-gate-reader-gate.sh`, CHANGELOG.

### #106 — `runtime.test` sem guarda de cobertura

**#106** · Refs #106 · gate novo: sim

Causa raiz: `template/.forge/hooks/git/pre-push:325` executa `fm_field test` como texto livre; nada confronta o comando com as superfícies de build da árvore (`grep -cE 'sln|csproj|dotnet'` no hook → 0).

Desenho: aviso, nunca bloqueio por padrão: se a árvore rastreada (`git ls-files`) contém `*.sln` ou `*.csproj` e `runtime.test` não contém `dotnet`, imprimir `pre-push: AVISO — <n> solution(s) .NET rastreada(s) e runtime.test ('<cmd>') não invoca dotnet; a suíte .NET não roda neste gate`. Reconhecimento restrito à stack .NET, que é a medida (axis-go-cloud: 24 `.sln`, `test: pnpm test`). Alternativa descartada: bloquear, que reprovaria todo push de consumidor cujo `runtime.test` chama um script que por sua vez chama `dotnet` — a heurística por comando não vê através de script. Fica `Refs`: a issue pede decisão sobre bloqueio e sobre as demais stacks. Pergunta ao dono: bloqueio opt-in por chave e quais stacks reconhecer.

Vermelho, executado (`/tmp/fh-R02-Bprepush.sh`): `App.sln` rastreado e `test: echo SUITE-RAN >> marker`; esperado a linha de AVISO. Hoje:

```
pre-push: test OK
pre-push OK
  avisos dotnet/.sln: 0
```

Gate que fica: `tests/w<NNN>-prepush-cobertura-dotnet-gate.sh`: `.sln` + `pnpm test` imprime o AVISO e sai rc 0 (positiva e não bloqueio); `test: dotnet test App.sln` não avisa (contrafactual); `.sln` não rastreado não avisa. Propriedade PBT: para árvores geradas (0 a 3 arquivos `.sln`/`.csproj`, rastreados ou não) e comandos gerados (com e sem `dotnet` em posição aleatória), o aviso aparece se e somente se há arquivo .NET rastreado e o comando não contém `dotnet`. Mutação: remover a condição de rastreado faz o cenário não rastreado avisar.

Arquivos: `template/.forge/hooks/git/pre-push`, gate novo, README, CHANGELOG.

### #150 — replay sem controle positivo aceita falha adjacente

**#150** · Refs #150 · gate novo: não (amplia `tests/w107-red-replay-gate.sh`)

Causa raiz: `template/.forge/scripts/lib/red-replay.mjs:469-473` (`matchesPattern` devolve `true` com padrão nulo) e `:643-675` (base falhou → `observed`, sem prova de que a base seria capaz de ficar verde). `record` já exige `--failure-pattern` (`red-evidence-ops.mjs:114`), mas o schema aceita `null` e um padrão genérico legítimo produz o mesmo desfecho.

Desenho: (1) `replay` recusa `failure_pattern` nulo ou vazio com `not-possible` e rc≠0, sem mexer no schema; (2) campo opcional `positive_control` (comando que precisa passar na base, na mesma corrida e no mesmo checkout); declarado e falhando na base, o veredito é `not-possible` com a saída do controle no excerpt. Alternativa descartada: tornar `failure_pattern` obrigatório no schema, que invalida evidências gravadas por escritores antigos em vez de só recusar o replay. Fica `Refs`: o controle positivo é opcional até o dono decidir. Pergunta ao dono: tornar `positive_control` obrigatório em change novo?

Vermelho, executado (`/tmp/fh-A-150.sh`): fixture em que a base falha só por fixture ausente e o "fix" é cosmético; com `failure_pattern: null`, esperado rc≠0. Hoje:

```
[B] failure_pattern nulo (campo opcional no schema?) → replay:
OK replay — Red observado (ancestry, base 72ad02f) e Green confirmado em HEAD
  rc=0
```

Gate que fica: cenários novos no w107 — nulo recusa com `not-possible` (positiva: status gravado `not-possible` e motivo nomeado); `positive_control` que falha na base dá `not-possible`; controle que passa na base mantém o `observed` do caso legítimo (contrafactual). Propriedade PBT: para padrões gerados (nulo, vazio, string aleatória presente ou ausente na saída da falha), `observed` nunca é gravado com padrão nulo ou vazio. Mutação: devolver `true` para padrão nulo em `matchesPattern` faz o cenário nulo gravar `observed`.

Arquivos: `template/.forge/scripts/lib/red-replay.mjs`, `template/.forge/schemas/red-evidence.schema.json` (`positive_control` opcional), `tests/w107-red-replay-gate.sh`, CHANGELOG.

### #138 — Red-first sem caminho em change `type: feature` que corrige defeito

**#138** · Closes #138 · gate novo: sim · depois do PR da #139

Causa raiz: todo ponto de decisão testa `type === 'bugfix'`: `template/.forge/scripts/lib/red-evidence-ops.mjs:69` e `:219`, `check-red-first.mjs:166`, `:350` e `:539`, `red-evidence.sh:66` e `:122`, `hooks/git/lib/check-red-first.sh:123` e `spec-verify.sh:118`. Em `feature`, a escrita recusa e a leitura responde `n/a` com rc 0.

Desenho, reaproveitando L5 D1–D3 e D20: `manifest.yaml` ganha `fixes_defects` (lista de ids); o predicado único `isDefectFixing(manifest)` = `type === 'bugfix' || fixes_defects não vazio`, em `lib/defect-scope.mjs` novo, consumido pelos nove sítios; em change que declara a lista, a cobrança exige uma entrada de `entries` (da #139) por id declarado. O WARN do item 3d deixa de dizer "type mudou" quando a lista existe. Alternativas descartadas: relaxar a escrita para qualquer `type` (opção A), que registra sem cobrar; derivar de commits `fix(...)` (opção C), heurística sobre mensagem.

Vermelho, executado (`/tmp/fh-A-139.sh`, segundo bloco): mesmo change com `type: feature`; esperado, com `fixes_defects` declarado e sem evidência, `check` rc≠0. Hoje o campo não existe e o change fica fora da política:

```
FAIL (red-evidence só se aplica a change type:bugfix, got: feature)
OK (n/a — type: feature)
  check rc=0
```

Gate que fica: `tests/w<NNN>-red-defect-scope-gate.sh`: `feature` + `fixes_defects: [D1]` sem evidência reprova nomeando D1 (positiva); `feature` sem o campo segue `n/a` (contrafactual); dois ids e uma entrada reprova nomeando o faltante. Revalidar w106, w107 e w144. Propriedade PBT: para manifestos gerados (`type` em {bugfix, feature, refactor, chore}, `fixes_defects` ausente, vazio ou com 1 a 3 ids), a aplicabilidade reportada pelos nove sítios é idêntica entre eles e igual a `isDefectFixing`. Mutação: voltar um dos sítios a `type === 'bugfix'` faz a propriedade de igualdade entre sítios falhar nomeando o arquivo.

Arquivos: os nove sítios acima, `template/.forge/scripts/lib/defect-scope.mjs` (novo), `template/.forge/schemas/spec-manifest.schema.json`, `template/.forge/rules/testing/regression-red-first.md`, `template/.forge/commands/testing/red.md` (+ plugin), gate novo, README, CHANGELOG.

### #128 — run-manifest.sh descarta o `--root` do chamador

**#128** · Closes #128 · gate novo: sim

Causa raiz: `template/.forge/scripts/run-manifest.sh:6` anexa `--root "$ROOT"` depois de `"$@"`, e `template/.forge/scripts/lib/run-manifest.mjs:23` deixa a última ocorrência vencer.

Desenho: o wrapper só anexa `--root` quando o chamador não passou um; `parseArgs` recusa chave escalar repetida com valores diferentes (`FAIL: --root informado duas vezes com valores diferentes`) e aceita repetição idêntica. Alternativa descartada: recusar toda repetição, idêntica ou não, que quebraria chamador que repete por construção sem ganho de segurança.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `bash A/.forge/scripts/run-manifest.sh write --root B --stage verify --dir B/out --status passed`; esperado `head_sha` igual ao HEAD de B. Hoje:

```
  rc=0
  head_sha gravado=5b77af532748 A=5b77af532748 B=956f8e41f07e
```

Gate que fica: `tests/w<NNN>-run-manifest-root-gate.sh`: `head_sha` = HEAD de B (positiva); valores diferentes recusam; sem `--root`, grava o HEAD da árvore do wrapper (contrafactual). Revalidar w90 e w91. Propriedade PBT: para permutações geradas dos argumentos com `--root` em posição aleatória, o `head_sha` gravado é sempre o HEAD do `--root` do chamador. Mutação: voltar o anexo incondicional faz o cenário principal gravar o HEAD de A.

Arquivos: `template/.forge/scripts/run-manifest.sh`, `template/.forge/scripts/lib/run-manifest.mjs`, gate novo, README, CHANGELOG.

### #133 — flag desconhecida aceita e flag engolida como valor em liaison-ops e deferral-ops

**#133** · Closes #133 · gate novo: sim

Causa raiz: guarda aplicada por sítio, sem declaração verificável de cobertura. `template/.forge/scripts/deferral-ops.sh:133-150` (`status`) não tem laço de parsing e `:114-115` (`test`) lê só `$1`; `template/.forge/scripts/liaison-ops.sh:771` (`--thread) filter_thread="$2"`) não chama `forge_reject_flag_as_value`, e L4 §1.1 contou 11 sítios assim. `lib/argparse.sh` nunca existiu no template (a regressão do corpo vem do overlay da #101 no consumidor).

Desenho, reaproveitando L4 §1.4: completar a guarda nos 11 sítios de `liaison-ops.sh`, laço de recusa em `deferral-ops.sh test/status` e em `wave-ops.sh`, mais um teste estrutural que enumera todo `--flag) x="$2"` sem guarda nos `*-ops.sh` e exige zero. Alternativa descartada: adotar a camada declarativa `_ap_ctx` do axis-fare-validator, contrato novo de lib incompatível com o `argparse_guard_value` do Axis.PadSimulator. Pergunta ao dono: especificar uma camada declarativa canônica numa rodada própria?

Vermelho, executado (`/tmp/fh-A-133.sh`): `deferral-ops.sh status chg --lixo x` e `liaison-ops.sh inbox canal-a --thread --show`; esperado rc 1 nos dois. Hoje:

```
OK (0 tested, 0 resolved, 0 open)
  rc=0
(nenhuma thread)
  rc=0
```

Gate que fica: `tests/w<NNN>-arg-surface-gate.sh`, com as recusas nominais (positivas: mensagem cita a flag) e os controles de uso legítimo em rc 0. Revalidar w51, w201. Propriedade PBT: para cada subcomando e pares gerados (F, G) do seu conjunto de flags com valor, `cmd --F --G` sai rc≠0 citando G. Mutação: remover a guarda de `--thread` em `inbox` faz o par (thread, show) sair rc 0.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `deferral-ops.sh`, `wave-ops.sh`, gate novo, README, CHANGELOG.

### #103 — `resolve` repetido duplica a nota e recarimba

**#103** · Closes #103 · gate novo: não (amplia `tests/w211-ledger-detail-acumulativo-gate.sh`)

O título já está corrigido por `f824165` (PR #114): `add --type roadmap --title --detail` sai rc 1 com mensagem nominal, reexecutado pelo orquestrador. O resíduo que o corpo pede no mesmo change reproduz. Causa raiz: `template/.forge/scripts/ledger-ops.sh:392` atribui `e.resolved_at = now` e anexa `Resolvido: <nota>` sem checar se a entrada já está no status pedido.

Desenho: `resolve` sobre entrada já em `resolved`/`wont-fix` sai rc 1 com `FAIL: LDG-NNNN já está '<status>' desde <resolved_at> — use update --detail para acrescentar nota`, sem escrever. Alternativa descartada: no-op silencioso com rc 0, que esconde de quem chama que o segundo ato não aconteceu.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `ledger-ops.sh resolve <id> --note n1` duas vezes; esperado segunda rc 1. Hoje:

```
  resolve1 rc=0
  resolve2 rc=0
  resolved detail="d0 — Resolvido: n1 — Resolvido: n1"
```

Gate que fica: cenário novo no w211 — segunda chamada rc 1 com a mensagem que cita o carimbo anterior (positiva), `resolved_at` byte-idêntico e nota presente uma vez. Propriedade PBT: para k gerado em [2, 5] chamadas de `resolve`, a nota aparece exatamente uma vez e `resolved_at` é o da primeira. Mutação: remover a checagem de status faz a segunda chamada sair rc 0.

Arquivos: `template/.forge/scripts/ledger-ops.sh`, `tests/w211-ledger-detail-acumulativo-gate.sh`, CHANGELOG.

### #108 — ack que falha o cursor em silêncio e doctor que emudece

**#108** · Refs #108 · gate novo: sim

Causa raiz: `template/.forge/scripts/liaison-ops.sh:732-738` engole a falha de avanço de cursor num `catch {}` vazio e imprime `OK ack`; `template/.forge/scripts/doctor.sh:231` (`2>/dev/null || true`) e `:232` (`-n`) somem com a linha de liaison quando `status` falha.

Desenho: o `catch` imprime `WARN: ack publicado, mas o cursor não avançou (<motivo>)` em stderr, rc 0 (o ack já está publicado); o doctor, com `status` rc≠0, imprime `✗ harness: LIAISON: status falhou — <primeira linha do erro>`. Fica `Refs`: o passivo retroativo de cursores pré-#105 (item 1) não reproduz sem estado gerado por código antigo. Alternativa descartada: falhar o `ack` quando o cursor não avança, que faria um ato de protocolo já publicado reportar falha.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `liaison-cursor.mjs` removido, `ack` de mensagem de terceiro; e `state.json` inválido com `doctor.sh`; esperado WARN no primeiro e linha de liaison no segundo. Hoje:

```
  ack rc=0 stderr/stdout: OK ack — qq-0001 confirma pp-0002
  state depois: {"cursors":{}}
  doctor linhas LIAISON: 0
```

Gate que fica: `tests/w<NNN>-liaison-diagnostico-mudo-gate.sh`: WARN presente e ack gravado no log (positiva); doctor com estado inválido imprime a linha de erro; estado válido imprime a linha normal (contrafactual). Propriedade PBT: não se aplica. Mutação: esvaziar o `catch` de novo faz o cenário do WARN falhar.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/doctor.sh`, gate novo, README, CHANGELOG.

### #109 — liaison não distingue mensagem enviada de publicada

**#109** · Refs #109 · gate novo: sim

Causa raiz: `template/.forge/scripts/liaison-ops.sh:325` cria `state.json` só com `cursors`, nenhum `sync` grava o que publicou, e o `status` não compara log próprio com o hub.

Desenho: `sync` com push bem-sucedido grava `published: { "<self>": "<último msg_id publicado>" }` em `state.json` (chave aditiva; leitores atuais só leem `cursors`), e `status` imprime `<n> própria(s) não publicada(s)` quando o log próprio tem mensagens posteriores à marca. Alternativa descartada: `send` e `ack` publicarem best-effort, que muda o protocolo de envio de todo consumidor. Fica `Refs`: o gate de acks distinguir "ack não publicado" é pergunta ao dono.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `send` sem `sync`, depois `status`; esperado `1 própria(s) não publicada(s)`. Hoje:

```
  LIAISON/ch: 1 thread(s) · 3 não lida(s) · 0 em quarentena
  menções a 'publicad': 0
  state.json keys: [ 'cursors' ]
```

Gate que fica: `tests/w<NNN>-liaison-outbox-watermark-gate.sh`: antes do `sync` a linha aparece com a contagem certa (positiva), depois do `sync` desaparece e `published` aponta o último id. Propriedade PBT: para sequências geradas de `send` e `sync` intercaladas, a contagem de não publicadas é igual ao número de mensagens próprias ausentes do log do hub. Mutação: não gravar `published` no `sync` faz a contagem pós-sync ficar maior que zero.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `template/.forge/scripts/lib/transports/` (retorno do push), gate novo, README, CHANGELOG.

### #117 — o nome do blob não é o sha256 dos bytes

**#117** · Closes #117 · gate novo: não (amplia `tests/w110-liaison-core-gate.sh`)

Causa raiz: `template/.forge/scripts/liaison-ops.sh:298` calcula `M.sha256Hex(buf.toString('binary'))`, e `template/.forge/scripts/lib/liaison-merge.mjs:37-39` faz hash do texto UTF-8 dessa string latin1: diverge de `shasum -a 256` em todo byte acima de 0x7F.

Desenho: blob novo é nomeado por `createHash('sha256').update(buf)`. Retrocompatível por medição: nenhum leitor recalcula o nome, `BODY_REF_RE` (`liaison-merge.mjs:267`) só confere o padrão `^blobs\/[A-Za-z0-9._-]+$` e o import só confere existência (`liaison-import.mjs:165-173`); nomes antigos seguem válidos como identificadores opacos. Alternativa descartada: migrar os nomes do acervo, que reescreve `body_ref` já publicados entre repositórios.

Vermelho, executado (`/tmp/fh-R02-Bliaison.sh`): `send --body-file` com "não, ação"; esperado prefixo do nome igual a `shasum -a 256` do blob. Hoje:

```
  nome=51ad79897c371dd154667ae63e5732dd686fd8d5e5f21bc81345f09e03da22fb
  shasum=f72d52dadc701adb2cdfdc50e2e53d71e15e4b2e53626b6aaf4f1cb14366f162
```

Gate que fica: cenário novo no w110 — prefixo igual ao `shasum` para conteúdo acentuado (positiva) e para ASCII (controle); um `body_ref` com nome antigo continua importando. Propriedade PBT: para buffers gerados de 0 a 4 KB com bytes aleatórios em [0, 255], o prefixo do nome é igual ao sha256 dos bytes. Mutação: voltar a `toString('binary')` faz o caso acentuado divergir.

Arquivos: `template/.forge/scripts/liaison-ops.sh`, `tests/w110-liaison-core-gate.sh`, CHANGELOG.

### #149 — `forge_find_prune` não poda nada e não tem invocador

**#149** · Closes #149 · gate novo: sim

Causa raiz: três defeitos em `template/.forge/scripts/lib/scan-exclude.sh`: aspas simples ecoadas viram literais (`:22`), parênteses sem escape quebram `eval` e o `-false` colado ao último padrão anula `vendor` (`:24`); e nenhum script do template carrega a lib.

Desenho: a função passa a preencher um array (`forge_find_prune_args <nome-do-array>`) com `\(`, `-name`, padrão, `-o` e `\) -prune -o`, sem `-false`, e o uso documentado passa a ser `find "$P" "${arr[@]}" ...` (bash 3.2); `forge_find_prune` antigo é removido do template porque nunca teve chamador. Invocador: o primeiro varredor por `find` do template que hoje repete a lista de poda passa a consumi-la (candidato nomeado na triagem: `doctor.sh::find_marker`, a medir no PR). Alternativa descartada: consertar o `echo` para uso com `eval`, que mantém a interface que quebra com espaço em padrão.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `find "$P" $(forge_find_prune) -name package.json -print | grep -cE 'node_modules|vendor'`, esperado 0; e contagem de invocadores, esperado ≥1. Hoje:

```
  podados errado (node_modules|vendor listados): 2
  invocadores da lib no template: 0
```

Gate que fica: `tests/w<NNN>-scan-exclude-prune-gate.sh`, com `src/package.json` listado (positiva) e os podados ausentes, sob `bash` explícito. Propriedade PBT: para subconjuntos gerados de `FORGE_SCAN_EXCLUDE` materializados como diretórios (incluindo o último da lista e padrões com glob), nenhum arquivo sob diretório excluído é listado e todo arquivo fora deles é. Mutação: recolocar `-false` faz `vendor` reaparecer.

Arquivos: `template/.forge/scripts/lib/scan-exclude.sh`, o invocador escolhido, gate novo, README, CHANGELOG.

### #153 — copiar `.forge` de outro consumidor é upgrade disfarçado sem aviso

**#153** · Closes #153 · gate novo: não (amplia `tests/w191-doctor-orphan-gate-gate.sh`)

Causa raiz: `template/.forge/commands/harness/upgrade.md:65-66` não trata cópia entre consumidores, e `template/.forge/scripts/doctor.sh:448-521` detecta só `check-*.sh` órfão (entregue por `d7d4ad4` e `6dd3952`), não lib sem invocador nem divergência entre `template_version` e a versão dos hooks.

Desenho: o doctor ganha duas linhas `!`: lib em `scripts/lib/` que nenhum script, hook ou lib sourceia ou importa, nomeada; e `forge.yaml template_version` diferente da versão gravada no cabeçalho de `machinery.lock`. `upgrade.md` ganha a seção "copiar .forge de outro repositório é upgrade parcial". Alternativa descartada: recusar a execução do doctor com divergência, que tira o diagnóstico justamente de quem precisa dele.

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): `.forge/scripts/lib/zz-orfa.sh` sem invocador; `doctor.sh | grep -c zz-orfa`, esperado ≥1. Hoje:

```
  menções a zz-orfa no doctor: 0
```

Gate que fica: cenários novos no w191 — lib órfã nomeada (positiva), lib sourceada não nomeada (contrafactual), versão divergente gera `!`. Deve rodar depois do PR da #149, que dá invocador à `scan-exclude.sh`. Propriedade PBT: não se aplica. Mutação: remover a varredura de libs faz o cenário órfão dar 0.

Arquivos: `template/.forge/scripts/doctor.sh`, `template/.forge/commands/harness/upgrade.md` (+ plugin), `tests/w191-doctor-orphan-gate-gate.sh`, CHANGELOG.

**DoD da Onda 4:** cada cenário que hoje termina verde sem medir passa a terminar com uma saída nominal que só existe depois da correção — "leitor devolveu ZERO" no pre-push com lib antiga, AVISO .NET, `not-possible` com padrão nulo, reprovação de `feature` com `fixes_defects` sem evidência, `head_sha` do `--root` do chamador, recusa de flag engolida, recusa de `resolve` repetido citando o carimbo, WARN de cursor, contagem de não publicadas, prefixo de blob igual ao `shasum`, `src/package.json` listado sem os podados, e lib órfã nomeada pelo doctor — e cada um tem o contrafactual de uso legítimo em rc 0 no mesmo gate.

## Onda 5 — prosa, contrato de agente e interface

### #126 — o cabeçalho do `_common.sh` diz que `behind` é recusado e o código une

**#126** · Closes #126 · gate novo: sim

Causa raiz: `template/.forge/scripts/lib/transports/_common.sh:19-20` ("recusar é a única saída — inclusive sob reparo") entrou em `d7d4ad4`; o `case 1` de `:158-170` passou a unir em `a86fdd7` e o cabeçalho não acompanhou.

Desenho, reaproveitando L6 D (§1.4): o cabeçalho vira a tabela de desfechos (`ff`, `behind` une, `diverged` recusa, `equal` no-op) e um gate executa os quatro casos e confronta cada desfecho com a linha da tabela. Alternativa descartada: só editar a frase, que deixa a próxima divergência sem detector.

Vermelho, executado: `grep -c 'recusar é a única saída — inclusive sob reparo' template/.forge/scripts/lib/transports/_common.sh`, esperado 0 com a linha de `behind` dizendo "une". Hoje: `1`.

Gate que fica: `tests/w<NNN>-transport-contract-coherence-gate.sh`: para cada linha da tabela, o caso executado produz o rc e o token declarados (positiva: `behind` rc 0 com `liaison-push-union` e hub preservado). Propriedade PBT: não se aplica; quatro desfechos exaustivos. Mutação: trocar "une" por "recusa" na linha de `behind` faz o confronto falhar; mudar o `case 1` para `return 1` também.

Arquivos: `template/.forge/scripts/lib/transports/_common.sh` (só comentário), gate novo, README, CHANGELOG.

### #136 — `--help` cai no ramo de comando desconhecido

**#136** · Closes #136 · gate novo: não (amplia o gate de superfície de argumento criado pelo PR da #133)

Causa raiz: os dispatchers não tratam `--help`/`-h`: `template/.forge/scripts/liaison-ops.sh:1295`, `ledger-ops.sh:600`, `wave-ops.sh:224` e `deferral-ops.sh:153` caem em "comando desconhecido" ou mostram usage pelo ramo de erro, rc 1; `red-evidence.sh:105` idem.

Desenho: `-h|--help|help` como primeiro argumento imprime o usage em stdout com rc 0; comando inválido continua rc 1 em stderr. O universo é derivado (todo `template/.forge/scripts/*-ops.sh` mais `red-evidence.sh`), não escrito à mão; L4 §2.2 alargou para 14 scripts e este plano mantém o universo da issue mais o predicado derivado, a medir no PR. Precedente interno: `run-all.sh:29`. Alternativa descartada: usage em stderr com rc 0, que quebra `script --help | grep`.

Vermelho, executado: `bash template/.forge/scripts/liaison-ops.sh --help; echo rc=$?`, esperado rc 0 com `Usage`. Hoje:

```
liaison-ops --help rc=1 FAIL: comando desconhecido '--help'
ledger-ops --help rc=1 FAIL: comando desconhecido '--help'
```

Gate que fica: cenários novos no gate de superfície de argumento — para cada script do universo, `--help` e `-h` rc 0 com `Usage` em stdout (positiva) e `comando-que-nao-existe` rc 1 (contrafactual). Propriedade PBT: a própria varredura sobre o universo derivado. Mutação: remover o ramo de help de um script faz a linha daquele script falhar.

Arquivos: os cinco scripts, o gate da #133, CHANGELOG.

### #145 — `/forge:pentest scan` não alcança o toolchain do consumidor

**#145** · Closes #145 · gate novo: sim

Causa raiz: três defeitos em `template/.forge/scripts/pentest-ops.sh`: nome fixo `PENTEST_IMAGE="forge-pentest"` (`:26`), tag `:latest` em nove sítios (`:180-181`, `:221-233`, `:261`, `:281`) e `docker run ... pentest-scan` (`:257-262`) sem contrato escrito nem diagnóstico.

Desenho, reaproveitando L6 §4.3 com fallback: precedência `image:` do `docker-compose.yml` em `tool_dir` > `runtime.pentest.image` > `forge-pentest:latest`; o fallback final imprime `WARN: tag latest (proibida pelas rules) — declare runtime.pentest.image`; antes de `scan`, `docker run --entrypoint sh <img> -c 'command -v pentest-scan'` e, se ausente, rc 4 com `FAIL: a imagem <img> não expõe pentest-scan <apk> <outdir> (contrato em commands/waves/pentest.md)`. O contrato do entrypoint é documentado. Alternativa descartada: trocar o default para uma tag versionada, que declara "não buildado" em toda imagem já construída pelos consumidores. Pergunta ao dono: quando remover o fallback `latest`, e se o harness entrega o binário `pentest-scan` em vez de só o contrato.

Vermelho, executado (`/tmp/fh-A-145.sh`, docker por stub): compose declara `axis/pentest:dev`; esperado `status` inspecionando essa referência e `scan` rc 4 nomeando `pentest-scan`. Hoje:

```
  docker image inspect forge-pentest:latest
exec: pentest-scan: not found
FAIL pentest:scan — workflow estático falhou
```

Gate que fica: `tests/w<NNN>-pentest-image-contract-gate.sh`, com stub de docker: compose > runtime > fallback com WARN; imagem com `pentest-scan` roda o scan (contrafactual). Revalidar w142 e w206. Propriedade PBT: para combinações geradas das três fontes presentes ou ausentes, a imagem inspecionada é sempre a de maior precedência presente. Mutação: remover a leitura do compose faz o cenário 1 inspecionar `forge-pentest:latest`.

Arquivos: `template/.forge/scripts/pentest-ops.sh`, `template/.forge/commands/waves/pentest.md` (+ plugin), gate novo, README, CHANGELOG.

### #140 — a receita A4 não distingue controle domado de não domado

**#140** · Refs #140 · gate novo: não (amplia `tests/w96-frontend-ui-review-gate.sh`)

O script que reprova (`check-frontend-design-system.sh`) não existe no template (0 arquivos em `template/.forge/scripts`, `log -S native-control` vazio); é gate local do azim-crm. O que o produtor entrega e reproduz: a receita A4 em `template/.forge/skills/frontend-ui-review/SKILL.md:81-91` casa `type="color"` qualquer que seja o CSS irmão, poder discriminante zero.

Desenho, reaproveitando L6 §3.3: A4 vira scanner determinístico advisory (`scripts/scan-native-controls.py` da skill) que reconhece os dois escapes da regra 12 de `rules/frontend/design-system.md:37` — pseudo-elemento domado no CSS do componente ou encapsulamento em componente do DS — e imprime `OK` para eles. Fica `Refs`: a metade bloqueante da issue mora no consumidor. Alternativa descartada: trazer o gate do azim-crm para o template, que é pergunta ao dono (aceitar o PR oferecido, e se o A4 bloqueia ou avisa).

Vermelho, executado (`/tmp/fh-R02-Bmisc.sh`): mesmo `<input type="color">`, um com `::-webkit-color-swatch` no CSS irmão e outro sem; esperado desfechos diferentes. Hoje:

```
  domado: WARN controles nativos
  cru: WARN controles nativos
```

Gate que fica: cenários novos no w96, domado `OK` (positiva) e cru `WARN` (contrafactual). Propriedade PBT: para combinações geradas de tipo de controle × presença do pseudo-elemento correto × encapsulamento, o veredito é `OK` se e somente se um dos dois escapes está presente para aquele tipo. Mutação: ignorar o CSS irmão faz o caso domado dar `WARN`.

Arquivos: `template/.forge/skills/frontend-ui-review/SKILL.md`, `template/.forge/skills/frontend-ui-review/scripts/scan-native-controls.py` (novo), `tests/w96-frontend-ui-review-gate.sh`, CHANGELOG.

### #151 — `change-test-contract` manda direto para "evidência pendente"

**#151** · Closes #151 · gate novo: não (amplia `tests/w197-normative-text-parity-gate.sh`)

Causa raiz: `template/.forge/rules/testing/change-test-contract.md:19` oferece uma única saída ("registrar explicitamente a evidência pendente") para nível de teste que não pode rodar. Premissa em remedição: a ficha A mediu 1 de 7 repositórios com a rule instalada que a estendem (azim-crm), não "consumidores" no plural; o dado é provisório até a remedição do orquestrador, e o desenho não depende dele.

Desenho: a regra passa a ordenar três saídas — criar o objeto (harness real e descartável), reescrever o critério com registro de quem decidiu, e só então pendência declarada — e o relatório de `/forge:verify` passa a marcar nível pendente com token distinto de verificado. Alternativa descartada: manter a saída única e só acrescentar exemplo, que não muda a ordem de decisão. Pergunta ao dono: reescrever o critério é prerrogativa exclusiva do dono da spec?

Vermelho, executado: `grep -ciE 'criar o objeto|harness real e descart' template/.forge/rules/testing/change-test-contract.md`, esperado ≥1 com as três saídas em ordem. Hoje: `0`. A metade de `/forge:verify`: vermelho NÃO executado — exige fixture de verify com nível pendente que ainda não existe; o implementador a escreve e observa as duas linhas iguais antes de corrigir.

Gate que fica: cenário novo no w197, que já confronta texto normativo: as três saídas presentes na ordem declarada (positiva por posição de linha). Propriedade PBT: não se aplica. Mutação: inverter a ordem das saídas faz o confronto de posição falhar.

Arquivos: `template/.forge/rules/testing/change-test-contract.md`, o comando ou template do relatório de verify, `tests/w197-normative-text-parity-gate.sh`, CHANGELOG.

### #152 — `security-reviewer` sem checagem de proveniência

**#152** · Closes #152 · gate novo: sim

Causa raiz: `template/.forge/agents/review/security-reviewer.md` cobre RBAC e IDOR (`:21`, `:159`) e não tem passo que pergunte quem escreve o campo usado na decisão de autorização, nem que percorra registros filhos.

Desenho: passo novo no pipeline do agente — para todo campo lido numa decisão de autorização ou proveniência, identificar o escritor; campo escrito pelo próprio verificado (ex.: `payload.runId`) sem ancoragem server-side é BLOCKER, e o passo percorre os registros filhos. Eval em `template/.forge/evals/` com a fixture `payload.runId` esperando BLOCKER. Alternativa descartada: só gate estático de texto, que prova a presença da frase e não o comportamento do agente.

Vermelho, executado: `grep -ciE 'proveni|quem escreve' template/.forge/agents/review/security-reviewer.md`, esperado ≥1. Hoje: `0` (controle positivo `grep -c IDOR` → `2`). O vermelho comportamental do eval: NÃO executado — exige rodar o agente LLM, fora do escopo determinístico desta rodada.

Gate que fica: `tests/w<NNN>-security-reviewer-provenance-gate.sh` (estático: passo presente e referenciado no checklist de saída) mais o caso de eval registrado no harness de evals. Propriedade PBT: não se aplica. Mutação: remover o passo faz o gate estático falhar.

Arquivos: `template/.forge/agents/review/security-reviewer.md`, `template/.forge/evals/` (caso novo), gate novo, README, CHANGELOG.

**DoD da Onda 5:** o gate de coerência executa os quatro desfechos do push e todos batem com o cabeçalho; `--help` sai rc 0 com usage em todo script do universo derivado e comando inválido continua rc 1; `pentest scan` contra imagem sem entrypoint sai rc 4 nomeando o binário e imagem com entrypoint roda; a receita A4 dá `OK` para controle domado e `WARN` para cru; a rule de testes lista as três saídas em ordem; e o `security-reviewer` tem o passo de proveniência referenciado no checklist, com o eval registrado e o seu vermelho declarado como não executado.

## Onda 6 — fora do escopo desta rodada

Nenhuma das 26 entradas não encerradas é a mesma causa raiz de uma das 36 issues; as vizinhas estão marcadas com o motivo de não entrarem na onda da issue. Esta rodada não edita `.forge/ledger/ledger.json`.

- **LDG-0008** — roadmap de enforcement de TDD e PBT; pede change SDD próprio e não tem issue aberta.
- **LDG-0010** — promoção do SRF-01 bloqueada por LDG-0162; sem dano a consumidor medido nesta rodada.
- **LDG-0021** — a prova de mutação mede regras e não superfície de entrada; change SDD próprio.
- **LDG-0029** — universo do route-scan; roadmap da Onda G, sem issue aberta.
- **LDG-0065** — enforcement mecânico de Java e Python; roadmap de packs.
- **LDG-0100** — acks não leem hub em git/gh; zero exposição (todo canal medido usa `fs`) e condição de reabertura registrada.
- **LDG-0140** — segunda metade do harvest; dívida interna do `ledger-ops`, sem dano a terceiro.
- **LDG-0151** — chaves de schema sem leitor que prometem default; decisão por chave em change próprio.
- **LDG-0152** — `fm_field` triplicado; consolidar tocaria o `pre-push`, que esta rodada já disputa em seis PRs.
- **LDG-0153** — doctor não informa divergência do `_common.sh`; requisito nascido da #101, mas no doctor, não no ramo do overlay (`bin/forge.mjs:623-633`), logo não é a mesma causa raiz.
- **LDG-0157** — falso positivo de atribuição de IA sem `node`; outro script, sem issue.
- **LDG-0158** — `gate-ordinal.sh next` resolve remoto pelo CWD; ferramenta interna de ordinal.
- **LDG-0160** — fases pre-deploy e post-deploy sem executor; depende do `deploy.sh` da Onda K.
- **LDG-0161** — duas cópias divergentes do `FORGE.md` de scaffold; dívida de scaffold sem issue.
- **LDG-0162** — `MapGroup()` não ancorado no route-scan; Onda G.
- **LDG-0163** — o detail declara resolvido no commit da união; fechar o status é reconciliação de ledger, que esta rodada não faz.
- **LDG-0164** — mutação malformada do w195[11]; dívida da suíte interna.
- **LDG-0167** — ordinal e id de ledger reservados em duplicidade; processo de reserva do orquestrador.
- **LDG-0171** — padrão `SCRIPT_DIR/../..` em 34 sítios; refatoração interna.
- **LDG-0173** — `gate-ordinal next` só lê `origin/develop`; processo interno.
- **LDG-0175** — gate destrói arquivo rastreado do template como fixture; suíte interna, não causa de issue.
- **LDG-0176** — `graph.json` commitado defasado; artefato interno.
- **LDG-0178** — dois esquemas de `hooks.manifest`; é a pergunta ao dono da #125, não a causa do desarme medido.
- **LDG-0180** — runner interno colapsa "reprovou" e "morto"; vizinho da #135 com mecanismo distinto.
- **LDG-0181** — runner do template com dois desfechos; vizinho da #135, cujo anúncio de nome não altera desfechos.
- **LDG-0182** — guarda anti-recursão do w80 morto; suíte interna.

**DoD da Onda 6:** o placar reconcilia as 26 entradas nesta onda sem órfão nem fantasma, e nenhuma delas muda de status por efeito desta rodada — a positiva é a linha `✓ todo item aberto está em exatamente uma onda` na saída de `node tools/plan-progress.mjs`.

## Fechamento de issue já corrigida

Nenhuma das 36 issues está corrigida em título e corpo inteiros, e por isso não há onda de fechamento (uma onda sem item faz o placar sair rc 2). A mais próxima é a #103: o título foi corrigido por `f824165` (PR #114) e `ledger-ops.sh add --type roadmap --title --detail` sai rc 1 com mensagem nominal, mas o resíduo de `resolve` repetido reproduz e está na Onda 4. A #140 não reproduz no produtor (o script bloqueante nunca existiu no template), mas a receita A4 do template reproduz a falta de discriminação e está na Onda 5.

## Decisão do dono

Pelo critério desta rodada — só vai para uma onda de decisão a issue em que toda correção viável quebre contrato com consumidor, remova chave de schema ou mude semântica de reconciliação — nenhuma das 36 se qualifica, e por isso não existe onda de decisão. Cada issue com decisão pendente tem uma correção retrocompatível planejada e a pergunta escrita na própria seção. As perguntas com custo medido que mais pesam:

| Issue | Pergunta | Custo medido do lado forte |
|---|---|---|
| #123 | recomendar `fs-union` aos consumidores | 176 worktrees em quatro consumidores têm leitor sem o kind e param de sincronizar até atualizar; 146 delas têm `_common.sh` sem `_dir_push_union` |
| #125 | esquema canônico da camada do consumidor (LDG-0178) | dois esquemas incompatíveis em produção (5 campos no axis-fare-validator, 4 no Axis.PadSimulator) |
| #101/#131 | parar o update em exceção expirada; preservar `scripts/` por deriva | L1 mediu 5 de 6 árvores com `pre-push` divergente do lock, que seria preservado e deixaria de receber correção |
| #137 | teto de posse ligado por padrão | com o default derivado, todo consumidor passa a ter dono vivo encerrado depois de 900 s de posse |
| #142 | nome default do recurso | axis-fare-validator declara `axis-heavy-suite` e axis-go-cloud `forge-heavy-suite`; trocar o default reparticiona quem está no default |

## Ordem de merge

Pares de PR que tocam o mesmo arquivo de maquinaria, na ordem em que devem entrar; o segundo de cada par é revalidado contra a base que já contém o primeiro.

| Arquivo | Ordem | Por quê |
|---|---|---|
| `bin/forge.mjs` | #101/#131 → #142 | as linhas `SOBRESCRITO` e o leitor de exceções nascem no primeiro; a mensagem de merge da #142 fica no relatório que o primeiro já reformata. A #125 não edita `bin/forge.mjs` (seus arquivos são `sync-adapters.mjs` e os hooks de `pre-tool-use/`) — sua dependência de #101/#131 é de ordem, não de arquivo comum, e está na seção de dependências de ordem abaixo |
| `template/.forge/scripts/lib/sync-adapters.mjs` | #130 → #125 | a #125 importa a função exportada pela guarda de principal; sem ela, o gate da #125 reconcilia a fixture ao importar |
| `template/.forge/hooks/git/pre-push` | #132/#134 → #135 → #141 → #144/#137 → #119 → #106 | o curto-circuito de deleção antecede `run_check`, que a #135 reescreve; a #141 muda a resolução dos sítios delegados que a #144 e a #119 editam em volta; a #106 acrescenta o aviso ao lado da linha `:325` já estável |
| `template/.forge/scripts/liaison-ops.sh` | #117 → #108 → #109 → #133 → #136 | do trecho mais baixo e isolado (`:298`) para o dispatcher (`:1295`), que a #136 reescreve. A #123 não edita `liaison-ops.sh` (seus arquivos são `liaison-config.mjs`, `transports/` e o schema) — sua dependência de rodar depois de #133 é de ordem, não de arquivo comum, e está na seção de dependências de ordem abaixo |
| `template/.forge/scripts/deferral-ops.sh` | #133 → #136 | o laço de recusa em `status` e `test` precisa existir antes do ramo de help no dispatcher |
| `template/.forge/scripts/ledger-ops.sh` | #103 → #136 | a recusa de `resolve` repetido é local; o help reescreve o dispatcher |
| `template/.forge/scripts/red-evidence.sh`, `lib/red-evidence-ops.mjs`, `lib/check-red-first.mjs` | #139 → #138 → #136 | a #138 itera `entries` criadas pela #139; o help da #136 toca o dispatcher de `red-evidence.sh` |
| `template/.forge/scripts/lib/red-replay.mjs` e `schemas/red-evidence.schema.json` | #139 → #150 | os dois acrescentam propriedades ao mesmo schema estrito |
| `template/.forge/scripts/doctor.sh` | #127 → #108 → #149 → #153 → #142 | universo de varredura primeiro; a lib órfã da #153 é medida depois que a #149 dá invocador à `scan-exclude.sh`; a linha do recurso da #142 entra no bloco `HEAVY-MUTEX` por último |
| `template/.forge/scripts/lib/transports/` | #126 → #109 → #123 | cabeçalho alinhado antes de o retorno do push (#109) e o roteamento do kind (#123) editarem o mesmo diretório |
| `README.md` (badge `gates-N`) | ordem de merge de todos os PRs com gate novo | o w200 exige a igualdade no mesmo commit; cada PR recalcula o badge contra a base em que entra |

## Dependências de ordem sem arquivo compartilhado

Pares que precisam entrar nesta ordem, mas não editam o mesmo arquivo — por isso não estão na tabela "Ordem de merge", que é só para pares com arquivo literal em comum.

| Depende de | Deve entrar depois | Por quê |
|---|---|---|
| #144/#137 | #146 | a #146 confere a armação de trap que o laço de aquisição reformado por #144/#137 continua chamando (`heavy-mutex.sh:790`), mas #146 só edita `heavy-run.sh` — não toca `heavy-mutex.sh` |
| #133 | #123 | a #123 toca `transport set` depois de #133 alcançar `--kind` com a guarda de flag-como-valor, mas #123 só edita `liaison-config.mjs`, `transports/` e o schema — não toca `liaison-ops.sh` |

## Tabela de ordinais

Uma linha por issue que ganha gate novo. O orquestrador preenche o ordinal contra `origin/*` e as branches em voo.

| Issue | Gate (slug provisório) | Ordinal |
|---|---|---|
| #101 | update-exceptions (mesmo gate da #131) | a reservar |
| #131 | update-exceptions (mesmo gate da #101) | a reservar |
| #125 | hook-wiring-derived | a reservar |
| #130 | module-import-side-effect | a reservar |
| #142 | heavy-mutex-partition | a reservar |
| #139 | red-evidence-entries | a reservar |
| #107 | liaison-blob-recovery | a reservar |
| #123 | liaison-fs-union | a reservar |
| #144 | heavy-mutex-posse (mesmo gate da #137) | a reservar |
| #137 | heavy-mutex-posse (mesmo gate da #144) | a reservar |
| #146 | heavy-run-signal-disposition | a reservar |
| #141 | delegacao-arvore-do-hook | a reservar |
| #132 | prepush-delecao-pura (mesmo gate da #134) | a reservar |
| #134 | prepush-delecao-pura (mesmo gate da #132) | a reservar |
| #135 | prepush-teto-de-check | a reservar |
| #127 | doctor-scan-universe | a reservar |
| #129 | naming-path-provenance | a reservar |
| #106 | prepush-cobertura-dotnet | a reservar |
| #138 | red-defect-scope | a reservar |
| #128 | run-manifest-root | a reservar |
| #133 | arg-surface | a reservar |
| #108 | liaison-diagnostico-mudo | a reservar |
| #109 | liaison-outbox-watermark | a reservar |
| #149 | scan-exclude-prune | a reservar |
| #126 | transport-contract-coherence | a reservar |
| #145 | pentest-image-contract | a reservar |
| #152 | security-reviewer-provenance | a reservar |

São 27 linhas e 24 gates distintos. As outras nove issues (#120, #119, #150, #103, #117, #153, #136, #140, #151) ampliam gates existentes.

## O que faz o placar sair com rc diferente de zero

Lido em `tools/plan-progress.mjs`. Sai rc 2 em: erro de uso (argumento desconhecido ou flag sem valor); plano inexistente; nenhuma seção `## Onda N — título`; onda sem item extraído; `--wave` com onda inexistente; item em duas ondas; ledger com JSON ilegível; `--universe` ausente ou ilegível. Sai rc 1 em: ledger não medido (arquivo ausente ou zero entradas); reconciliação com órfão (item aberto no repositório fora do plano) ou fantasma (item do plano inexistente no universo); ou rede ligada com `gh issue list` falhando. Não mudam o rc: ondas não entregues e itens abertos (o placar só conta), onda sem `**DoD` (só imprime aviso), entradas de ledger com status nulo ou `resolved` sem carimbo (só imprime `✗` na seção de integridade), `--help` (rc 0) e `--no-network`, que declara a cegueira e pula a reconciliação de issues sem rc 1.

## Decisões que o brief não cobriu

1. #101 e #131 num PR só, com a #125 em PR separado que depende dele: as três passam por `bin/forge.mjs:623-633`, mas a #125 tem duas causas próprias (`sync-adapters.mjs:233` e o contrato argv do gancho) e depende também da #130.
2. #138 e #139 em PRs separados, com ordem declarada, contra a sugestão da triagem de desenhá-las juntas: os loci são distintos e L5 continua valendo como desenho único executado em dois passos.
3. Desvios em relação aos spikes para ficar retrocompatível: exceção expirada preserva em vez de parar (L1 D3), teto de posse opt-in em vez de derivado (L2 D3), backup em vez de recusa no handoff, fallback `latest` com WARN no pentest.
4. Nenhuma onda de decisão e nenhuma onda de fechamento, porque nenhuma issue atende aos critérios e uma onda vazia faz o placar sair rc 2; as duas viraram seções sem "Onda".
5. #123 saiu da decisão do dono: o kind `fs-union` é aditivo e opt-in, e a leitura antiga já recusa kind desconhecido (`liaison-config.mjs:86`), medido.
6. #117 é retrocompatível por medição: nenhum leitor recalcula o nome do blob (`BODY_REF_RE` só confere padrão).
7. #136 amplia o gate criado pela #133 em vez de ganhar gate próprio, o que prende a ordem de merge entre as duas.
8. Nenhuma entrada de ledger entrou na onda de uma issue; LDG-0153, LDG-0178 e LDG-0181 são vizinhas com locus distinto.
