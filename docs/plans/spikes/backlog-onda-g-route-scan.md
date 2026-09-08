# Onda G — route-scan e cobertura de superfície

Especificação implementável. Insumo: `docs/plans/2026-09-07-backlog-zero.md`, seções "Invariantes", "Definição de pronto do plano inteiro" e "Onda G". Endereça LDG-0029, LDG-0162 e LDG-0010.

**Revisão 2.** A revisão 1 foi reprovada por dois defeitos de prova de mutação e por um conjunto de medições que o revisor não conseguiu reproduzir. As respostas item a item estão na seção 13; a varredura das cinco armadilhas sobre o documento inteiro está na seção 14.

Data das medições desta revisão: 2026-09-07. Árvore do harness: `/Users/milton/Documents/projects/forge-harness`, branch `develop`, commit `3bb67f5`. Repositório de referência: `/Users/milton/Documents/projects/axis-go-cloud`, commit `721fc7ec5`, **leitura apenas**, nenhuma escrita de nenhuma natureza.

**A regra de prova deste documento, depois da revisão 1.** Toda afirmação numérica vem com o comando que a produz, colado ao lado dela, para que o próximo revisor a reproduza sem adivinhar. E todo número que conta algo da árvore — arquivos, changes, nodes, diretórios — é **testemunha de data e nunca critério**: ele dimensiona o trabalho e não entra em asserção nenhuma; a asserção correspondente é sempre propriedade mais piso. A seção 14 lista, uma a uma, qual é qual.

Nenhum gate da suíte foi executado na produção desta especificação — a suíte não tolera concorrência (`feedback-suite-sem-concorrencia`). As reproduções usaram bancada em `$TMPDIR`, com cópia da `lib/` de produção, e nenhum arquivo rastreado do harness ou dos consumidores foi editado.

## 0. A bancada, e como reconstruí-la

Todos os comandos deste documento pressupõem a bancada abaixo, montada em `$TMPDIR` e descartável. `lib-prod` é a cópia intocada da biblioteca de produção; `lib-proto` é a mesma cópia com as duas correções da onda prototipadas.

```
B=$TMPDIR/ondaG; H=/Users/milton/Documents/projects/forge-harness
rm -rf $B; mkdir -p $B
cp -R $H/template/.forge/scripts/lib $B/lib-prod
cp -R $H/template/.forge/scripts/lib $B/lib-proto
```

O protótipo aplica três mudanças em `lib-proto`, e são exatamente as três que a onda propõe:

```
# 1. route-scan.mjs:411 — CHAIN tolera elo não-rota DEPOIS de cada MapGroup
const LINK = '(?:\\s*\\.\\s*(?!Map[A-Z])\\w+\\s*\\(\\s*[^()]*?\\s*\\))';
const CHAIN = '(?:\\s*\\.\\s*MapGroup\\s*\\(\\s*[^)]*?\\s*\\)' + LINK + '*)+';

# 2. source-scan.mjs — collect() ganha pruneForeign (default false) e o gancho onPrune
#    foreign(dir, name): nome que começa com '.forge.bak' -> 'backup-de-update'
#                        existsSync(join(dir, name, '.git')) -> 'repositorio-aninhado'
#    a regra vale para DESCENDENTES; a raiz recebida nunca é testada

# 3. route-scan.mjs — scanRoutes() liga pruneForeign, acumula em `skipped` e o devolve
const skipped = [];
const onPrune = ({ motivo, dir }) => { ... skipped.push({ motivo, dir: relativo }) };
const files = [...new Set(collect(paths, { exts, skipDirs, pruneForeign: true, onPrune }))];
return { routes: deduped, unresolved, skipped };
```

O `(?!Map[A-Z])` impede que o elo engula o próprio verbo; o `[^()]*?` recusa argumento com parênteses aninhados (lambda) e o `\w+` recusa argumento de tipo genérico — as duas fronteiras que a seção 4.4 mede e que a seção 6 usa como eixo de mutação.

Três drivers de bancada são citados repetidamente e ficam declarados aqui de uma vez.

`$B/scan.mjs` — varredura completa de uma raiz, com a partição por subárvore e por `kind`:

```javascript
const libdir = process.argv[2]; const raiz = process.argv[3];
const { scanRoutes } = await import(libdir + '/route-scan.mjs');
const t0 = Date.now(); const r = scanRoutes([raiz], { root: raiz }); const ms = Date.now() - t0;
const dentro = r.unresolved.filter((u) => String(u.file).startsWith('axis-device-platform')).length;
const porKind = {}; for (const u of r.unresolved) porKind[u.kind] = (porKind[u.kind] || 0) + 1;
console.log(JSON.stringify({ ms, routes: r.routes.length, unresolved: r.unresolved.length,
  dentroDeviceplatform: dentro, foraDeviceplatform: r.unresolved.length - dentro, porKind,
  skipped: (r.skipped || []).length }, null, 2));
```

`$B/fxrun.mjs` — uma fixture de bancada contra uma biblioteca, imprimindo rotas e `kind` distintos:

```javascript
const [lib, dir] = process.argv.slice(2);
const { scanRoutes } = await import(lib + '/route-scan.mjs');
const r = scanRoutes([dir], { root: dir });
const kinds = [...new Set(r.unresolved.map((u) => u.kind))].sort();
console.log('  rotas: ' + (r.routes.map((x) => x.method + ' ' + x.path).join(' | ') || '(nenhuma)'));
console.log('  kinds: ' + (kinds.join(', ') || '(nenhum)'));
```

`$B/podarun.mjs` — o mesmo, mas imprimindo o terceiro campo em vez dos `kind`:

```javascript
const [lib, dir] = process.argv.slice(2);
const { scanRoutes } = await import(lib + '/route-scan.mjs');
const r = scanRoutes([dir], { root: dir });
console.log('  rotas: ' + (r.routes.map((x) => x.method + ' ' + x.path).join(' | ') || '(nenhuma)'));
console.log('  skipped: ' + (r.skipped === undefined ? '(o campo não existe no objeto devolvido)'
  : (r.skipped.length ? r.skipped.map((s) => s.motivo + ' ' + s.dir).join(' | ') : '[] (vazio)')));
```

Rigor **reduzido** por decisão do dono: três rodadas de revisão.

---

## 1. O veredito da onda, antes de tudo

A onda tem três itens e **dois desfechos diferentes**, e dizer isso na primeira página é o ponto do documento.

| Item | Desfecho proposto | Por quê, em uma linha |
|---|---|---|
| LDG-0029 | **resolved** | A remedição confirma a partição registrada, o índice de constante literal tem alvo zero medido, e o que sobra — pular a subárvore alheia — é implementável e testável nesta onda. |
| LDG-0162 | **resolved** | O defeito reproduz, a correção foi prototipada e medida, e com ela o repositório de referência vai a **zero irresolúveis**. |
| LDG-0010 | **wont-fix recomendado**, com condição de reabertura escrita | O bloqueio nomeado pelo ledger cai nesta onda, mas a remedição encontrou um **segundo** bloqueio que o ledger nunca teve: promover o SRF-01 a bloqueante hoje reprovaria 4 dos 16 changes ativos do parque que têm `requirements.md`, com um oráculo que a própria descrição do item chama de heurística. |

O aviso de escopo do plano-mestre — *"se resistir, o desfecho honesto é `wont-fix` com a medição, não um `resolved` fabricado"* — se aplica a **um** dos três itens, não aos três. Os dois primeiros fecham com entrega real; o terceiro fecha por decisão do dono sobre a medição da seção 9.

---

## 2. Método, e o que a bancada podia e não podia fazer

Três instrumentos, todos executados por mim nesta rodada:

1. **Varredura do oráculo real sobre o repositório de referência**, importando `template/.forge/scripts/lib/route-scan.mjs` do harness e chamando `scanRoutes([raiz], { root: raiz })`. É o mesmo código que a suíte exercita, sem intermediário.
2. **Cópia da `lib/` para `$TMPDIR`**, com as duas correções prototipadas, e a mesma varredura repetida. Todo par "antes/depois" deste documento é literalmente o mesmo comando contra duas cópias da mesma biblioteca.
3. **Bancadas de fixture** em `$TMPDIR`, reproduzindo os idiomas medidos no repositório de referência em arquivos de dez linhas, que é a forma que os cenários de gate precisam ter — o gate **não pode** depender de um repositório externo, e a seção 5 volta a esse ponto.

O que a bancada **não** podia fazer, dito em letra: nada foi escrito em `axis-go-cloud` nem em nenhum outro consumidor; nenhum gate da suíte foi executado; e a árvore de trabalho do repositório de referência é **viva**, de modo que contagens absolutas dela variam entre execuções.

A prova disso está na própria história deste documento. O universo de código do repositório de referência mediu 10.323 arquivos na primeira passada, 10.324 na segunda, e **10.325** hoje:

```
$ node $B/universo-ref.mjs $B/lib-prod /Users/milton/Documents/projects/axis-go-cloud
{"universo":10325,"emAxisDevicePlatform":1429,"emForgeBak":191,"nosDois":54,"uniao":1566}
```

```javascript
// $B/universo-ref.mjs
const lib = process.argv[2], raiz = process.argv[3];
const { collect } = await import(lib + '/source-scan.mjs');
const EXTS = new Set(['.cs', '.java', '.kt', '.ts', '.js', '.mjs', '.py', '.go']);
const files = collect([raiz], { exts: EXTS }).map((f) => f.slice(raiz.length + 1));
const dev = files.filter((f) => f.startsWith('axis-device-platform/'));
const bak = files.filter((f) => f.split('/').some((s) => s.startsWith('.forge.bak')));
const ambos = dev.filter((f) => f.split('/').some((s) => s.startsWith('.forge.bak')));
console.log(JSON.stringify({ universo: files.length, emAxisDevicePlatform: dev.length,
  emForgeBak: bak.length, nosDois: ambos.length, uniao: dev.length + bak.length - ambos.length }));
```

Três medições do mesmo comando, três números, nenhum defeito: é a invariante 14 aplicada a um corpus externo, e a razão de **nenhum número deste documento virar literal de asserção em gate**. A seção 5 constrói os cenários sobre fixtures próprias justamente por isso.

---

## 3. LDG-0029 — o universo da varredura

### 3.1 A remedição, e o que ela faz com a partição registrada

O ledger registra que a partição 69/8 "foi recomputada sobre saída de terceiro, NÃO regenerada", e manda remedir antes de decidir. Remedi, com o oráculo real:

```
$ node $B/scan.mjs $B/lib-prod /Users/milton/Documents/projects/axis-go-cloud
{
  "ms": 326185,
  "routes": 373,
  "unresolved": 77,
  "dentroDeviceplatform": 69,
  "foraDeviceplatform": 8,
  "porKind": {
    "route-path-not-literal": 23,
    "route-prefix-unresolved": 1,
    "group-path-not-literal": 32,
    "mapgroup-unindexed": 5,
    "route-site-unindexed": 5,
    "producer-never-invoked": 11
  },
  "skipped": 0
}
```

**A partição registrada está CONFIRMADA pela regeneração: 77 irresolúveis, 69 de `axis-device-platform` e 8 do repositório de referência.** O ledger diz "se a remedição não a confirmar, o índice de constante volta à mesa" — a remedição confirma, e o índice não volta.

O campo `ms` do bloco acima é ruído e está aqui só porque o driver o imprime: **nenhuma afirmação deste documento depende dele**, e a seção 4.3 mostra as quatro medições independentes que provam por que.

E confirma o resto do registro no mesmo passo. Restringindo a saída aos quatro arquivos que estão **fora** da subárvore alheia:

```
$ node $B/quatro.mjs $B/lib-prod \
    "$R/services/admin-portal-bff/src/AdminPortalBff.Api/Endpoints/ReconciliationEndpoints.cs" \
    "$R/services/admin-portal-bff/src/AdminPortalBff.Api/Endpoints/ValidationRulesEndpoints.cs" \
    "$R/services/token-vault/src/TokenVault.Api/Endpoints/KmsEndpoints.cs" \
    "$R/services/token-vault/src/TokenVault.Api/Endpoints/ListHashKeyEndpoints.cs"
argc=4
rotas: (nenhuma)
  mapgroup-unindexed   :: .../ReconciliationEndpoints.cs:24  :: 1 chamada(s) MapGroup() ...
  route-site-unindexed :: .../ReconciliationEndpoints.cs:0   :: 1 registro(s) de verbo HTTP ...
  mapgroup-unindexed   :: .../ValidationRulesEndpoints.cs:30 :: 1 chamada(s) MapGroup() ...
  route-site-unindexed :: .../ValidationRulesEndpoints.cs:0  :: 1 registro(s) de verbo HTTP ...
  mapgroup-unindexed   :: .../KmsEndpoints.cs:27             :: 2 chamada(s) MapGroup() ...
  route-site-unindexed :: .../KmsEndpoints.cs:0              :: 2 registro(s) de verbo HTTP ...
  mapgroup-unindexed   :: .../ListHashKeyEndpoints.cs:26     :: 4 chamada(s) MapGroup() ...
  route-site-unindexed :: .../ListHashKeyEndpoints.cs:0      :: 4 registro(s) de verbo HTTP ...
```

```javascript
// $B/quatro.mjs — R é a raiz do repositório de referência
const libdir = process.argv[2];
const { scanRoutes } = await import(libdir + '/route-scan.mjs');
const raiz = '/Users/milton/Documents/projects/axis-go-cloud';
const arqs = process.argv.slice(3);
console.error('argc=' + arqs.length);
const r = scanRoutes(arqs, { root: raiz });
console.log('rotas: ' + (r.routes.map((x) => x.method + ' ' + x.path).join(' | ') || '(nenhuma)'));
for (const u of r.unresolved) console.log('  ' + u.kind + ' :: ' + u.file + ':' + u.line + ' :: ' + String(u.detail).slice(0, 40));
```

Quatro arquivos, sempre com o par `mapgroup`/`route-site` carregando a mesma contagem por arquivo — exatamente como o ledger descreve. E `group-path-not-literal` e `route-path-not-literal`, as duas categorias que o índice de constante literal resolveria, somam **zero** fora da subárvore alheia: as 32 e as 23 ocorrências da tabela acima são **todas** de `axis-device-platform`. O mecanismo proposto originalmente por LDG-0029 tem alvo zero onde ele promete destravar, e isso agora é medição regenerada, não herança.

### 3.2 O que a remedição CORRIGE no registro

Duas correções, e a primeira importa para a onda inteira porque ela é o insumo de LDG-0162.

**O ledger diz "4 chamadas MapGroup() em quatro arquivos". São 8 chamadas em quatro arquivos.** O registro contou **diagnósticos** (quatro entradas `mapgroup-unindexed`) e chamou de chamadas; o campo `detail` de cada entrada diz `1`, `1`, `2` e `4`, que somam oito — é a saída de 3.1, coluna a coluna. O mesmo vale para o par: são 8 registros de verbo HTTP não ancorados, não quatro. A correção não muda a natureza do item — muda o tamanho do que a correção precisa alcançar, e é o número que a seção 4 usa.

**Os `.forge.bak-*` do repositório de referência entram no universo e contribuem zero registros.** Medido em duas metades. A primeira é a saída de `universo-ref.mjs` da seção 2: 10.325 arquivos de dialeto suportado, dos quais 1.429 em `axis-device-platform`, 191 em algum `.forge.bak-*` e 54 nos dois ao mesmo tempo — união de 1.566. A segunda é a atribuição de cada rota e cada irresolúvel à sua origem:

```
$ node $B/atribui.mjs $B/lib-prod /Users/milton/Documents/projects/axis-go-cloud
resto do repositório de referência       rotas 353   unresolved 8
axis-device-platform (aninhado)          rotas 20   unresolved 69
```

```javascript
// $B/atribui.mjs
const lib = process.argv[2], raiz = process.argv[3];
const { scanRoutes } = await import(lib + '/route-scan.mjs');
const r = scanRoutes([raiz], { root: raiz });
const dentro = (f) => String(f).startsWith('axis-device-platform');
const rd = r.routes.filter((x) => dentro(x.file)).length;
const ud = r.unresolved.filter((x) => dentro(x.file)).length;
console.log(`resto do repositório de referência       rotas ${r.routes.length - rd}   unresolved ${r.unresolved.length - ud}`);
console.log(`axis-device-platform (aninhado)          rotas ${rd}   unresolved ${ud}`);
```

`.forge.bak-*` não aparece porque contribuiu **zero rotas e zero irresolúveis**, apesar dos 191 arquivos. O ledger dizia isso e agora está regenerado: pular `.forge.bak*` é higiene defensiva, não correção medida. Ele entra nesta onda mesmo assim, e o motivo está em 3.4.

Os cinco números deste bloco — 10.325, 1.429, 191, 54 e 1.566 — são **testemunhas de data**, medidas no commit `721fc7ec5` do repositório de referência, e nenhum deles entra em asserção. Os pares 353/8 e 20/69 são propriedade estrutural (a subárvore alheia concentra os irresolúveis) e é a propriedade, não o par, que a onda usa.

### 3.3 Decisão fechada — o índice de constante literal sai de escopo

**Decisão:** o índice de constante literal **não** é implementado, nem nesta onda nem como pendência aberta. A justificativa é a medição de 3.1: as duas categorias que ele resolveria somam zero no repositório de referência, e a projeção de 51 sítios que o ledger registra está acima do teto medido da variante qualificada (49). Um mecanismo com alvo zero no único corpus de referência disponível não é dívida — é ideia sem demanda.

**Alternativa descartada:** implementar o índice mesmo assim, porque as 32 ocorrências de `group-path-not-literal` existem. Descartada porque elas estão **todas** dentro do repositório aninhado, que a própria onda passa a excluir do universo — implementar o índice para elas seria construir maquinaria para código que o harness deixa de olhar no mesmo commit.

### 3.4 Decisão fechada — o discriminante da poda

O item pede "pular a subárvore git-excluída". A tentação é implementar literalmente isso, e ela está errada por uma razão medida: `axis-device-platform` está excluído por `.git/info/exclude:20`, que é arquivo **local e não versionado** —

```
$ git -C /Users/milton/Documents/projects/axis-go-cloud check-ignore -v axis-device-platform
.git/info/exclude:20:/axis-device-platform/	axis-device-platform
```

— de modo que um clone novo do mesmo repositório, num runner de CI, **não** teria a exclusão e varreria a subárvore. Um universo de varredura que depende de configuração de máquina não é reprodutível, e a rule `testing/gate-delivery-channel.md` já normatiza a classe: *"config de máquina some num clone novo e num runner de CI"*.

**Decisão fechada: o discriminante é estrutural, não de configuração — um diretório-filho que contém um `.git` próprio é um repositório SEPARADO e não é código-fonte deste repositório.** Junto com ele entra o segundo discriminante, por nome: diretório cujo nome começa com `.forge.bak`.

Três razões medidas sustentam a escolha:

**1. Ela discrimina o caso real.**

```
$ ls -d /Users/milton/Documents/projects/axis-go-cloud/axis-device-platform/.git
axis-device-platform/.git
$ git -C /Users/milton/Documents/projects/axis-go-cloud ls-files --error-unmatch axis-device-platform
error: pathspec 'axis-device-platform' did not match any file(s) known to git
```

O `.git` existe e é diretório; a subárvore não é rastreada pelo superprojeto por nenhum mecanismo.

**2. Ela não depende de `git` no PATH, nem de o diretório varrido ser um repositório, nem de haver commit.** É a saída para o caso que a invariante 17 do plano-mestre nomeia — repositório sem nenhum commit, onde os comandos de git degeneram — e para o caso de varrer um tarball extraído.

**3. O caso ambíguo tem zero instâncias no parque, e o caso comum tem sete.** Medido em duas metades, e a revisão 1 errou a redação desta terceira razão sem errar a medição.

```
$ cd ~/Documents/projects && ls -d */ | wc -l
33
$ cd ~/Documents/projects && for d in */; do [ -e "$d/.git" ] && echo "$d"; done | wc -l
20
$ cd ~/Documents/projects && find . -maxdepth 4 -name .gitmodules -not -path '*/node_modules/*' | wc -l
0
$ cd ~/Documents/projects && for d in */; do d=${d%/}; \
    n=$(find "$d" -mindepth 2 -maxdepth 3 -name .git -not -path '*/node_modules/*' -prune 2>/dev/null | wc -l | tr -d ' '); \
    [ "$n" -gt 0 ] && echo "$d $n"; done
axis-go-cloud 1
docuseal 1
lioncode 1
oversetter 4
payments 24
pitflow 11
secret-weapon 2
```

São **33 diretórios de topo**, dos quais **20 são repositório próprio** (têm `.git` na raiz) e os outros 13 são diretório comum ou guarda-chuva. **Zero `.gitmodules`** em qualquer profundidade até 4. E **sete diretórios de topo têm `.git` aninhado em profundidade 2–3** — dos quais `axis-go-cloud`, `docuseal` e `payments` são repositório próprio com subárvore alheia dentro, e `pitflow`, `oversetter`, `secret-weapon` e `lioncode` **não têm `.git` próprio**: são guarda-chuvas que só contêm repositórios aninhados. A revisão 1 chamou os sete de "repositórios" e disse que o parque tinha doze; os dois erros estão corrigidos e nenhum deles muda a conclusão, porque o que a decisão usa é o zero de `.gitmodules`. O submódulo — o único arranjo em que "tem `.git`" e "faz parte deste repositório" coexistem — é uma objeção teórica aqui.

**O `.forge.bak*` entra pelo motivo de LDG-0152, não pelo dano medido.**

```
$ awk 'NR==17' template/.forge/scripts/lib/scan-exclude.sh
FORGE_SCAN_EXCLUDE="${FORGE_SCAN_EXCLUDE:-.git node_modules .forge.bak-* dist build out obj coverage vendor}"
$ grep -c "forge.bak" template/.forge/scripts/lib/source-scan.mjs
0
```

`scan-exclude.sh:17` já declara `.forge.bak-*` na lista do que **nenhum** gate deve varrer, e o cabeçalho dele registra o dano em consumidor real. Só que essa lista serve os gates de shell; os gates de node passam por `collect()` de `lib/source-scan.mjs`, cujo `DEFAULT_SKIP` tem `.forge` e **zero** ocorrências de `.forge.bak` — é por isso que os 191 arquivos estão no universo. Duas políticas de exclusão no mesmo harness, discordando exatamente num item, é a forma do defeito de LDG-0152. Fechar a assimetria custa uma linha e evita que a próxima medição de universo tenha de descobrir de novo qual das duas listas vale.

**Alternativa descartada:** `git check-ignore --stdin`. Descartada pelas três razões acima e por uma quarta: ela transforma a varredura numa chamada de subprocesso por diretório, num engine cujo contrato é zero-dependência.

**Alternativa descartada:** `git ls-files` como universo. Descartada porque um arquivo recém-criado e ainda não adicionado deixa de existir para o oráculo — que é precisamente o arquivo do endpoint que se acabou de escrever — e porque num repositório sem commit ela devolve lista vazia com rc 0, que é universo vazio com cara de sucesso.

### 3.5 A enumeração dos desfechos, e os casos que ela não cobria

A invariante 17 manda procurar ativamente o caso não coberto. Procurei na revisão 1 e achei o sexto item; procurei de novo nesta revisão, com o protótipo pronto, e achei mais **dois** — o que é a demonstração de que "enumeração exaustiva" só vale quando cada linha tem medição própria.

| Estado do diretório-filho | O que acontece | Medido? |
|---|---|---|
| Repositório independente, não rastreado e git-excluído | podado, anunciado | sim — 3.1/3.2, é o caso real |
| Repositório independente, não rastreado e **não** excluído | podado, anunciado | sim — fixture `aninhado/` de 5.4 |
| Submódulo git (o `.git` é **arquivo**) | podado, anunciado | não: o `existsSync` não distingue arquivo de diretório e o parque tem zero instâncias (3.4) |
| Worktree do MESMO repositório dentro da árvore | podado, anunciado | mesma mecânica da linha anterior; varrer uma worktree de si mesmo duplicaria cada achado |
| Diretório chamado `.git` que não é repositório | podado, anunciado | mesma mecânica; inofensivo, porque a poda é anunciada e quem olhar vê |
| **A própria RAIZ da varredura contém `.git`** — o caso normal | **NÃO podada** | sim — fixture `raiz/` de 5.5: `GET /raiz/ok`, `skipped` vazio |
| **A própria RAIZ da varredura É um `.forge.bak-*`** | **NÃO podada** | sim, e é a escape hatch em ação: passar o backup como raiz explícita devolve `GET /bak/raiz` com `skipped` vazio |
| **Diretório-filho que é SYMLINK para outra árvore** | **não é varrido, e o silêncio é PREEXISTENTE** | sim — `readdirSync(..., {withFileTypes:true})` classifica symlink como não-diretório, então `collect()` nunca entra; produção e protótipo devolvem zero rotas e nenhum anúncio |
| `.git` que é symlink quebrado | não podado (o teste de existência segue o link e falha) | borda benigna, registrada por leitura |
| Permissão negada ao ler o diretório | `collect()` hoje lança; comportamento preexistente | fora do escopo desta onda, registrado |

Os dois casos novos:

```
$ node $B/podarun.mjs $B/lib-proto $B/fx/raizbak/.forge.bak-9
  rotas: GET /bak/raiz
  skipped: [] (vazio)
$ node $B/podarun.mjs $B/lib-prod  $B/fx/symlink/dentro
  rotas: (nenhuma)
  skipped: (o campo não existe no objeto devolvido)
$ node $B/podarun.mjs $B/lib-proto $B/fx/symlink/dentro
  rotas: (nenhuma)
  skipped: [] (vazio)
```

O sétimo caso é a escape hatch de 3.7 exercida sobre o segundo discriminante, e ele passa porque a regra vale só para descendentes. O oitavo é um achado desta revisão que a onda **não** conserta e que fica registrado em letra: um diretório-filho que é symlink já hoje sai do universo **sem anúncio nenhum**, o que é a mesma classe de silêncio que 3.7 combate — só que preexistente, com dono anterior a esta onda, e por isso item de ledger próprio, não escopo daqui.

O sexto caso não é hipótese: é o modo de operação normal (`scanRoutes(['.'])` a partir da raiz do repositório) e uma implementação que aplicasse a regra à raiz devolveria zero arquivos — o defeito que o harness mais combate. Ele ganha cenário próprio de gate em 5.5 e mutação própria em 6 (M4).

### 3.6 Decisão fechada — a poda é OPT-IN em `collect()`, e ligada em `scanRoutes()`

Esta é a decisão que mais mudou durante a medição, e o que a mudou foi um contraexemplo que eu não esperava.

`collect()` é compartilhado. Medido:

```
$ grep -rln "source-scan.mjs" template/
template/.forge/scripts/check-observability.sh
template/.forge/scripts/lib/api-surface.mjs
template/.forge/scripts/lib/check-authz.mjs
template/.forge/scripts/lib/check-data-governance.mjs
template/.forge/scripts/lib/check-observability.mjs
template/.forge/scripts/lib/route-scan.mjs
$ grep -n "source-scan" template/.forge/scripts/check-observability.sh
4:# REQ-09b logger cru fora do wrapper (lib/source-scan.mjs), REQ-10 alerts-as-code por
```

São **quatro** módulos que de fato importam `collect()` — `lib/check-authz.mjs`, `lib/check-observability.mjs`, `lib/check-data-governance.mjs` e `lib/api-surface.mjs` — mais o próprio `route-scan.mjs`. O sexto arquivo da lista, `check-observability.sh`, casa apenas num **comentário** e não importa nada; o comando acima é o que separa os dois casos, e é a razão de ele estar colado aqui.

Ligar a poda no default de `collect()` muda o universo dos três gates de governança. Medi o efeito em três repositórios, contando o universo antes e depois, para `.md` e para código:

```
$ node $B/universo.mjs $B/lib-proto ~/Documents/projects/payments ~/Documents/projects/axis-fare-validator /Users/milton/Documents/projects/forge-harness
payments             md      antes=  1092 depois=   621 delta=   471 (43.1%) podadas=25
payments             código  antes=  3022 depois=     0 delta=  3022 (100.0%) podadas=25
axis-fare-validator  md      antes=   350 depois=   350 delta=     0 (0.0%) podadas=0
axis-fare-validator  código  antes=  1081 depois=  1081 delta=     0 (0.0%) podadas=0
forge-harness        md      antes=   188 depois=   188 delta=     0 (0.0%) podadas=0
forge-harness        código  antes=    20 depois=    20 delta=     0 (0.0%) podadas=0
```

```javascript
// $B/universo.mjs
const lib = process.argv[2];
const { collect } = await import(lib + '/source-scan.mjs');
const CODIGO = ['.cs', '.java', '.kt', '.ts', '.js', '.mjs', '.py', '.go'];
for (const repo of process.argv.slice(3)) {
  for (const [rot, exts] of [['md    ', ['.md']], ['código', CODIGO]]) {
    const podadas = new Set();
    const antes = collect([repo], { exts: new Set(exts) }).length;
    const depois = collect([repo], { exts: new Set(exts), pruneForeign: true, onPrune: (x) => podadas.add(x.dir) }).length;
    const d = antes - depois; const pct = antes ? ((d / antes) * 100).toFixed(1) : '0.0';
    console.log(`${repo.split('/').pop().padEnd(20)} ${rot}  antes=${String(antes).padStart(6)} depois=${String(depois).padStart(6)} delta=${String(d).padStart(6)} (${pct}%) podadas=${podadas.size}`);
  }
}
```

O `188` do `forge-harness` era `184` na revisão 1, quatro dias atrás: a diferença são os próprios arquivos de spike desta rodada. É a ilustração mais limpa que este documento produziu do porquê de a invariante 14 existir, e é de novo testemunha de data, não critério.

**Em `payments` o universo de código vai a ZERO.** Não é anomalia, e a decomposição das 25 podas diz exatamente o que ele é:

```
$ node $B/podas-detalhe.mjs $B/lib-proto ~/Documents/projects/payments
{ "total": 25,
  "porMotivo": { "backup-de-update": 1, "repositorio-aninhado": 24 },
  "exemplos": [ "backup-de-update .forge.bak-1",
                "repositorio-aninhado Axis.AxisPayment.Backoffice.Spa",
                "repositorio-aninhado Payments.Audit" ] }
```

São **24 repositórios independentes** lado a lado mais **um** `.forge.bak-1` — e os 24 batem exatamente com a contagem de `.git` aninhado de 3.4. A revisão 1 dizia "aproximadamente vinte e cinco repositórios", e o "aproximadamente" escondia justamente a linha que não era repositório. O `.forge/` mora no guarda-chuva, a poda diria a verdade — aquele diretório não tem código próprio — e `lib/check-observability.mjs:204-205` usa `collect(...).length` como **contador de universo**, que reprova em zero por desenho (`lib/gate-universe.mjs`):

```
$ awk 'NR>=204 && NR<=205' template/.forge/scripts/lib/check-observability.mjs
  const scanned = collect(inputs, { exts: SOURCE_EXTS }).length
    + collect(inputs, { exts: new Set(['.json']) }).length;
```

Um gate hoje verde passaria a reprovar com `universo-vazio` num consumidor com change ativo.

**Decisão fechada:** `collect()` ganha a poda como **opção desligada por default**, e quem a liga é `scanRoutes()`. O raio de alcance da onda passa a ser exatamente o oráculo de rota, que é onde LDG-0029 vive — o título do item é literalmente *"route-scan: corrigir o universo da varredura"*. Consumidores dos três gates de governança não veem um byte de diferença, e isso é assertado em 5.6.

**Alternativa descartada:** ligar por default e deixar `payments` reprovar. Descartada porque o veredito seria certo e a onda erraria de escopo: transformar a política de universo dos gates de governança é uma decisão com dono e com piloto, não um efeito colateral de um item de route-scan. **Ela vira item novo de ledger**, com a medição acima anexada — é a informação que falta hoje para tomar essa decisão, e ela não existia antes desta rodada.

**Alternativa descartada:** ligar também em `collectDeclaredSurface()` de `lib/api-surface.mjs`, por simetria. Descartada por medição, e a medição da revisão 1 estava incompleta porque olhava a extensão errada:

```
$ node $B/contratos.mjs $B/lib-proto /Users/milton/Documents/projects/axis-go-cloud/contracts
contrato (.yaml/.yml/.json): antes=60 depois=60 podadas=0
spec (.md): antes=5 depois=5 podadas=0
```

```javascript
// $B/contratos.mjs
const lib = process.argv[2], dir = process.argv[3];
const { collect } = await import(lib + '/source-scan.mjs');
for (const [rot, exts] of [['contrato (.yaml/.yml/.json)', ['.yaml', '.yml', '.json']], ['spec (.md)', ['.md']]]) {
  const podadas = [];
  const antes = collect([dir], { exts: new Set(exts) }).length;
  const depois = collect([dir], { exts: new Set(exts), pruneForeign: true, onPrune: (x) => podadas.push(x.dir) }).length;
  console.log(`${rot}: antes=${antes} depois=${depois} podadas=${podadas.length}`);
}
```

`collectDeclaredSurface()` lê contratos com `{'.yaml','.yml','.json'}` (`api-surface.mjs:423`) e specs com `{'.md'}` (`:429`); a revisão 1 mediu só o `.md`. Medidas as duas, **zero podas nas duas** — 60 arquivos de contrato e 5 de spec, antes e depois. Simetria sem efeito medido é superfície nova de graça, e agora com a extensão certa.

### 3.7 Decisão fechada — o canal do silêncio, e o nome do campo

Podar em silêncio reintroduziria, do lado do universo, o defeito que `route-scan.mjs` combate do lado da rota: o cabeçalho do módulo diz em letra que *"o que o scanner viu e não resolveu vira `unresolved` — nunca é descartado"*, e uma subárvore inteira desaparecendo sem registro é a versão macro disso.

**Decisão fechada:** a poda é anunciada por um canal **próprio**. `scanRoutes()` passa a devolver um terceiro campo, **chamado `skipped`**, com uma entrada por diretório podado, cada entrada carregando `motivo` (`repositorio-aninhado` ou `backup-de-update`) e `dir` (o caminho relativo à raiz). `collect()` recebe a poda pela opção `pruneForeign` e o anúncio pelo gancho `onPrune`; quem compõe o relatório é o chamador.

O nome é fixado **aqui** e não por acidente noutra seção, e ele foi varrido antes de ser escolhido:

```
$ grep -c "skipped" template/.forge/scripts/lib/route-scan.mjs
0
$ grep -c "skipped" tests/w132-route-surface-gate.sh
0
$ grep -rln "skipped" tests/ | wc -l
9
```

Zero ocorrências no módulo e zero no gate que o exercita; as nove ocorrências em `tests/` estão em gates de outro assunto (`w32-archive`, `w173-archive-state-machine-contract`, `w205-quick-plan-design-skip` e companhia) e nenhuma toca `route-scan`. `[62]` e M5 dependem do mesmo nome, e agora as duas seções falam do mesmo campo porque o campo tem nome aqui.

**Alternativa descartada, e ela é a tentadora:** empurrar a poda para dentro de `unresolved`, com um `kind` novo, e inscrevê-lo em `NAO_SUPRIME` de `surContractToCode`. Descartada por duas razões. A primeira é de contrato: `unresolved` significa *"o scanner viu e não resolveu"*, e uma subárvore alheia nunca foi vista como fonte deste repositório — encaixá-la ali alarga o significado de um campo que quatro dialetos e quinze `kind` já compartilham. A segunda é de risco: `NAO_SUPRIME` está **vazio hoje** e o default de `surContractToCode` é o oposto — *"kind desconhecido SUPRIME"* —, de modo que inscrever o primeiro membro nessa lista é gastar a única garantia fail-closed que o SUR-01 tem, e gastá-la num `kind` que a onda acabou de inventar.

**A fronteira que essa decisão cria, dita em voz alta:** um endpoint declarado em contrato mas servido por código que mora num repositório aninhado passa a ser reportado pelo SUR-01 como ausente, com veredito conclusivo. A escape hatch é passar aquele repositório como **raiz explícita** de varredura — medida nas linhas 6 e 7 da tabela de 3.5. Isso é fronteira decidida, não esquecimento, e está aqui para que o próximo revisor não precise descobri-la.

---

## 4. LDG-0162 — `MapGroup()` não ancorado

### 4.1 O defeito, reproduzido, com o código real

Os quatro arquivos de 3.1 têm o **mesmo** idioma. O de `ListHashKeyEndpoints.cs`, que sozinho responde por metade dos oito sítios:

```csharp
public static IEndpointRouteBuilder MapListHashKeyEndpoints(this IEndpointRouteBuilder app)
{
    app.MapGroup("/api/v1/list-hash-keys")
        .WithTags("list-hash-keys")
        .MapPost("/derive", DeriveAsync);

    app.MapGroup("/api/v1/list-hash-keys")
        .WithTags("list-hash-keys")
        .MapPost("/wrap", WrapAsync);
    // … mais dois, idênticos em forma
}
```

O mecanismo, lido no engine com as linhas conferidas nesta revisão:

```
$ grep -n "const CHAIN\|kind: 'mapgroup-unindexed'\|kind: 'route-site-unindexed'" template/.forge/scripts/lib/route-scan.mjs
411:  const CHAIN = '(?:\\s*\\.\\s*MapGroup\\s*\\(\\s*[^)]*?\\s*\\))+';
499:      kind: 'mapgroup-unindexed',
509:      kind: 'route-site-unindexed',
$ awk 'NR==443 || NR==460 || NR==475' template/.forge/scripts/lib/route-scan.mjs
    const re = new RegExp(`\\b(\\w+)(${CHAIN})\\s*\\.\\s*Map${cap}\\s*\\(\\s*([^,)]*)`, 'g');
  const fluentCallRe = new RegExp(`\\b(\\w+)(${CHAIN})\\s*\\.\\s*(Map[A-Z]\\w*)\\s*\\(\\s*\\)`, 'g');
    const re = new RegExp(`(\\w+)\\s*\\.\\s*Map${cap}\\s*\\(\\s*([^,)]*)`, 'g');
$ awk 'NR==496 || NR==507' template/.forge/scripts/lib/route-scan.mjs
  const orfaos = sitiosGrupo.filter((i) => !ancorados.has(i));
  if (rotasVistas + naoLiterais < sitiosVerbo) {
```

`route-scan.mjs:411` define `CHAIN` como uma ou mais chamadas `.MapGroup(...)` **adjacentes**, e os reconhecedores de cadeia fluente (`:443` para o verbo, `:460` para o produtor) exigem que a cadeia encoste no verbo. `.WithTags("list-hash-keys")` se interpõe, a cadeia não casa, `ancorar()` não é chamada, e o sítio de `MapGroup` cai no laço de órfãos que **começa em `:496`** e emite `mapgroup-unindexed` **em `:499`** (bloco `496-503`). O registro do verbo, por sua vez, não casa o padrão simples de `:475` porque o receptor imediatamente antes de `.MapPost` é um `)`, que não é `\w+` — e cai na guarda que **começa em `:507`** e emite `route-site-unindexed` **em `:509`** (bloco `507-513`). A revisão 1 citava `:496` e `:507` (os statements que abrem cada bloco) e o revisor citava `:499` e `:509` (as linhas do `kind`); os dois estão certos sobre coisas diferentes, e citar o **bloco** encerra a ambiguidade. Uma causa, dois diagnósticos, contagem idêntica por arquivo: é exatamente a assinatura que o ledger descreve.

Reproduzido contra os quatro arquivos, com a `lib/` de produção — é a saída de `quatro.mjs` colada em 3.1: zero rotas, `mapgroup-unindexed` ×4 e `route-site-unindexed` ×4, com `detail` somando 8 e 8.

### 4.2 A propriedade, e o contrafactual

**Propriedade:** numa cadeia fluente do .NET, elos que **não** abrem grupo nem registram rota — `.WithTags(...)`, `.RequireAuthorization()`, `.WithName(...)`, `.ExcludeFromDescription()` — são transparentes para a composição do prefixo. A rota resultante é a mesma que seria composta se esses elos não estivessem escritos.

**Contrafactual que a mutação tem de produzir:** removida a tolerância, a cadeia com elo intercalado volta a não compor, os sítios voltam a `mapgroup-unindexed` mais `route-site-unindexed`, e **nenhuma** rota é emitida. Nunca uma rota com prefixo pela metade.

A especificação **não prescreve o primitivo**. O protótipo que eu executei generaliza o `CHAIN` de `:411` para tolerar elos não-rota **depois** de cada `MapGroup` (seção 0), e a seção 6 mostra por que "depois" e "com que forma de argumento" são dois eixos e não um; mas a escolha entre generalizar o regex, tokenizar a cadeia ou reconhecê-la por outro caminho é de quem executa, com a obrigação de provar a discriminação pela matriz de 6.

### 4.3 O que o protótipo mediu

Contra os quatro arquivos do repositório de referência, com a `lib/` prototipada:

```
$ node $B/quatro.mjs $B/lib-proto "$R/.../ReconciliationEndpoints.cs" "$R/.../ValidationRulesEndpoints.cs" \
                                  "$R/.../KmsEndpoints.cs" "$R/.../ListHashKeyEndpoints.cs"
argc=4
rotas: GET /api/v1/clearing/batches | POST /api/v1/kms/unwrap | POST /api/v1/kms/wrap
     | GET /api/v1/list-hash-keys/current-version | POST /api/v1/list-hash-keys/derive
     | POST /api/v1/list-hash-keys/rotate | POST /api/v1/list-hash-keys/wrap
     | GET /api/v1/validation-rules
```

Oito sítios, oito rotas, zero irresolúveis. E sobre o repositório de referência **inteiro**, com as duas correções da onda ligadas:

```
$ node $B/scan.mjs $B/lib-proto /Users/milton/Documents/projects/axis-go-cloud
{ "ms": 296084, "routes": 364, "unresolved": 0, "dentroDeviceplatform": 0,
  "foraDeviceplatform": 0, "porKind": {}, "skipped": 4 }
```

**Zero irresolúveis no repositório de referência.** É a primeira vez, na história deste item, que a varredura fecha — e é o que satisfaz a pré-condição (1) de LDG-0010, que o ledger diz ser `mapgroup-unindexed`/`route-site-unindexed` e não o índice de constante.

Duas cautelas sobre esses números, porque elas importam mais que os números.

**A atribuição por arquivo depois da deduplicação não é confiável, e eu não a uso para nada.**

```
$ awk 'NR>=1253 && NR<=1263' template/.forge/scripts/lib/route-scan.mjs
  const { routes, unresolved } = compose(idx);

  const seen = new Set();
  const deduped = [];
  for (const r of routes) {
    const key = `${r.method} ${r.path}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(r);
  }
  deduped.sort(...);
```

A deduplicação por `MÉTODO path` ocupa `1255-1263` e `compose()` a alimenta em `1253`; a revisão 1 citou o bloco de dedup e o revisor citou o bloco com a chamada que o alimenta, e o `awk` acima torna a discussão desnecessária. Ela mantém a primeira rota empilhada, então uma rota que existe nas duas árvores é atribuída ao arquivo que veio primeiro. É por isso que a passada com só a correção da cadeia mostrava 361 rotas fora do aninhado e a passada com as duas mostra 364 no total: a diferença de três é compatível com colisão de chave entre as duas árvores, e eu **não** isolei o mecanismo. Registro assim em vez de explicar, porque explicação não medida é o que a invariante 19 proíbe.

**O tempo de parede não sustenta afirmação nenhuma, e os literais da revisão 1 saíram do documento.** A revisão 1 publicava "93.118 ms" e "167.468 ms" como se fossem medições estáveis. São ruído. Três execuções completas do mesmo par de comandos — seis medições ao todo —, por dois operadores independentes na mesma máquina:

| Execução | Produção | Protótipo |
|---|---|---|
| Revisão 1 (autor) | 93 s | 167 s |
| Revisão 1 (revisor) | 359 s | 297 s |
| Revisão 2 (autor, blocos de 3.1 e 4.3) | 326 s | 296 s |

A ordem entre produção e protótipo **inverteu** entre operadores, e o intervalo cobre uma faixa de quase quatro vezes. O que sobrevive, e sobrevive com força, é a **faixa**: as seis medições ficam entre dezenas de segundos e poucos minutos, e nenhuma chega perto do segundo. É essa faixa — e não um literal — que a seção 9.3-C usa, e nenhuma asserção de gate depende dela.

### 4.4 A fronteira do reconhecedor, medida

Prototipar um reconhecedor mais tolerante cria a pergunta "tolerante até onde", e a resposta precisa ser medida, não estimada. Bancada com quatro formas, em `$B/fx/f44/G.cs`:

```csharp
app.MapGroup("/p1").RequireAuthorization(p => p.RequireRole("admin")).MapGet("/lam", H);
app.MapGroup("/p2").Produces<Foo>(200).MapGet("/gen", H);
app.MapGroup("/p3").WithTags("t").MapPost("/ok", H);
app.MapGroup("/p4")
    .WithTags("t")
    .WithName("n")
    .MapPut("/dois", H);
```

```
$ node $B/fxrun.mjs $B/lib-prod  $B/fx/f44
  rotas: (nenhuma)
  kinds: mapgroup-unindexed, route-site-unindexed
$ node $B/fxrun.mjs $B/lib-proto $B/fx/f44
  rotas: POST /p3/ok | PUT /p4/dois
  kinds: mapgroup-unindexed, route-site-unindexed
```

O elo simples e o elo múltiplo em várias linhas compõem; o elo com **argumento lambda** e o elo com **argumento de tipo genérico** não compõem, e degradam para os dois diagnósticos de sempre. **A degradação é na direção segura** — o reconhecedor que não entende a cadeia diz que não entendeu, e nunca emite path parcial. Essa é a propriedade que o cenário contrapositivo de 5.2 assere, e ela é o que impede que "tolerar mais" vire "inventar mais".

As duas metades desta fixture viram duas fixtures separadas na seção 5, e a separação é o que a seção 6 precisa para discriminar os dois eixos: `$B/fx/f59` com as duas formas que compõem e `$B/fx/f60` com as duas que não compõem.

```
$ node $B/fxrun.mjs $B/lib-prod  $B/fx/f59      # as duas que compõem
  rotas: (nenhuma)
  kinds: mapgroup-unindexed, route-site-unindexed
$ node $B/fxrun.mjs $B/lib-proto $B/fx/f59
  rotas: POST /p3/ok | PUT /p4/dois
  kinds: (nenhum)
$ node $B/fxrun.mjs $B/lib-prod  $B/fx/f60      # as duas que NÃO compõem
  rotas: (nenhuma)
  kinds: mapgroup-unindexed, route-site-unindexed
$ node $B/fxrun.mjs $B/lib-proto $B/fx/f60
  rotas: (nenhuma)
  kinds: mapgroup-unindexed, route-site-unindexed
```

Consequência declarada: repositório que use `RequireAuthorization(policy => …)` entre o grupo e o verbo continua com `mapgroup-unindexed`. O repositório de referência não usa — depois da correção ele vai a zero —, então a onda para aqui por medição, não por preguiça.

### 4.5 A linha vermelha de `w132[16]` — MEDIDA, e ela se mantém

O plano-mestre e o ledger mandam manter `w132[16]` verde: ele assere que literal interpolado com buraco de runtime produz `group-path-not-literal` e nenhuma rota. Extraí a fixture literal do gate (`tests/w132-route-surface-gate.sh:414-448`) para `$B/fx/f16` e rodei as **quatro** condições que as quatro asserções do cenário cobrem, contra as duas bibliotecas:

```
$ node $B/f16chk.mjs $B/lib-prod  $B/fx/f16
  rotas=[]  group-path-not-literal=2  inventou-tenantId=false  inventou-contaId=false
$ node $B/f16chk.mjs $B/lib-proto $B/fx/f16
  rotas=[]  group-path-not-literal=2  inventou-tenantId=false  inventou-contaId=false
```

```javascript
// $B/f16chk.mjs
const [lib, dir] = process.argv.slice(2);
const { scanRoutes } = await import(lib + '/route-scan.mjs');
const { routes, unresolved } = scanRoutes([dir], { root: dir });
const din = unresolved.filter((u) => u.kind === 'group-path-not-literal');
console.log(`  rotas=${JSON.stringify(routes.map((r) => r.method + ' ' + r.path))}  group-path-not-literal=${din.length}  inventou-tenantId=${routes.some((r) => r.path.includes('tenantId'))}  inventou-contaId=${routes.some((r) => r.path.includes('contaId'))}`);
```

Saída idêntica nas quatro condições, incluindo a contagem exata de `2` que o gate cobra (`!== 2` reprova). A linha vermelha se mantém, e isso é medição, não expectativa.

### 4.6 O gate que a correção QUEBRA — nominal, com a linha

A invariante 15 manda varrer antes de propor a mudança. Varri `tests/`, `template/` e `plugin/` pelos dois `kind` afetados:

```
$ grep -rn "mapgroup-unindexed" tests/ template/ plugin/ | grep -v Binary | sed 's/:.*//' | sort | uniq -c
   1 template/.forge/scripts/lib/route-scan.mjs
   2 tests/w132-route-surface-gate.sh
$ grep -rn "route-site-unindexed" tests/ template/ plugin/ | grep -v Binary | sed 's/:.*//' | sort | uniq -c
   1 template/.forge/scripts/lib/route-scan.mjs
   1 tests/w132-route-surface-gate.sh
$ grep -n "mapgroup-unindexed\|route-site-unindexed" tests/w132-route-surface-gate.sh
839:if (!kinds.includes('mapgroup-unindexed')) { ... }
1090:if (!unresolved.some((u) => u.kind === 'mapgroup-unindexed')) { ... }
1241:if (!cs.unresolved.some((u) => u.kind === 'route-site-unindexed')) { ... }
```

Há exatamente **três** asserções, as três no mesmo arquivo, e a exaustividade é do `grep -rn` sobre as três árvores — não de leitura. A ocorrência restante em cada `kind` é a própria emissão em `route-scan.mjs`, e `plugin/` não aparece porque ele espelha só `.md` e `.json` (seção 14, armadilha B).

| Sítio | O que assere | Efeito da correção |
|---|---|---|
| `tests/w132-route-surface-gate.sh:839` (`[31]`) | `kinds.includes('mapgroup-unindexed')` sobre `var truncada = app.MapGroup("/api").RequireAuthorization().MapGroup("/v3")` | **QUEBRA** |
| `tests/w132-route-surface-gate.sh:1090` (`[40]`) | `mapgroup-unindexed` sobre `var b = Helper.Build().MapGroup("/b")` | intacto |
| `tests/w132-route-surface-gate.sh:1241` (`[42]`) | `route-site-unindexed` sobre `Helper.Build().MapGet("/composto", H)` | intacto |

Não é leitura: extraí as três fixturas para `$B/fx/f31`, `$B/fx/f40` e `$B/fx/f42` e rodei contra as duas bibliotecas.

```
$ for f in f31 f40 f42; do for L in lib-prod lib-proto; do echo "== $f :: $L =="; node $B/fxrun.mjs $B/$L $B/fx/$f; done; done
== f31 :: lib-prod ==    rotas: (nenhuma)            kinds: group-unreachable, mapgroup-unindexed
== f31 :: lib-proto ==   rotas: GET /api/v3/orders   kinds: group-unreachable
== f40 :: lib-prod ==    rotas: GET /a/x             kinds: mapgroup-unindexed
== f40 :: lib-proto ==   rotas: GET /a/x             kinds: mapgroup-unindexed
== f42 :: lib-prod ==    rotas: (nenhuma)            kinds: route-site-unindexed
== f42 :: lib-proto ==   rotas: (nenhuma)            kinds: route-site-unindexed
```

**Decisão fechada sobre `[31]`, e ela entra na definição de pronto.** O cenário `[31]` tem duas asserções negativas e duas positivas. As negativas continuam valendo e continuam sendo o que ele protege: `GET /admin/users` não pode sair (receptor desconhecido virando raiz) e `GET /api/orders` não pode sair (prefixo pela metade). Medido, as duas continuam falsas no protótipo — `/api/v3/orders` **não** é `/api/orders`, é a rota correta que o ASP.NET registra. A positiva `group-unreachable` continua valendo. A positiva `mapgroup-unindexed`, que hoje vem **só** daquele elo, deixa de ser verdadeira porque o elo passou a ser reconhecido, que é o objetivo do item.

`[31]` passa a assertar o invariante verdadeiro: *a cadeia com elo intercalado compõe o prefixo INTEIRO (`/api/v3`), e não meio prefixo*. A asserção de `mapgroup-unindexed` **muda de fixture**, não de existência: ela vai para o cenário contrapositivo de 5.2, sobre a forma que o reconhecedor comprovadamente não alcança (elo com lambda e elo com genérico), onde ela volta a ser o sinal de que a degradação é segura. Sem essa mudança de sítio, a onda apagaria uma asserção em vez de reposicioná-la — que é o que a invariante 15 existe para impedir.

---

## 5. O vermelho, antes do verde

Todos os cenários novos vivem em `tests/w132-route-surface-gate.sh`. O denominador de hoje:

```
$ grep -c '^echo "\[' tests/w132-route-surface-gate.sh
59
$ grep -c '^echo "OK \[' tests/w132-route-surface-gate.sh
59
$ grep -o '^echo "\[[0-9]*\]' tests/w132-route-surface-gate.sh | grep -o '[0-9]*' | sort -n -u | wc -l
59
$ grep -o '^echo "\[[0-9]*\]' tests/w132-route-surface-gate.sh | grep -o '[0-9]*' | sort -n | tail -1
58
$ wc -l < tests/w132-route-surface-gate.sh
1958
```

**59** cenários, ids `[0]` a `[58]`, 59 aberturas e 59 fechos, num arquivo de 1.958 linhas. A onda **não cria arquivo de gate novo**, e portanto **não aloca ordinal**: os pedágios de LDG-0167/0173 não se aplicam aqui, o que é decisão consciente e não omissão. E o `59` acima **não** entra na especificação como literal: quem executa **re-deriva** com o primeiro comando desta seção, no instante de escrever o gate, e confere que `SCEN_MIN` é o derivado mais seis (5.7). Se o derivado não for 59 no dia da execução, há cenário entrando por outra frente e a colisão precisa ser resolvida antes, não depois.

Os cenários usam fixture própria em `$TMPDIR`, reproduzindo em dez linhas os idiomas medidos no repositório de referência. **O gate não pode depender de repositório externo**: a suíte roda em máquina de CI onde `axis-go-cloud` não existe, e um gate que só morde na máquina do autor é gate morto no lugar em que ele mais importa.

### 5.1 `[59]` — a cadeia com elo não adjacente compõe

Fixture: `$B/fx/f59` — as duas formas medidas em 4.4 que compõem, elo único em uma linha e dois elos em linhas separadas, dentro de um produtor `MapX(this IEndpointRouteBuilder app)`.

Asserções: as rotas `POST /p3/ok` e `PUT /p4/dois` existem, com o prefixo **inteiro**; nenhuma rota com prefixo parcial (`POST /ok`) existe.

*Como falha hoje:* medido em 4.4, `node $B/fxrun.mjs $B/lib-prod $B/fx/f59` devolve **zero rotas** e dois diagnósticos. A asserção falha porque `CHAIN` em `route-scan.mjs:411` exige adjacência e não existe nenhum caminho no arquivo que tolere elo intercalado:

```
$ grep -n 'WithTags\|RequireAuthorization\|ExcludeFromDescription' template/.forge/scripts/lib/route-scan.mjs
1084:    // RELATIVO, um receptor que não é o parâmetro nasceu de `group.RequireAuthorization()` ou
1085:    // `group.WithTags()` — idioma corrente de ASP.NET — e o prefixo dele é o do chamador.
```

Exatamente **duas** ocorrências, ambas em comentário, ambas em `compose()` e ambas sobre um sítio DIFERENTE — o receptor desconhecido de dentro de um produtor relativo, tratado por `isRootOwner`. O engine conhece o idioma em prosa e não o reconhece na cadeia; é ausência de funcionalidade, não fixture torta.

### 5.2 `[60]` — CONTRAPOSITIVA: a tolerância não virou passe livre

Fixture: `$B/fx/f60` — as duas formas medidas em 4.4 que **não** compõem, `.RequireAuthorization(p => p.RequireRole("admin"))` e `.Produces<Foo>(200)` entre o grupo e o verbo.

Asserções: nenhuma rota é emitida para elas; `mapgroup-unindexed` **e** `route-site-unindexed` são reportados. É aqui que a asserção de `mapgroup-unindexed` que sai de `[31]` volta a morar, agora sobre a forma em que ela é verdadeira.

*Como falha hoje:* **não falha — ele nasce verde**, e a revisão 1 legitimava isso com o argumento errado. Medido em 4.4, produção e protótipo devolvem saída idêntica sobre `f60`: `rotas: (nenhuma)` e `kinds: mapgroup-unindexed, route-site-unindexed`. Ele não é red-first, é o **controle de contenção** de `[59]`.

**O que prova a morte de `[60]` é a mutação M7 (eixo da FORMA do argumento), não a M2 (eixo da POSIÇÃO), e a revisão 1 errava aqui.** Os dois eixos são ortogonais, e a fixture de `[60]` não tem nenhum elo antes do primeiro `MapGroup` — então mutação posicional nenhuma pode tocá-la, sob qualquer primitivo que o implementador escolha. Medido lado a lado:

```
$ for L in lib-proto lib-m2 lib-m7; do for f in f40 f60; do echo "== $f :: $L =="; node $B/fxrun.mjs $B/$L $B/fx/$f; done; done
== f40 :: lib-proto ==   rotas: GET /a/x                    kinds: mapgroup-unindexed
== f60 :: lib-proto ==   rotas: (nenhuma)                   kinds: mapgroup-unindexed, route-site-unindexed
== f40 :: lib-m2 ==      rotas: GET /a/x | GET /b/y         kinds: (nenhum)
== f60 :: lib-m2 ==      rotas: (nenhuma)                   kinds: mapgroup-unindexed, route-site-unindexed
== f40 :: lib-m7 ==      rotas: GET /a/x                    kinds: mapgroup-unindexed
== f60 :: lib-m7 ==      rotas: GET /p1/lam | GET /p2/gen   kinds: (nenhum)
```

Sob **M2** a fixture de `[60]` é **byte a byte igual ao verde** — a mutação não a toca — enquanto `[40]` cai. Sob **M7** é o inverso: `[60]` passa a emitir `GET /p1/lam | GET /p2/gen` com zero irresolúveis, e `[40]` fica intacto. Um cenário de contenção que nasce verde e cuja morte é provada por mutação é legítimo; um cenário que nasce verde e **nunca** é provado é o gate morto que esta suíte combate, e a revisão 1 entregava `[60]` na segunda condição enquanto declarava a primeira.

### 5.3 `[61]` — PBT da composição da cadeia

A rule `testing/property-based-testing.md` e a invariante 5 pedem PBT onde há espaço de entrada, e um reconhecedor de cadeia é um parser: o espaço é o produto entre número de grupos e número/posição de elos intercalados.

**Propriedade:** para `k` grupos com literal e `j` elos não-rota intercalados, o path composto é a concatenação dos `k` literais mais o path do verbo, independentemente de `j` e das posições.

**Executei o PBT nesta rodada**, e a revisão 1 publicava os números sem publicar o gerador nem a seed — o que os tornava irreproduzíveis por construção. O driver inteiro fica aqui, e com ele a seed:

```javascript
// $B/pbt-cadeia.mjs — uso: node pbt-cadeia.mjs <dir da lib> <seed> <runs>
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const libdir = process.argv[2];
const seed = Number(process.argv[3] || 1);
const runs = Number(process.argv[4] || 120);
const { scanRoutes } = await import(libdir + '/route-scan.mjs');
const { forAll, gen, makeRandom } = await import(libdir + '/pbt.mjs');
const ELOS = ['WithTags("t")', 'RequireAuthorization()', 'WithName("n")', 'ExcludeFromDescription()'];
const GRUPOS = ['g00', 'v1', 'internal', 'admin', 'api'];
const gGrupos = gen.array(gen.oneOf(GRUPOS), 1, 3);
const gElos = gen.array(gen.oneOf(ELOS), 0, 3);
const dir = mkdtempSync(join(tmpdir(), 'pbt-cadeia-'));
const arq = join(dir, 'G.cs');
function fonte(grupos, elos) {
  const porGrupo = grupos.map(() => []);
  elos.forEach((e, i) => porGrupo[i % grupos.length].push(e));
  let s = 'app';
  grupos.forEach((g, i) => { s += `.MapGroup("/${g}")`; for (const e of porGrupo[i]) s += `.${e}`; });
  return s + '.MapGet("/fim", H);\n';
}
const prop = (grupos, elos) => {
  writeFileSync(arq, fonte(grupos, elos));
  const { routes } = scanRoutes([dir], { root: dir });
  const esperado = '/' + grupos.join('/') + '/fim';
  return routes.length === 1 && routes[0].method === 'GET' && routes[0].path === esperado;
};
const r = forAll([gGrupos, gElos], prop, { runs, seed });
// Controle de gerador: reconstrói a MESMA sequência (mesma seed, mesmo tamanho progressivo)
// e conta quantos dos casos EXECUTADOS carregavam ao menos um elo intercalado.
const rnd = makeRandom(seed);
const executados = r.ok ? runs : r.runs;
let comElo = 0;
for (let i = 0; i < runs; i++) {
  const size = runs === 1 ? 1 : i / (runs - 1);
  const grupos = gGrupos.generate(rnd, size);
  const elos = gElos.generate(rnd, size);
  if (i < executados && elos.length > 0) comElo += 1;
}
rmSync(dir, { recursive: true, force: true });
console.log(JSON.stringify({ ok: r.ok, seed, runs, executados, comElo, counterexample: r.counterexample || null }));
```

```
$ node $B/pbt-cadeia.mjs $B/lib-prod  1 120
{"ok":false,"seed":1,"runs":120,"executados":23,"comElo":1,"counterexample":[["internal"],["WithName(\"n\")"]]}
$ node $B/pbt-cadeia.mjs $B/lib-proto 1 120
{"ok":true,"seed":1,"runs":120,"executados":120,"comElo":65,"counterexample":null}
```

O vermelho é real e o contraexemplo já vem minimizado pelo shrinking: **um** grupo e **um** elo bastam. E o verde vem com o **controle de gerador** que `[15]` já usa neste mesmo arquivo: das 120 execuções, 65 carregaram ao menos um elo intercalado — sem esse controle, a propriedade passaria por degeneração, porque `j = 0` é o caso que já funciona hoje.

**O gate fixa `seed = 1` e `runs = 120`, e assere `comElo >= 40`.** Os dois valores que faltavam na revisão 1 estão nomeados, e o piso vem de medição e não de gosto:

```
$ for s in 1 2 3 7 42; do printf "seed=%s -> " $s; node $B/pbt-cadeia.mjs $B/lib-proto $s 120; done
seed=1  -> {"ok":true,...,"comElo":65,...}
seed=2  -> {"ok":true,...,"comElo":57,...}
seed=3  -> {"ok":true,...,"comElo":61,...}
seed=7  -> {"ok":true,...,"comElo":68,...}
seed=42 -> {"ok":true,...,"comElo":64,...}
```

Cinco seeds, faixa de 57 a 68 sobre 120. O piso de **40** — um terço das execuções — fica com margem larga abaixo do mínimo medido e é **propriedade, não contagem**: ele reprova a degeneração do gerador (o caso em que quase nenhum caso carrega elo) sem depender do valor exato que a seed 1 produz. É a forma que a invariante 14 pede quando o número é do próprio gate e não da árvore.

### 5.4 `[62]` — o universo pula a subárvore alheia, e ANUNCIA

Fixture em `$TMPDIR` (`$B/fx/poda`), três diretórios irmãos: `proprio/` com uma rota, `aninhado/` contendo um `.git` e uma rota, e `.forge.bak-1/` com uma rota.

Asserções: só a rota de `proprio/` é emitida; o campo `skipped` existe, tem duas entradas, e cada uma nomeia **o motivo e o diretório**.

*Como falha hoje:*

```
$ node $B/podarun.mjs $B/lib-prod  $B/fx/poda
  rotas: GET /alheio/nao | GET /backup/velho | GET /meu/ok
  skipped: (o campo não existe no objeto devolvido)
$ node $B/podarun.mjs $B/lib-proto $B/fx/poda
  rotas: GET /meu/ok
  skipped: backup-de-update .forge.bak-1 | repositorio-aninhado aninhado
```

As três asserções falham na produção: as duas rotas alheias saem, e o campo de anúncio não existe — `grep -c 'skipped' template/.forge/scripts/lib/route-scan.mjs` devolve **0** (3.7). É ausência de funcionalidade.

### 5.5 `[63]` — a raiz que é ela própria um repositório não é podada

Fixture (`$B/fx/raiz`): um diretório com `.git` **na raiz** da varredura e um arquivo de rota dentro.

Asserção: a rota é emitida, e `skipped` está vazio.

*Como falha hoje:* passa hoje, porque a poda não existe.

```
$ node $B/podarun.mjs $B/lib-prod  $B/fx/raiz
  rotas: GET /raiz/ok
  skipped: (o campo não existe no objeto devolvido)
$ node $B/podarun.mjs $B/lib-proto $B/fx/raiz
  rotas: GET /raiz/ok
  skipped: [] (vazio)
```

É o **controle** do sexto caso de 3.5 — o único cuja violação zeraria o universo —, e ele é provado por mutação em 6 (M4), com o contrafactual medido.

### 5.6 `[64]` — a poda é opt-in, e o universo dos gates de governança não muda

Asserção: `collect()` chamado **sem** a opção, sobre a mesma fixture de `[62]`, devolve os três arquivos; chamado **com** a opção, devolve um. É a retrocompatibilidade de 3.6 assertada por propriedade, e não por confiança na leitura do diff.

*Como falha hoje:* falha na metade "com a opção", porque a opção não existe e é ignorada em silêncio.

```
$ node $B/optin.mjs $B/lib-prod  $B/fx/poda
  collect() SEM a opção: 3 arquivo(s)
  collect() COM a opção: 3 arquivo(s), 0 poda(s)
$ node $B/optin.mjs $B/lib-proto $B/fx/poda
  collect() SEM a opção: 3 arquivo(s)
  collect() COM a opção: 1 arquivo(s), 2 poda(s)
```

```javascript
// $B/optin.mjs
const [lib, dir] = process.argv.slice(2);
const { collect } = await import(lib + '/source-scan.mjs');
const EXTS = new Set(['.cs']);
const sem = collect([dir], { exts: EXTS });
let podadas = 0;
const com = collect([dir], { exts: EXTS, pruneForeign: true, onPrune: () => { podadas += 1; } });
console.log(`  collect() SEM a opção: ${sem.length} arquivo(s)`);
console.log(`  collect() COM a opção: ${com.length} arquivo(s), ${podadas} poda(s)`);
```

### 5.7 O contador de controle, e ONDE ele mora

`w132` **não tem contador**:

```
$ grep -c 'SCEN' tests/w132-route-surface-gate.sh
0
$ grep -c 'forge_universe_check' tests/w132-route-surface-gate.sh
0
$ tail -1 tests/w132-route-surface-gate.sh
echo "OK"
```

Um gate de 1.958 linhas e 59 cenários que não publica quantos cenários rodou é a forma exata do que a invariante 3 proíbe: uma saída antecipada em qualquer ponto deixa a suíte verde sobre metade das asserções.

**A revisão 1 prescrevia a colocação errada, e ela não fecha a ameaça que ela própria nomeia.** A revisão 1 mandava contar "no idioma que `w190` já usa (`SCEN` incrementado por cenário, `forge_universe_check` no fecho)". Conferido, `w190` de fato confere no fim do arquivo, em statement normal:

```
$ awk 'NR>=331 && NR<=332' tests/w190-pre-push-gate-reader-gate.sh
forge_universe_check "w190/cenarios" "$SCEN" "cenário(s) de push" "canal real (git push)" "$WS" \
  || { echo "FAIL [8]: nenhum cenário executado"; exit 1; }
$ grep -n '^trap' tests/w190-pre-push-gate-reader-gate.sh
54:trap 'rm -rf "$T"' EXIT
```

E uma conferência no fecho do arquivo **nunca é alcançada** por uma saída antecipada — que é precisamente o desfecho contra o qual ela existiria. Reproduzido em bash, com os dois arranjos lado a lado e um `exit 0` plantado no meio:

```
$ for s in fecho trap; do for p in 0 1; do PLANTA=$p ./$s.sh; echo "  ^ $s.sh PLANTA=$p rc=$?"; done; done
fecho.sh PLANTA=0 -> rc=0 | [0] [1] [2] OK
fecho.sh PLANTA=1 -> rc=0 | [0] [1]
trap.sh  PLANTA=0 -> rc=0 | [0] [1] [2] OK
trap.sh  PLANTA=1 -> rc=1 | [0] [1] FAIL SCEN=2 < 3
```

Com a conferência no fecho, o `exit 0` plantado sai **verde com rc 0**, com e sem `SCEN_MIN`, porque a saída antecipada nunca alcança a linha da conferência. Só com a conferência dentro do `trap EXIT` o mesmo `exit 0` produz `FAIL SCEN=2 < 3` e rc 1.

**Decisão fechada, saída (a) do veredito:** a conferência de `SCEN_MIN` mora no **`trap EXIT` do `w132`**, e ela **compõe** com o `trap 'rm -rf "$T"' EXIT` que já existe em `tests/w132-route-surface-gate.sh:83` — capturando `$?` antes de qualquer coisa e reemitindo-o no fim, para que uma reprovação real de cenário não seja mascarada. A forma exata que eu executei, e portanto a única que esta especificação prescreve:

```bash
#!/usr/bin/env bash
set -euo pipefail
T="$(mktemp -d "${TMPDIR:-/tmp}/m6b.XXXXXX")"
SCEN_MIN=3
SCEN=0
fecho() {
  rc=$?
  rm -rf "$T"
  if [ "$rc" -eq 0 ] && [ "$SCEN" -lt "$SCEN_MIN" ]; then
    echo "FAIL SCEN=$SCEN < $SCEN_MIN"
    exit 1
  fi
  exit "$rc"
}
trap fecho EXIT
echo "[0]"; SCEN=$((SCEN + 1))
echo "[1]"; SCEN=$((SCEN + 1))
[ "${PLANTA:-0}" = "1" ] && exit 0
echo "[2]"; SCEN=$((SCEN + 1))
echo "OK"
```

Três propriedades do arranjo, as três medidas:

```
$ /bin/bash --version | head -1
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ /bin/bash -n trap.sh && echo "bash -n limpo"
bash -n limpo
$ PLANTA=1 /bin/bash ./trap.sh;  echo "rc=$?"      # saída antecipada
[0] [1] FAIL SCEN=2 < 3   rc=1
$ ./trap-falha.sh; echo "rc=$?"                     # reprovação REAL de cenário
[0] FAIL [1]: asserção real quebrou   rc=1
```

A guarda `[ "$rc" -eq 0 ]` é o que impede que o contador mascare uma reprovação real: com um cenário falhando de verdade, o trap reemite rc 1 e a mensagem original, sem acrescentar ruído. O `SCEN=0` é declarado **antes** do `trap`, para que `set -u` não estoure no fecho de uma saída precoce. E o arranjo passa em `bash 3.2`, que é a invariante 8.

`SCEN_MIN = 65` no fecho desta onda — o denominador re-derivado com o comando de 5 (59 hoje) mais `[59]`, `[60]`, `[61]`, `[62]`, `[63]` e `[64]`. **Este é o único literal desta especificação que vira asserção de gate**, e ele é a exceção que a invariante 14 nomeia: denominador de cenários do próprio gate, fixo por construção, cuja divergência é justamente o achado. Nenhum cenário de `w132` é condicionado ao ambiente — todos operam sobre fixture de arquivo —, então não há segunda constante como em `w190`.

---

## 6. Prova de mutação

Alvos: `template/.forge/scripts/lib/route-scan.mjs` e `template/.forge/scripts/lib/source-scan.mjs`. Os dois são **rastreados e distribuídos no pacote**, de modo que o protocolo de LDG-0175 vale integralmente: a árvore é copiada para `$TMPDIR` e a mutação é aplicada na **cópia**, nunca no arquivo de produção.

Protocolo, na ordem, com o cuidado de LDG-0164 e de `feedback-mutacao-fantasma-restore`:

1. `shasum -a 256` do alvo íntegro, guardado.
2. Mutação por **substituição integral** do arquivo a partir de uma cópia preparada em `$TMPDIR`. Nunca `perl -0pi -e` com `$` do lado direito — em perl aquilo é variável vazia e a mutação vira no-op enquanto o `cmp` confirma que o arquivo mudou.
3. `shasum` do mutado e asserção `mutado != íntegro`. Sem ela, o passo 4 mede o engano.
4. Rodar o cenário nomeado e exigir **FAIL**, com a mensagem que a asserção declara. FAIL por outra mensagem não conta.
5. Restaurar por cópia; `shasum` e asserção `depois == antes`.
6. **Recontrole:** rodar o cenário de novo e exigir **PASS**.

**As sete linhas têm contrafactual MEDIDO nesta revisão.** A revisão 1 entregava três medidas e três declaradas; a invariante 16 pede as sete medidas antes de escritas, e o protótipo da seção 0 tornou isso barato.

| # | Mutação | O gate deve ACUSAR em | Contrafactual **medido** |
|---|---|---|---|
| M1 | `CHAIN` volta à forma adjacente de hoje (= `lib-prod`) | `[59]` e `[61]` | `node $B/fxrun.mjs $B/lib-prod $B/fx/f59` → `rotas: (nenhuma)` com `mapgroup-unindexed, route-site-unindexed`; `node $B/pbt-cadeia.mjs $B/lib-prod 1 120` → `{"ok":false,"executados":23,"comElo":1,"counterexample":[["internal"],["WithName(\"n\")"]]}` |
| M2 | a tolerância a elo não-rota passa a valer **também antes** do primeiro `MapGroup` (eixo POSIÇÃO) | **`[40]` (existente), e SÓ ele** | `node $B/fxrun.mjs $B/lib-m2 $B/fx/f40` → `rotas: GET /a/x \| GET /b/y` e `kinds: (nenhum)` — path inventado a partir de `Helper.Build()`, cujo prefixo real ninguém sabe. Sobre `f60` a saída é **idêntica ao verde**, e é por isso que M2 **não** prova `[60]` |
| M7 | a tolerância passa a aceitar **argumento com parênteses aninhados e argumento de tipo genérico** no elo (eixo FORMA) | **`[60]`** | `node $B/fxrun.mjs $B/lib-m7 $B/fx/f60` → `rotas: GET /p1/lam \| GET /p2/gen` e `kinds: (nenhum)`; sobre `f40` a saída é intacta (`GET /a/x`, `mapgroup-unindexed`). É a mutação complementar de M2, e a única que discrimina `[60]` |
| M3 | remove a poda de repositório aninhado, mantendo a de `.forge.bak` | `[62]`, asserção das rotas | `node $B/podarun.mjs $B/lib-m3 $B/fx/poda` → `rotas: GET /alheio/nao \| GET /meu/ok` e `skipped: backup-de-update .forge.bak-1` |
| M4 | a poda passa a valer **também para a raiz** da varredura | `[63]`, as duas asserções | `node $B/podarun.mjs $B/lib-m4 $B/fx/raiz` → `rotas: (nenhuma)` e `skipped: repositorio-aninhado` nomeando a própria raiz; sobre `fx/poda` a saída é idêntica ao verde, então `[63]` é o único discriminador |
| M5 | mantém a poda e remove o **anúncio** (`onPrune = null`) | `[62]`, asserção do campo | `node $B/podarun.mjs $B/lib-m5 $B/fx/poda` → `rotas: GET /meu/ok` (correto!) e `skipped: [] (vazio)`. É a mutação mais importante da matriz, porque é a única em que o comportamento observável fica certo e a prestação de contas some |
| M6 | `SCEN_MIN` deixa de ser conferido no trap (só a guarda de universo `> 0`) | o próprio fecho de `w132` | com o `exit 0` plantado: `trap.sh` → `rc=1` e `FAIL SCEN=2 < 3`; `trap-m6.sh` (mesma estrutura, com `[ "$SCEN" -lt 1 ]` no lugar de `SCEN_MIN`) → `rc=0`, verde. Discrimina, e só discrimina porque a conferência está no trap (5.7) |

Duas leituras que a matriz obriga e que a revisão 1 não fazia:

**M2 e M7 são eixos ortogonais, e é por isso que são duas linhas.** Uma implementação que tolere elo em posição errada é derrubada por `[40]`; uma que tolere argumento de forma errada é derrubada por `[60]`. Uma matriz com só uma delas deixa metade do espaço de erro sem gate, e foi exatamente isso que a revisão 1 entregou.

**M3, M4 e M5 tocam duas fixtures cada e discriminam por asserções diferentes.** M3 mata a asserção de rota de `[62]` e deixa a de campo passar pela metade; M5 faz o inverso; M4 não toca `[62]` e mata `[63]` inteiro. Nenhum par colapsa no mesmo cenário, e a checagem que prova isso é a coluna de contrafactual, rodada uma a uma.

---

## 7. Retrocompatibilidade

**Quem tem esse código instalado.** `template/.forge/scripts/lib/route-scan.mjs` e `lib/source-scan.mjs` são distribuídos no pacote e existem hoje na `.forge/scripts/lib/` de todo consumidor que rodou `forge update`.

**Quem CHAMA esse código em produção: ninguém.**

```
$ grep -rln "route-scan" template/ bin/ plugin/
template/.forge/scripts/lib/api-surface.mjs
template/.forge/scripts/lib/route-scan.mjs
$ grep -rln "SUR-01" template/ tests/
template/.forge/scripts/lib/api-surface.mjs
template/.forge/scripts/lib/route-scan.mjs
template/.forge/scripts/lib/tasks-graph.mjs
template/.forge/scripts/lib/validate-spec.mjs
tests/w130-tasks-graph-gate.sh
tests/w132-route-surface-gate.sh
$ grep -rln "source-scan" tests/ | wc -l
0
```

Exatamente dois arquivos citam `route-scan`, e os dois são as próprias bibliotecas; `SUR-01` aparece em quatro libs e dois gates. Nenhum script, comando, hook ou executor invoca `scanRoutes` ou `surContractToCode`, e **nenhum gate exercita `lib/source-scan.mjs` diretamente**. **O único consumidor real do oráculo de rota é o gate `w132`.**

Isso decide o risco de LDG-0162 por completo: a mudança de comportamento — cadeias que antes não compunham passam a compor — não alcança nenhum caminho de produção de nenhum consumidor. O que ela alcança é o gate, e o gate está nominalmente tratado em 4.6.

**A mudança de assinatura é aditiva.** `scanRoutes` passa a devolver `skipped` como terceiro campo; todos os chamadores medidos desestruturam `{ routes }` ou `{ routes, unresolved }`, que continuam funcionando. `collect` ganha `pruneForeign` e `onPrune` com default que reproduz o comportamento de hoje, e `[64]` assere isso com medição (5.6).

**Os três gates de governança não mudam de universo**, por decisão de 3.6 e por asserção de 5.6. Medido: `forge-harness` e `axis-fare-validator` teriam delta zero de qualquer modo; `payments` teria delta de 100% no universo de código, e é ele que justifica o opt-in.

**O que muda para quem varrer um diretório com subárvore aninhada** — e são **sete dos 33 diretórios de topo do parque**, três deles repositório próprio e quatro guarda-chuvas (3.4) — é que a varredura de rota passa a não olhar para ela, **anunciando** em `skipped`. Quem precisar do contrário passa a subárvore como raiz explícita (3.5, linhas 6 e 7).

**O que a onda NÃO cobre e fica registrado:** um diretório-filho que é **symlink** já sai do universo hoje, sem anúncio, e continua saindo (3.5, linha 8). É silêncio preexistente, com dono anterior a esta onda, e vira item de ledger em vez de escopo daqui.

---

## 8. Onde entram PBT, contrato, integração e E2E

**PBT: entra, e o vermelho foi executado.** É `[61]`, seção 5.3, com driver publicado, seed fixada, contraexemplo minimizado e controle de gerador com piso. A superfície é um reconhecedor de cadeia, que é parser, que é exatamente o que a invariante 5 nomeia.

**Teste de contrato: entra em uma metade e não se aplica na outra.** A fronteira publicada aqui é a assinatura de retorno de `scanRoutes` e a assinatura de opções de `collect` — as duas são consumidas hoje por um único chamador dentro do próprio repositório, medido em 7. Não há adotante externo cujo código quebre, e por isso não nasce um gate de contrato próprio; o que entra é `[64]`, que fixa por asserção a metade que tem risco real (o default de `collect` preserva o universo). Registro a assimetria em letra para que ninguém a confunda com esquecimento: se um segundo chamador aparecer, `[64]` é o lugar de crescer.

**Integração: entra, e é a razão de `[62]` existir com fixture de três diretórios em vez de um teste unitário de `collect`.** O defeito de LDG-0029 não é de função — é de **quem chama a função com que universo**. Um teste unitário de `collect` com a opção ligada nasceria verde e não diria nada sobre `scanRoutes` estar ou não ligando a opção. `[62]` exercita `scanRoutes` de ponta a ponta e olha o efeito na saída, que é o canal em que o defeito se manifesta — e M5 prova que a metade do anúncio não passa por acidente.

**E2E: NÃO se aplica, e a justificativa é medida, não conveniente.** E2E aqui significaria exercitar o oráculo pelo caminho por que ele roda em produção — e medido em 7, **não existe caminho de produção**: nenhum script, comando ou hook invoca `scanRoutes`. Não há canal de entrega para provar, porque não há entrega. Isso não é uma folga: é o achado que a seção 9 usa, porque uma biblioteca sem chamador é exatamente o estado em que LDG-0010 tenta mexer.

---

## 9. LDG-0010 — a recomendação, e a medição que a sustenta

### 9.1 O que o item pede, e o que a onda destrava dele

LDG-0010 tem duas pré-condições escritas. A **(1)** é "as `MapGroup()` não ancoradas, registradas em LDG-0162" — e ela **cai nesta onda**: medido em 4.3, o repositório de referência passa a zero irresolúveis, o que torna o SUR-01 conclusivo ali pela primeira vez. A **(2)** é a implementação: passar rota real em vez de `apiPaths()` e `enforceable:true` na chamada de `checkSurfaceCoverage`. O sítio exato:

```
$ grep -n "checkSurfaceCoverage(rows, parsed" template/.forge/scripts/lib/validate-spec.mjs
314:      for (const f of checkSurfaceCoverage(rows, parsed, { apiPaths: apiLayerPaths() }))
```

É `validate-spec.mjs:314`, e não `:302` como a revisão 1 escrevia — `:302` é a linha de despacho do SRF-00, dois checks acima.

O crédito é da redação do ledger, que estava certa sobre o bloqueio: era LDG-0162, não LDG-0029. A remedição confirmou isso e o desbloqueou.

### 9.2 O oráculo que o item quer trocar é pior do que o registro dizia

O ledger chama `apiPaths()` de "heurística de path derivada de graph.json, nunca de rota". Medi o que ela devolve no repositório de referência:

```
$ node -e 'const g=JSON.parse(require("fs").readFileSync("/Users/milton/Documents/projects/axis-go-cloud/.forge/graph/graph.json","utf8"));
           const a=(g.nodes||[]).filter(n=>n&&n.layer==="api");
           console.log("total layer:api =",a.length); console.log(a.slice(0,2).map(n=>n.id).join("\n"))'
total layer:api = 815
apps/admin-portal/src/features/acquirers/api/acquirerConfig.types.ts
apps/admin-portal/src/features/acquirers/api/index.ts
```

**815 nodes** com `layer: 'api'`, e os dois primeiros em ordem são um arquivo de **tipos** e um **barril de reexport** de uma feature de front-end — artefatos que **consomem** API, não a expõem. A revisão 1 citava `useAcquirers.ts` e `useAkuaConfig.ts`, que estão no mesmo diretório e são *hooks* de React; a substância é a mesma e o par estava errado, corrigido acima pelo comando que o produz.

E medi o quanto essa heurística muda o veredito:

```
$ node $B/srf01.mjs $H/template/.forge/scripts/lib /Users/milton/Documents/projects/axis-go-cloud
{"repo":"...axis-go-cloud","changes":66,"comRequirements":35,"linhasChecklist":188,
 "apiNodes":815,"achadosSemGrafo":25,"achadosComGrafo":24,"changesComAchado":8}
```

```javascript
// $B/srf01.mjs — uso: node srf01.mjs <lib do harness> <raiz do repo consumidor>
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const lib = process.argv[2], repo = process.argv[3];
const { parseTasks, parseSurfaceChecklist, checkSurfaceCoverage } = await import(lib + '/tasks-graph.mjs');
const gp = join(repo, '.forge/graph/graph.json');
let apiPaths = [];
if (existsSync(gp)) { const g = JSON.parse(readFileSync(gp, 'utf8')); apiPaths = (g.nodes || []).filter((n) => n && n.layer === 'api').map((n) => n.id); }
let changes = 0, comReq = 0, linhas = 0, semGrafo = 0, comGrafo = 0, changesComAchado = 0;
for (const estado of ['active', 'archived']) {
  const base = join(repo, '.forge/specs', estado);
  if (!existsSync(base)) continue;
  for (const d of readdirSync(base, { withFileTypes: true })) {
    if (!d.isDirectory()) continue;
    changes += 1;
    const req = join(base, d.name, 'requirements.md'); const tk = join(base, d.name, 'tasks.md');
    if (!existsSync(req)) continue;
    comReq += 1;
    const rows = parseSurfaceChecklist(readFileSync(req, 'utf8'));
    linhas += rows.length;
    const parsed = parseTasks(existsSync(tk) ? readFileSync(tk, 'utf8') : '');
    const a = checkSurfaceCoverage(rows, parsed, {});
    const b = checkSurfaceCoverage(rows, parsed, { apiPaths });
    semGrafo += a.length; comGrafo += b.length;
    if (b.length) changesComAchado += 1;
  }
}
console.log(JSON.stringify({ repo, changes, comRequirements: comReq, linhasChecklist: linhas,
  apiNodes: apiPaths.length, achadosSemGrafo: semGrafo, achadosComGrafo: comGrafo, changesComAchado }));
```

Rodando `checkSurfaceCoverage` sobre os 66 changes do repositório de referência, sem grafo dá **25** achados e com os 815 nodes dá **24**. A heurística suprime **um** achado em vinte e cinco. Ela não é um oráculo fraco; ela é quase inerte. O par 25/24 foi a medição que o revisor não conseguiu reproduzir por falta do driver; o driver está acima e o par reproduz.

### 9.3 Os três bloqueios novos, que o ledger não tinha

**Bloqueio A — o insumo não existe onde o check roda.** Rodei o cruzamento sobre os 15 changes arquivados deste repositório, pelo mesmo caminho que `validate-spec.mjs` usa (o bloco SRF só é alcançado dentro de `reached('tasks-ready')` e com `tasks.md` legível):

```
$ node $B/insumo.mjs $H/template/.forge/scripts/lib $H/.forge/specs/archived
{"changes":15,"comHeadingREQ":9,"comSecaoChecklist":7,"comLinhaParseavel":5,
 "linhasChecklist":16,"linhasQueNomeiamAPI":0,"SRF01":0,"SRF02":4,"SRF03":0}
```

```javascript
// $B/insumo.mjs
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const lib = process.argv[2], dir = process.argv[3];
const { parseSurfaceChecklist, namesApiSurface, checkSurfaceCoverage,
        checkSurfaceChecklistPresence, checkSurfaceChecklistLiteral, parseTasks } = await import(lib + '/tasks-graph.mjs');
let changes = 0, comReq = 0, comSecao = 0, comLinha = 0, linhas = 0, linhasApi = 0, srf1 = 0, srf2 = 0, srf3 = 0;
for (const d of readdirSync(dir, { withFileTypes: true })) {
  if (!d.isDirectory() || !existsSync(join(dir, d.name, 'manifest.yaml'))) continue;
  changes += 1;
  const rp = join(dir, d.name, 'requirements.md');
  if (!existsSync(rp)) continue;
  const t = readFileSync(rp, 'utf8');
  if (/^##\s+REQ-/m.test(t)) comReq += 1;
  if (/Checklist/i.test(t)) comSecao += 1;
  const rows = parseSurfaceChecklist(t);
  if (rows.length) comLinha += 1;
  linhas += rows.length;
  linhasApi += rows.filter((r) => namesApiSurface(r.surface)).length;
  const tk = join(dir, d.name, 'tasks.md');
  if (!existsSync(tk)) continue;               // validate-spec.mjs não alcança o bloco SRF sem tasks.md
  const parsed = parseTasks(readFileSync(tk, 'utf8'));
  srf1 += checkSurfaceCoverage(rows, parsed, {}).length;
  srf2 += checkSurfaceChecklistPresence(t).length;
  srf3 += checkSurfaceChecklistLiteral(rows).length;
}
console.log(JSON.stringify({ changes, comHeadingREQ: comReq, comSecaoChecklist: comSecao,
  comLinhaParseavel: comLinha, linhasChecklist: linhas, linhasQueNomeiamAPI: linhasApi,
  SRF01: srf1, SRF02: srf2, SRF03: srf3 }));
```

Dos 15 changes arquivados, nove têm heading `## REQ-`, sete têm a seção de checklist, cinco produzem linhas parseáveis, **16 linhas no total — e ZERO delas nomeiam superfície de API** pelo predicado `namesApiSurface` da própria lib. SRF-01 dispara **zero** vezes, SRF-03 zero, e SRF-02 dispara **quatro** — a revisão 1 dizia três, e a correção é minha, saída do driver acima. Promover a bloqueante um check que, no corpus inteiro deste repositório, examinou zero condições é promover nada: é a invariante 3 vista pelo avesso, um gate que aprova por não ter olhado, agora com autoridade para reprovar.

**Bloqueio B — onde o insumo existe, a promoção reprova o parque.** Rodei o mesmo cruzamento sobre todos os repositórios de `~/Documents/projects` com `.forge/specs/`, e desta vez com os **dois** denominadores explícitos, que é o que faltava na revisão 1:

```
$ node $B/parque.mjs $H/template/.forge/scripts/lib ~/Documents/projects
Axis.AcqSimulator      archived  changes=  4  com-requirements=  3  linhas-API= 12  changes-com-achado= 3  achados= 12
Axis.PadSimulator      active    changes=  4  com-requirements=  1  linhas-API=  4  changes-com-achado= 0  achados=  0
Axis.PadSimulator      archived  changes= 11  com-requirements=  7  linhas-API= 32  changes-com-achado= 3  achados= 16
axis-fare-validator    active    changes=  6  com-requirements=  4  linhas-API=  2  changes-com-achado= 1  achados=  2
axis-fare-validator    archived  changes= 49  com-requirements= 23  linhas-API= 11  changes-com-achado= 6  achados= 11
axis-go-cloud          active    changes=  9  com-requirements=  5  linhas-API= 21  changes-com-achado= 2  achados= 16
axis-go-cloud          archived  changes= 57  com-requirements= 30  linhas-API= 18  changes-com-achado= 7  achados=  9
azim-crm               active    changes=  6  com-requirements=  2  linhas-API=  4  changes-com-achado= 1  achados=  4
azim-crm               archived  changes=  9  com-requirements=  6  linhas-API=  6  changes-com-achado= 2  achados=  6
collatra               archived  changes=  3  com-requirements=  3  linhas-API=  4  changes-com-achado= 1  achados=  4
cpf-cnpj-validator     archived  changes=  1  com-requirements=  1  linhas-API=  0  changes-com-achado= 0  achados=  0
forge-harness          archived  changes= 15  com-requirements=  9  linhas-API=  0  changes-com-achado= 0  achados=  0
payments               active    changes=  4  com-requirements=  4  linhas-API=  0  changes-com-achado= 0  achados=  0
payments               archived  changes=  1  com-requirements=  1  linhas-API=  0  changes-com-achado= 0  achados=  0

ATIVOS no parque: 29 changes com manifest.yaml | 16 deles com requirements.md | 4 bloqueariam | 22 achados
```

```javascript
// $B/parque.mjs — uso: node parque.mjs <lib do harness> <diretório-pai dos repositórios>
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
const lib = process.argv[2];
const { parseTasks, parseSurfaceChecklist, checkSurfaceCoverage, namesApiSurface } = await import(lib + '/tasks-graph.mjs');
const base = process.argv[3];
const tot = { ativos: 0, ativosComReq: 0, bloqueiam: 0, achados: 0 };
for (const repo of readdirSync(base, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort()) {
  for (const estado of ['active', 'archived']) {
    const dir = join(base, repo, '.forge/specs', estado);
    if (!existsSync(dir)) continue;
    let changes = 0, comReq = 0, linhas = 0, comAchado = 0, achados = 0;
    for (const d of readdirSync(dir, { withFileTypes: true })) {
      if (!d.isDirectory() || !existsSync(join(dir, d.name, 'manifest.yaml'))) continue;
      changes += 1;
      const req = join(dir, d.name, 'requirements.md');
      if (!existsSync(req)) continue;
      comReq += 1;
      const rows = parseSurfaceChecklist(readFileSync(req, 'utf8'));
      linhas += rows.filter((r) => namesApiSurface(r.surface)).length;
      const tk = join(dir, d.name, 'tasks.md');
      const parsed = parseTasks(existsSync(tk) ? readFileSync(tk, 'utf8') : '');
      const f = checkSurfaceCoverage(rows, parsed, {});
      if (f.length) { comAchado += 1; achados += f.length; }
    }
    if (!changes) continue;
    console.log(`${repo.padEnd(22)} ${estado.padEnd(9)} changes=${String(changes).padStart(3)}  com-requirements=${String(comReq).padStart(3)}  linhas-API=${String(linhas).padStart(3)}  changes-com-achado=${String(comAchado).padStart(2)}  achados=${String(achados).padStart(3)}`);
    if (estado === 'active') { tot.ativos += changes; tot.ativosComReq += comReq; tot.bloqueiam += comAchado; tot.achados += achados; }
  }
}
console.log(`\nATIVOS no parque: ${tot.ativos} changes com manifest.yaml | ${tot.ativosComReq} deles com requirements.md | ${tot.bloqueiam} bloqueariam | ${tot.achados} achados`);
```

**Quatro changes ativos ficariam sem poder transitar no dia em que `enforceable:true` for publicado, e a proporção depende de qual denominador se usa.** São 4 de 16 changes ativos **que têm `requirements.md`** — 25% —, e 4 de 29 changes ativos **com `manifest.yaml`** — 13,8%. A revisão 1 escrevia "4 dos dezesseis changes ativos do parque — 25%" sem qualificar, e a frase estava certa sobre o numerador e ambígua sobre o denominador; os dois estão acima. Os 13 changes ativos sem `requirements.md` nunca seriam reprovados porque o SRF-01 só roda dentro de `if (reqText)` (`validate-spec.mjs:306`), então o denominador defensável é 16 — mas a proporção que um leitor de fora ouve como "um quarto do parque" é a de 29, e ela é 13,8%.

A tabela também ganhou duas linhas que a revisão 1 não tinha (`cpf-cnpj-validator archived` e `payments archived`), e as duas são zero — o que não muda nada e é justamente o ponto: uma tabela que se diz do parque inteiro e omite linhas é a armadilha D, mesmo quando as linhas omitidas são zeros.

`validate-spec.mjs` é chamado por `spec-transition.sh:137` em **toda** transição, e por `spec-new.sh:139` na criação, **com rollback do change em caso de reprovação**. E olhando o texto dos achados, a maioria não é defeito de código: são linhas em prosa (`"tela admin-portal + endpoints internos bff"`, `"rotina de rotação + auditoria"`) e linhas com a coluna "Coberto por task" vazia. Bloquear uma spec por uma célula em branco é o gate que o adotante desliga na primeira semana — e o comentário de `tasks-graph.mjs:335-336` já escreve isso: *"promover direto inundaria specs já escritas, e um gate que chega bloqueando o passado é um gate que a pessoa desliga"*.

**Bloqueio C — o oráculo de rota real não cabe onde o item quer colocá-lo, e isso é medido em duas metades.**

*Custo.* `validate-spec.mjs` custa hoje entre **0,795 s e 5,747 s** por change:

```
$ for d in .forge/specs/archived/*/; do [ -f "$d/manifest.yaml" ] || continue; \
    s=$(python3 -c 'import time;print(time.time())'); \
    node template/.forge/scripts/lib/validate-spec.mjs "$d" >/dev/null 2>&1 || true; \
    e=$(python3 -c 'import time;print(time.time())'); \
    python3 -c "print(f'{($e-$s)*1000:.0f} ms  $(basename $d)')"; done | sort -n | sed -n '1p;$p'
795 ms  2026-09-04-gate-assert-visibility
5747 ms  2026-08-03-graph-bin-source
```

Uma varredura de rota sobre o repositório de referência custa, nas seis execuções registradas em 4.3, entre dezenas de segundos e poucos minutos. **A comparação é de faixa contra faixa, e não de literal contra literal**: segundos de um lado, centenas de segundos do outro, com uma a duas ordens de grandeza entre elas, num validador que roda em toda transição e na criação de change. Essa é a única forma em que a medição de tempo de parede sobrevive à ressalva de 4.3, e é assim que ela é usada.

*E a saída óbvia para o custo não funciona.* A ideia natural é varrer só os `paths:` das tasks que cobrem a linha, em vez do repositório inteiro. Medi, sobre a fixture do próprio `w132`, que tem uma cadeia de dois saltos entre três arquivos:

```
DIR INTEIRO              rotas: GET /health/live | POST /internal/v1/widgets/dispatch
                                | GET /internal/v1/widgets/events/stream | … (5)   unresolved: (nenhum)
SÓ Program.cs            rotas: GET /health/live                                    unresolved: producer-not-found
SÓ WidgetEndpoints.cs    rotas: (nenhuma)                                           unresolved: producer-never-invoked
SÓ WidgetStreamEndpoints rotas: (nenhuma)                                           unresolved: producer-never-invoked
```

**Varrer o universo parcial transforma 4 das 5 rotas reais em irresolúvel.** E o SUR-01 se abstém na presença de qualquer irresolúvel, por desenho (`api-surface.mjs:470-488`) — de modo que a versão barata do oráculo devolveria "não pude verificar" quase sempre. O oráculo de rota real exige o repositório inteiro, e o repositório inteiro exige um índice persistido com ciclo de vida próprio — que é a mesma classe de dívida de LDG-0176 (`graph.json` commitado defasado, sem detector), e portanto **um change de spec próprio, não um item de onda**.

### 9.4 Decisão recomendada

**Recomendo `wont-fix` para LDG-0010 tal como está redigido**, com a decisão final sendo do dono, e com a condição de reabertura escrita. O que recebe `wont-fix` é o **veículo**, não o valor: promover o SRF-01 a bloqueante dentro de `validate-spec.mjs` é a coisa errada, por três razões medidas — o insumo não existe onde ele rodaria (9.3-A), onde existe ele reprova quatro changes ativos por prosa e por célula vazia (9.3-B), e o oráculo que o justificaria não cabe naquele processo (9.3-C).

A recomendação **não depende da proporção**. Ela se apoia em três bloqueios independentes, e cairia igual se o denominador fosse 16, 29 ou outro: o bloqueio A é sobre corpus vazio, o C é sobre custo e sobre abstenção estrutural, e nenhum dos dois cita proporção nenhuma.

**O valor já existe implementado e sem chamador.** `surContractToCode` de `lib/api-surface.mjs` é o cruzamento contrato↔código com veredito de três estados — `conclusive` com achados, `inconclusive` com abstenção e blockers —, e medido em 7 e em 8, **nenhum caminho de produção o invoca**. Depois desta onda ele passa a ter, pela primeira vez, um corpus em que devolve `conclusive`.

**Condição de reabertura, escrita para ser verificável:** LDG-0010 volta à mesa quando existir um índice de rotas persistido, com detector de defasagem contra a regeneração (a lição de LDG-0176, e o gate dela compara **ids**, nunca contagem), e um executor que consuma `surContractToCode` fora do caminho de `validate-spec.mjs`. Enquanto isso, o achado de superfície continua sendo aviso — que é o que `tasks-graph.mjs:474-478` diz desde sempre e que a medição de 9.3 acaba de confirmar como calibração correta, e não como timidez.

**Item novo de ledger que esta onda propõe**, com a medição anexada e sem o qual a recomendação acima vira esquecimento: *"cruzamento contrato↔código não tem executor — `surContractToCode` é a única implementação de veredito de três estados sobre superfície de API do harness e nenhum caminho de produção a invoca; o índice de rotas persistido é a pré-condição, e o parque tem 4 changes ativos, de 16 com requirements.md, que o cruzamento acusaria hoje"*.

---

## 10. O que a onda NÃO faz

1. **Não implementa o índice de constante literal.** Alvo zero medido no repositório de referência (3.1, 3.3).
2. **Não promove SRF-01 a bloqueante** e não toca `validate-spec.mjs:314` nem `checkSurfaceCoverage`. Seção 9.
3. **Não liga a poda de universo no default de `collect()`**, portanto não muda o universo de `check-authz`, `check-observability` e `check-data-governance`. O contraexemplo de `payments` (universo de código a zero, 24 repositórios aninhados mais um backup) está em 3.6 e vira item de ledger próprio.
4. **Não liga a poda em `collectDeclaredSurface()`.** Medido nas duas extensões que ela usa: zero podas em 60 arquivos de contrato e em 5 de spec (3.6).
5. **Não estende o reconhecedor de cadeia a elo com argumento lambda ou com argumento de tipo genérico.** Medido em 4.4: os dois degradam para `mapgroup-unindexed`, que é a direção segura, e o repositório de referência não os usa. É justamente essa fronteira que M7 protege (6).
6. **Não cria arquivo de gate novo** e portanto não aloca ordinal (5), e não move o badge de gates do README (14, armadilha A).
7. **Não conserta o silêncio do diretório-filho que é symlink** (3.5, linha 8; 7). Preexistente, medido, vira item de ledger.
8. **Não escreve nada em `axis-go-cloud` nem em nenhum outro consumidor.** Todas as medições deste documento são de leitura.
9. **Não regenera o `graph.json` de ninguém**, embora a medição tenha encontrado nodes de `axis-device-platform` no grafo commitado do repositório de referência — mesma classe de universo, em outro engine (`lib/graph-build.mjs`), e portanto item separado. Registrado aqui para não sumir.

---

## 11. Definição de pronto

1. `w132` verde, com o contador de cenários publicado e `SCEN_MIN` conferido **no `trap EXIT`** (5.7), e os seis novos (`[59]`–`[64]`) presentes. `SCEN_MIN` é o denominador **re-derivado no momento da execução** por `grep -c '^echo "\[' tests/w132-route-surface-gate.sh` mais seis; se o derivado não for 59 naquele instante, há cenário entrando por outra frente e a colisão é resolvida antes de escrever a constante.
2. `[31]` reescrito conforme 4.6, com as duas asserções negativas preservadas e a asserção de `mapgroup-unindexed` reposicionada em `[60]`.
3. `[16]` verde e **byte a byte como está** — nenhuma edição naquele bloco.
4. `[40]` e `[42]` verdes sem edição (medidos intactos em 4.6).
5. As **sete** mutações de 6 provadas, cada uma com controle de checksum e recontrole, e cada uma acusando o cenário que a tabela nomeia — em particular M2 acusando `[40]` e **não** `[60]`, e M7 acusando `[60]` e **não** `[40]`.
6. `[61]` com `seed = 1`, `runs = 120` e a asserção de controle de gerador `comElo >= 40` (5.3).
7. A suíte inteira verde, rodada pelo orquestrador em série.
8. `CHANGELOG.md` em `[Unreleased]`, seção `Fixed`, com as duas correções. O número que importa entra **datado e ancorado**: *"no repositório de referência `axis-go-cloud`, commit `721fc7ec5`, medido em 2026-09-07, a varredura passa de 77 irresolúveis para zero"*. Sem a data e sem o commit ele é um número sobre a árvore viva de um consumidor externo indo para um artefato publicado, que o leitor de amanhã não tem como conferir.
9. Ledger: LDG-0029 e LDG-0162 para `resolved`, cada um com a evidência desta especificação; LDG-0010 com o desfecho que o dono decidir sobre a seção 9; e os **três** itens novos propostos — o de 3.6 (política de universo dos gates de governança), o de 9.4 (executor do cruzamento contrato↔código) e o de 3.5/7 (symlink sai do universo sem anúncio) — abertos.
10. Nenhum arquivo rastreado de `template/` alterado fora de `lib/route-scan.mjs` e `lib/source-scan.mjs` — conferido por `git status` ao fim, que é a segunda metade de LDG-0175.
11. `npm run build:plugin` **não** é necessário, e a conferência que prova isso é `grep -rln "route-scan\|scanRoutes\|surContractToCode" template/.forge/commands plugin/forge` devolvendo vazio (14, armadilha B). Se a implementação acabar tocando algum `.md` de comando, o `build:plugin` volta a ser obrigatório e entra aqui.

## 12. Ordem de execução

1. `[62]`, `[63]`, `[64]` e a poda opt-in em `collect()` mais o campo `skipped` em `scanRoutes()` — é a fatia independente, e ela muda o universo em que a fatia seguinte é medida.
2. `[59]`, `[60]`, `[61]` e a tolerância a elo não adjacente; `[31]` reescrito **no mesmo commit**, porque separá-los deixa a suíte vermelha entre dois commits com dois caminhos errados à mão.
3. O contador e `SCEN_MIN` no `trap EXIT`, por último, porque o denominador só é conhecido depois dos cenários.
4. As sete mutações, com a árvore copiada para `$TMPDIR`.
5. Ledger e `CHANGELOG.md`.

---

## 13. Respostas ao veredito da revisão 1

### 13.1 Os dois bloqueadores

**BLOQUEADOR 1 — falso-verde em `[60]`: ACEITO, e remedido por medição própria.** O revisor está certo e a medição dele reproduz na minha bancada, comando por comando. Rodei M2 e a mutação nova lado a lado (5.2, e a saída está colada lá): sob M2 a fixture de `[60]` devolve saída **byte a byte idêntica ao verde**, porque a fixture não tem nenhum elo antes do primeiro `MapGroup` e M2 é posicional; sob a mutação de argumento, `[60]` passa a emitir `GET /p1/lam | GET /p2/gen` com zero irresolúveis enquanto `[40]` fica intacto. O crédito do diagnóstico e do desenho da mutação complementar é inteiro do revisor. As três correções que ele pediu estão feitas: a matriz ganhou **M7** como linha própria (6), a §5.2 agora nomeia M7 — e não M2 — como a prova de morte de `[60]`, e a linha M2 ficou com `[40]` sozinho, que é o que ela de fato derruba. Acrescentei também, em 6, a leitura que a correção obriga: M2 e M7 são eixos ortogonais e por isso são duas linhas, e uma matriz com só uma delas deixa metade do espaço de erro sem gate.

**BLOQUEADOR 2 — o contrafactual de M6 é falso sob o idioma prescrito: ACEITO, e remedido pela saída (a).** Reproduzi a medição do revisor com script próprio (5.7): com a conferência no fecho do arquivo, um `exit 0` plantado no meio deixa o gate verde com rc 0, com e sem `SCEN_MIN`; só com a conferência dentro de um `trap EXIT` o mesmo `exit 0` produz `FAIL SCEN=2 < 3` e rc 1. Escolhi a **saída (a)** — a conferência mora no `trap EXIT` do `w132` e compõe com o `trap 'rm -rf "$T"' EXIT` da linha 83, capturando `$?` antes e reemitindo-o no fim — porque ela fecha a ameaça que a própria §5.7 nomeia, e a saída (b) apenas trocaria o contrafactual por outro que a colocação fraca ainda discrimina. A §5.7 traz o script inteiro que eu executei, mais três verificações que a escolha obriga e que o veredito não pediu: que o arranjo passa em `bash 3.2` e em `bash -n`, e que uma **reprovação real** de cenário não é mascarada pelo trap (`trap-falha.sh` → rc 1 com a mensagem original). A linha M6 da matriz agora carrega o contrafactual medido nos dois lados, com e sem `SCEN_MIN`.

### 13.2 As medições que não reproduziram

Sete itens. **Cinco remedidos com o comando colado ao lado do número, dois removidos.**

| # | Medição | Desfecho | Onde |
|---|---|---|---|
| 1 | Os dois tempos de parede (93.118 ms e 167.468 ms) | **REMOVIDA** | 4.3 |
| 2 | Os números exatos do PBT (`total: 25`, contraexemplo, 65 de 120) | **REMEDIDA, com driver e seed publicados** | 5.3 |
| 3 | A contagem de `.git` aninhado por diretório | **REMEDIDA — reproduz exatamente; o que estava errado era a redação** | 3.4 |
| 4 | O par 25/24 de `checkSurfaceCoverage` sobre os 66 changes | **REMEDIDA, com o driver publicado** | 9.2 |
| 5 | Os 5 arquivos `.md` do diretório de contratos, com zero podas | **REMEDIDA e ampliada — a revisão 1 media a extensão errada** | 3.6 |
| 6 | Os 10.324 arquivos do universo | **REMEDIDA como testemunha de data explícita** | 2 |
| 7 | A atribuição de rota por arquivo depois da deduplicação | **REMOVIDA como afirmação; permanece como não-medição declarada** | 4.3 |

**1 — removida.** O revisor mediu 358.633 ms e 297.227 ms onde eu tinha 93.118 e 167.468, com a **ordem invertida** entre produção e protótipo. Remedi hoje: 326.185 ms e 296.084 ms, e a ordem inverteu de novo em relação à minha própria revisão 1. Seis medições, três rodadas de execução por dois operadores, faixa de quase quatro vezes. Os dois literais saíram do documento; o que ficou é a tabela de 4.3 com as seis execuções e a declaração explícita de que nenhuma asserção depende delas. A §9.3-C, que era o único lugar em que os números tinham função, passou a comparar **faixa contra faixa** — segundos contra centenas de segundos —, e o revisor tem razão que o argumento fica mais forte assim do que estava.

**2 — remedida.** O revisor não conseguiu reproduzir porque a revisão 1 publicava os números sem publicar o gerador nem a seed. O driver inteiro está agora em 5.3, com `seed = 1` e `runs = 120` nomeados. Rodado hoje: vermelho na lib de produção com o contraexemplo minimizado `[["internal"],["WithName(\"n\")"]]` em 23 execuções, verde no protótipo em 120 execuções com 65 carregando elo. O `total: 25` da revisão 1 virou `executados: 23` — a diferença é do driver, que agora está publicado e é o que vale. E acrescentei o que o revisor pediu numa ressalva separada: o **piso** do contador de casos com elo, que a revisão 1 não nomeava. Ele é **40**, e vem de rodar cinco seeds (1, 2, 3, 7, 42) e observar a faixa 57–68 sobre 120 — piso como propriedade, com margem larga, não como contagem.

**3 — remedida, e ela reproduz inteira.** O revisor não enumerou `.git` aninhado por diretório. Eu enumerei de novo, com o comando agora colado em 3.4, e o histograma sai **idêntico** ao da revisão 1: `payments` 24, `pitflow` 11, `oversetter` 4, `secret-weapon` 2, e `axis-go-cloud`, `docuseal` e `lioncode` 1 cada. O que estava errado era a **redação em volta**, e aí o revisor está inteiramente certo: são 33 diretórios de topo e não doze, 20 deles são repositório próprio, e quatro dos sete nomes que eu citava — `pitflow`, `oversetter`, `secret-weapon` e `lioncode` — **não têm `.git` próprio**, são guarda-chuvas. Corrigido em 3.4 e propagado para a frase de 7, que dizia "sete dos doze repositórios". A metade que sustenta a decisão — zero `.gitmodules` — reproduz nos dois lados.

**4 — remedida, com o driver publicado.** O revisor reproduziu os 815 nodes e não reproduziu o par 25/24 por falta do código. `$B/srf01.mjs` está inteiro em 9.2 e devolve `achadosSemGrafo: 25, achadosComGrafo: 24` sobre os mesmos 66 changes. Corrigi junto a ressalva dele sobre os dois primeiros nodes em ordem: são `acquirerConfig.types.ts` e `api/index.ts`, não `useAcquirers.ts` e `useAkuaConfig.ts` — a substância (front-end que consome API, não a expõe) se mantém e o par errado saiu.

**5 — remedida e ampliada, e a revisão 1 media a extensão errada.** O revisor não reproduziu os "5 arquivos `.md` antes e 5 depois". Remedi com o comando em 3.6 e o `.md` reproduz (5 → 5, zero podas), **mas** `collectDeclaredSurface()` lê contratos com `{'.yaml','.yml','.json'}` (`api-surface.mjs:423`) e não com `.md`, de modo que a revisão 1 media a metade menos relevante. Medidas as duas extensões: 60 → 60 nos contratos e 5 → 5 nas specs, **zero podas nas duas**. A decisão de não ligar a poda ali fica igual e agora com o insumo certo.

**6 — remedida como testemunha de data.** O revisor mediu 10.325 onde eu tinha 10.324 e onde a primeira passada tinha 10.323, e concluiu, corretamente, que é a árvore viva e que a revisão 1 já tratava isso bem. Remedi hoje e deu 10.325, com o comando colado em 2, e reforcei o tratamento: os cinco números daquele bloco estão agora rotulados em letra como testemunha de data ancorada no commit `721fc7ec5`, e a seção 14 os lista entre os que não entram em asserção nenhuma.

**7 — removida como afirmação.** A diferença de três entre 361 e 364 era registro de mecanismo não isolado, e o revisor também não o isolou. Ela deixou de ser afirmação numérica: 4.3 agora publica o `awk` do bloco de deduplicação, diz que a atribuição por arquivo depois dela é não confiável, e declara que **eu não isolei o mecanismo e não uso o número para nada**. É a única saída honesta quando não se mediu.

**O que o revisor declarou não ter checado.** Ele não rodou a suíte inteira e não executou os três gates de governança contra o protótipo. Eu também não — a proibição é a mesma nos dois mandatos. O que substitui a execução é o mesmo argumento por construção que ele levantou, agora com as duas verificações coladas em 7: as opções novas de `collect()` nascem com default que reproduz o comportamento de hoje (medido em 5.6: 3 arquivos com e sem a opção na lib de produção) e `grep -rln "source-scan" tests/` devolve **zero**. Fica registrado como lacuna assumida da especificação, e é o orquestrador que a fecha rodando a suíte em série.

### 13.3 As ressalvas de redação

As sete estão endereçadas, e três delas viraram correção de conteúdo e não de redação.

- **"Varri os doze repositórios"** → corrigido em 3.4 e propagado para 7, com os três comandos que produzem 33, 20 e 0 (item 3 acima).
- **"Quatro dos dezesseis changes ativos — 25%"** → 9.3-B agora publica os **dois** denominadores (16 com `requirements.md`, 29 com `manifest.yaml`) e as duas proporções (25% e 13,8%), diz por que 16 é o denominador defensável e por que 29 é o que um leitor de fora ouve, e 9.4 acrescenta em letra que a recomendação **não depende da proporção**. A tabela também ganhou as duas linhas que faltavam (`cpf-cnpj-validator archived`, `payments archived`), o que era armadilha D silenciosa.
- **O terceiro campo de `scanRoutes` sem nome em §3.7** → o campo se chama **`skipped`**, fixado em 3.7 com a varredura de colisão colada (zero em `route-scan.mjs`, zero em `w132`, nove em `tests/` todas de outro assunto).
- **O piso do contador de casos com elo, e a seed** → nomeados em 5.3: `seed = 1`, `runs = 120`, `comElo >= 40`, com as cinco seeds que justificam o piso.
- **Referências de linha com deslocamento de dois a três** → 4.1 passou a citar **blocos** (`496-503` para `mapgroup-unindexed`, `507-513` para `route-site-unindexed`) com o `awk` que os imprime, o que encerra a discussão sobre qual linha é "a" linha; e 4.3 publica `awk 'NR>=1253 && NR<=1263'` para a deduplicação, mostrando que `1253` é a chamada de `compose()` e `1255-1263` é o bloco de dedup — o revisor e eu estávamos certos sobre coisas diferentes. `411`, `443`, `460`, `475` e `1084-1085` batem e agora vêm com o comando.
- **Os dois primeiros nodes `layer:'api'`** → corrigidos em 9.2 (item 4 acima).
- **Os 184 `.md` do forge-harness** → 188 hoje, com o comando, e marcado como testemunha de data em 3.6. O revisor chamou isso de "a ilustração mais limpa que esta rodada produziu do porquê da invariante 14", e concordo tanto que a promovi a exemplo explícito na seção 2, ao lado do 10.323/10.324/10.325.
- **O item 7 da definição de pronto** → agora manda o `CHANGELOG.md` **datar e ancorar** o número: repositório de referência, commit `721fc7ec5`, data 2026-09-07 (item 8 da nova definição de pronto).

---

## 14. Varredura das cinco armadilhas, no documento inteiro

Não só nos pontos que o revisor tocou. Cada armadilha com o comando que a varre.

### A. Literal que envelhece em asserção

**Literais que entram em asserção de gate: dois, e os dois são a exceção legítima da invariante 14** — denominador do próprio gate, fixo por construção, cuja divergência é o achado.

1. `SCEN_MIN = 65` (5.7). Denominador de cenários do `w132`, **re-derivado no momento da execução** pelo comando de 5 (item 1 da definição de pronto), nunca copiado deste documento.
2. `comElo >= 40` em `[61]` (5.3). É **piso**, não contagem: a faixa medida em cinco seeds é 57–68, e o piso fica com margem larga abaixo. Reprova a degeneração do gerador sem depender do valor exato.

**Contadores do README e badges — varridos, e a onda não move nenhum:**

```
$ grep -o 'gates-[0-9]*%20passing' README.md
gates-131%20passing
$ ls tests/*-gate.sh | wc -l
131
$ ls tests/*.sh | wc -l
132
```

O badge diz 131 e `ls tests/*-gate.sh | wc -l` devolve 131 — o par está coerente hoje, e a onda **não cria arquivo de gate novo** (item 6 da seção 10), então o badge não move. Se a implementação acabar criando um arquivo de gate, o badge entra na mesma mudança; é a checagem que duas ondas deste lote esqueceram e que esta faz por comando, não por memória.

**Números que este documento publica e que NÃO entram em asserção nenhuma**, declarados aqui para que ninguém os promova por engano a critério: os 10.325 arquivos do universo do repositório de referência e a decomposição 1.429 / 191 / 54 / 1.566 (2, 3.2); os pares 373/77, 69/8, 353/8, 20/69 e 364/0 (3.1, 3.2, 4.3); os 8 sítios de `MapGroup` em quatro arquivos (3.2); os 33 / 20 / 0 diretórios do parque e o histograma de `.git` aninhado (3.4); as seis linhas da tabela de universo de 3.6 e as 25 podas de `payments`; os 60 e 5 arquivos do diretório de contratos (3.6); os 59 cenários e as 1.958 linhas do `w132` (5); os 815 nodes e o par 25/24 (9.2); as 14 linhas da tabela do parque e os denominadores 29 e 16 (9.3-B); os 0,795 s e 5,747 s de `validate-spec` e as seis medições de tempo de varredura (4.3, 9.3-C). Todos são **relatórios de medição do dia**, úteis para dimensionar o trabalho e inúteis como asserção. A definição de pronto da seção 11 não cita nenhum deles como critério, exceto o número datado e ancorado do `CHANGELOG` (item 8), que é registro histórico e não asserção de gate.

### B. String de produção mudada sem varrer `tests/` e sem o espelho do plugin

**A onda não muda nenhuma string que a produção imprime.** As duas correções alteram um regex (`CHAIN`) e acrescentam opções e um campo de retorno; nenhum `detail`, nenhuma mensagem de `kind`, nenhum texto de log é tocado. A varredura que prova que os `kind` afetados estão nominalmente cobertos é a de 4.6, com `grep -rn` sobre `tests/`, `template/` e `plugin/` — três asserções, todas em `w132`, todas nomeadas com a linha.

**A string NOVA é o nome do campo e os dois motivos, e ela foi varrida antes de escolhida** (3.7): `skipped` tem zero ocorrências em `route-scan.mjs` e zero em `w132`; as nove em `tests/` são de gates de outro assunto. `repositorio-aninhado` e `backup-de-update` são inéditos:

```
$ grep -rn "repositorio-aninhado\|backup-de-update" tests/ template/ plugin/ | wc -l
0
```

**O espelho do plugin não precisa ser regenerado, e isso é medido:**

```
$ find plugin -type f | sed 's/.*\.//' | sort | uniq -c
   1 json
  56 md
$ grep -rln "route-scan\|scanRoutes\|surContractToCode" template/.forge/commands plugin/forge
(vazio)
```

`plugin/forge` contém só `.md` de comando e um `.json`; nenhum `.mjs` é espelhado, e **nenhum documento de comando cita `route-scan`, `scanRoutes` ou `surContractToCode`**. Logo `npm run build:plugin` não é exigido por esta onda — e o item 11 da definição de pronto registra a condição em que ele voltaria a ser: se a implementação tocar algum `.md` de comando. O `plugin-sync-gate` fica satisfeito por vacuidade, e a vacuidade está medida em vez de suposta.

### C. Linha de matriz de mutação sem contrafactual medido

**Zero linhas sem contrafactual medido.** A matriz de 6 tem sete linhas e as sete carregam saída de execução colada: M1 (lib de produção sobre `f59` e o PBT), M2 (`lib-m2` sobre `f40` **e** sobre `f60`, para provar que não discrimina `[60]`), M7 (`lib-m7` sobre `f60` **e** sobre `f40`), M3, M4 e M5 (`lib-m3`, `lib-m4`, `lib-m5` sobre `fx/poda` **e** `fx/raiz`, cada um contra as duas fixtures para provar que não colapsam) e M6 (`trap.sh` contra `trap-m6.sh`, com o `exit 0` plantado). A revisão 1 entregava três medidas e três declaradas; a invariante 16 pede as sete, e o protótipo da seção 0 tornou isso barato.

Cada linha de M3/M4/M5 foi rodada contra **as duas** fixtures de poda, e não só contra a que ela deveria matar — é o controle que separa "a mutação mata o cenário certo" de "a mutação mata tudo". M4 sobre `fx/poda` sai idêntico ao verde; M3 e M5 sobre `fx/raiz` saem idênticos ao verde. Sem esse par, uma mutação que quebrasse os dois cenários passaria por discriminante.

### D. Enumeração que se diz exaustiva

Quatro enumerações neste documento se dizem exaustivas. As quatro têm o comando que as fecha, e **duas cresceram nesta revisão**.

| Enumeração | Onde | O que a fecha | Cresceu? |
|---|---|---|---|
| Os estados do diretório-filho na poda | 3.5 | procura ativa, com fixture medida por linha | **sim, de 8 para 10 linhas** — raiz que é `.forge.bak` e diretório-filho que é symlink |
| As asserções afetadas pelos dois `kind` | 4.6 | `grep -rn` sobre `tests/`, `template/` e `plugin/` | não — três, e o `grep` é a prova |
| Os módulos que importam `collect()` | 3.6 | `grep -rln "source-scan.mjs" template/` mais o `grep -n` que mostra que o sexto é comentário | **sim, em precisão** — a revisão 1 dizia quatro sem mostrar o sexto arquivo que casa e por que ele não conta |
| Os repositórios do parque com changes | 9.3-B | o driver varre `readdirSync` do diretório-pai, sem lista escrita à mão | **sim, de 12 para 14 linhas** — `cpf-cnpj-validator archived` e `payments archived` |

A regra que sobrou desta varredura: uma enumeração só é exaustiva quando o que a produz é um comando que varre, não uma lista que alguém digitou. As duas que cresceram cresceram porque eu troquei a lista pelo comando.

### E. Prescrição de comando que eu nunca executei

**Todo comando colado neste documento veio de uma execução minha nesta rodada**, e a bancada que os reproduz está declarada na seção 0. Isso inclui os sete drivers (`scan.mjs`, `quatro.mjs`, `fxrun.mjs`, `podarun.mjs`, `optin.mjs`, `pbt-cadeia.mjs`, `srf01.mjs`, `insumo.mjs`, `parque.mjs`, `universo.mjs`, `universo-ref.mjs`, `contratos.mjs`, `podas-detalhe.mjs`, `atribui.mjs`, `f16chk.mjs`), os scripts de bash de 5.7 e os `grep`/`awk`/`find`/`git` de 3.4, 4.1, 4.6, 5, 7 e 14.

**O que a especificação NÃO prescreve, por não ter executado**, e que fica com quem implementa, sob a invariante 19:

1. **O primitivo do reconhecedor de cadeia.** O protótipo generaliza o regex de `:411` (seção 0); tokenizar a cadeia ou reconhecê-la por outro caminho é escolha de quem executa, com a obrigação de provar a discriminação pela matriz de 6, nos dois eixos (M2 e M7).
2. **Os comandos exatos do protocolo de mutação** (passos 1 a 6 de 6). Declaro a propriedade e o contrafactual de cada linha, com a saída da minha execução colada; o `shasum`, a substituição integral e o recontrole são de quem executa, e o motivo de eu não prescrevê-los é LDG-0164 — foi exatamente prescrevendo comando de mutação sem rodar que uma especificação desta rodada ensinou a mutação-fantasma no parágrafo em que a proibia.
3. **A execução da suíte.** Nenhum gate foi rodado aqui, por proibição de mandato, e o item 7 da definição de pronto é do orquestrador, em série.

Três lacunas assumidas, nomeadas, e nenhuma delas escondida atrás de um comando que pareça ter sido executado.
