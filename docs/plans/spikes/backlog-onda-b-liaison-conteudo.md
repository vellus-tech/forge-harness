# Onda B — liaison: integridade de conteúdo (especificação implementável)

Autor: especificador da Onda B. Data: 2026-09-07. Revisão 2 — reescrita depois do veredito da revisão 1, cujas respostas estão em §15. Base medida: branch `develop` em `3bb67f5`, `v0.14.0` publicada no npm.

Escopo: **#117** (o nome do blob não é o `sha256` do arquivo), **#107** (a instalação do blob mora dentro do laço de mensagens novas), **#109** (o `sync` publica e não deixa marca d'água), **#108** (três resíduos de cursor e de instrumento), **LDG-0153** (o doctor não informa divergência da maquinaria local contra o `machinery.lock`) e **LDG-0163** (defeito já corrigido, que fecha por prova e não por código). O critério que junta os seis é o mesmo: alguma coisa que o canal carrega — o corpo, o ponteiro para o corpo, o cursor, a marca do que já saiu, a própria maquinaria que lê tudo isso — está errada ou invisível, e nenhum comando reprova.

Esta especificação é para ser executada, não lida. **Nenhum gate da suíte foi executado na elaboração** — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio, com log vazio.

**Regra de número, endurecida na revisão 2 e aplicada a cada linha deste documento.** Toda afirmação numérica traz, ao lado dela, o comando que a produziu — não a bancada em que ela foi observada, o comando, colável e reexecutável por quem revisa. A revisão 1 devolveu onze afirmações numéricas que o revisor não conseguiu reproduzir, e a lição é que número sem comando contamina a confiança no documento inteiro, porque quem lê deixa de saber quais números valem. Onde o número conta algo da árvore — arquivos, gates, entradas de lock, blobs, mensagens, réplicas —, ele é **testemunha de data e nunca critério**: serve para dimensionar a decisão no dia em que foi medido, e a asserção correspondente do gate usa **propriedade mais piso**, jamais o literal. Isso é a invariante 14 do plano-mestre, e o próprio acervo desta onda a demonstrou: entre a revisão 1 e a revisão 2, medido pelo mesmo comando, o número de blobs distintos subiu de 1090 para 1094 e as mensagens ackadas-e-não-lidas de 68 para 71, sem que ninguém tocasse no código.

**Regra de método, e ela é a invariante 19 do plano-mestre.** Uma especificação não prescreve mecanismo que ela não executou. O que esta especificação declara é a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele tem a obrigação de **provar que o primitivo escolhido discrimina**, com controle e recontrole. Comando exato só permanece aqui quando veio de uma execução minha, com a saída colada. As bancadas que usei estão nomeadas em §1.

---

## 0. Resumo do que muda

| Item | Mudança | Onde |
|---|---|---|
| #117 | O esquema de nome de blob passa a ser **versionado**: blob novo nasce `sha256-<hex do sha256 dos bytes>-<base>`, blob antigo fica intocado, e nasce um verificador de três estados que conhece os dois esquemas | `liaison-ops.sh::_write_body_blob`, `lib/liaison-merge.mjs` (função nova de nome), subcomando `blobs verify` |
| #107 | A instalação de blob sai do laço de mensagens novas e vira **passada própria sobre toda mensagem com `body_ref`**, com contador de corpos ausentes na saída do import e no `status` | `lib/liaison-import.mjs::applyBundle` |
| #109 | O `sync` grava `published: { seq, at }` em `state.json` ao fim de um `t_push` bem-sucedido, e o `status` compara o maior `seq` próprio contra a marca | `liaison-ops.sh` (`sync)` e `status)`) |
| #108 | (1) subcomando `cursors repair` com `--dry-run`; (2) o `catch` mudo do avanço de cursor no `ack` vira `WARN`; (3) o doctor deixa de emudecer quando `status` reprova | `liaison-ops.sh`, `doctor.sh:230-238` |
| LDG-0153 | O doctor passa a comparar a maquinaria local contra `machinery.lock`, com três estados, espelhando o que ele já faz para o lockfile de adapter | `lib/machinery-drift.mjs` (novo), `doctor.sh` |
| LDG-0163 | Nenhum código novo: `w198[5]` ganha as duas asserções que faltam para que a prova seja do caminho `ff` e da causa | `tests/w198-liaison-push-union-gate.sh` |
| Arrasto obrigatório | `README.md` — badge `gates-N` e linha `scripts/ (N)` — e o espelho `plugin/forge/commands/liaison.md`, regenerado por `npm run build:plugin`; mais o estreitamento de `npx-pack-gate.sh:135` | §10, com a definição de pronto em §12 |

Dois gates novos, `wB1` (blobs) e `wB2` (outbox, cursor e instrumento), com ordinal alocado pelo orquestrador (§13) — os marcadores `wB1`/`wB2` não chegam ao disco. **Sete artefatos existentes editados**, nominalmente listados em §10: cinco gates, o `README.md` e o espelho do plugin.

---

## 1. As bancadas, e o que foi medido em cada uma

Quatro bancadas, todas sob `$TMPDIR`, com `cwd` **dentro** da fixture — nunca na árvore real, porque `on-session-end.sh` resolve a raiz pelo `cwd` e ignora `FORGE_ROOT`. Toda mutação é aplicada a **cópia de fixture**, por substituição integral a partir de um arquivo preparado, com `sha256` antes, asserção de que o arquivo mudou, restauração por checksum e recontrole — LDG-0175 registra o gate desta suíte que mutou arquivo rastreado e o deixou reduzido a um stub de três linhas.

**Bancada A — canal `fs` de dois participantes.** Duas árvores git com `.forge/scripts` copiado do template, `open` + `transport set --kind fs` + `thread open <id> --participants`, hub em `$T/hub`. É a fixture de `w198` e de `w195`, reconstruída à mão. Serviu a #117, #107, #109 e LDG-0163.

**Bancada B — canal sem transporte, com `export`/`import`.** Duas árvores, bundle materializado à mão em `log/` + `blobs/` e aplicado por `import --from`. Serviu a #108, itens 2 e 3, e ao bloqueador 3 da revisão 1.

**Bancada C — leitura das quatro árvores consumidoras.** `axis-fare-validator`, `axis-go-cloud`, `Axis.PadSimulator` e `forge-harness`, mais os dois hubs (`/Users/milton/Documents/projects/.forge-liaison-hub` e `/Users/milton/.forge/liaison-hub`). **Somente leitura** — nenhuma escrita, e nenhum comando do harness executado dentro delas: os censos importam as funções puras de `template/.forge/scripts/lib/liaison-merge.mjs` e leem os arquivos, em vez de invocar `liaison-ops.sh` na árvore de campo. Serviu ao censo de #117, #107, #109, #108-1 e LDG-0153.

**Bancada D — a fixture do `w112`, reconstruída exatamente como `mk_repo` a monta** (os dez diretórios de `.forge/`, `forge.yaml`, `git init`, commit vazio), porque a afirmação de §5.3 é sobre o comportamento do gate e só vale se medida no ambiente do gate. Nasceu na revisão 2, e nasceu porque a medição equivalente da revisão 1 foi feita fora dele e afirmou o contrário do que o ambiente do gate produz.

---

## 2. ITEM 1 — issue #117: o nome do blob não é o `sha256` do arquivo

### 2.1 O defeito, reproduzido

`template/.forge/scripts/liaison-ops.sh:298` é `const sha = M.sha256Hex(buf.toString('binary'));`, e `sha256Hex` (`lib/liaison-merge.mjs:37-39`) faz `createHash('sha256').update(text, 'utf8')`. A composição é `sha256(utf8(latin1(bytes)))`, não `sha256(bytes)`.

Executado nesta rodada:

```
$ node -e "
const { createHash } = require('crypto');
function sha256Hex(text) { return createHash('sha256').update(text, 'utf8').digest('hex'); }
const buf = Buffer.from('não', 'utf8');
console.log('gerado :', sha256Hex(buf.toString('binary')));
console.log('bytes  :', createHash('sha256').update(buf).digest('hex'));
const ascii = Buffer.from('nao', 'utf8');
console.log('ascii match:', sha256Hex(ascii.toString('binary')) === createHash('sha256').update(ascii).digest('hex'));
"
gerado : fccc513463754c038da17b3f857c80cdc5f2bd82a9b6c6508e738f52561761f2
bytes  : 76daee1631fea659d4916e762790fa20df30a372595cefa140030834c67b08ea
ascii match: true
```

E na bancada A, pelo caminho real (`send --body-file` com corpo acentuado). O comando, na bancada montada como descrito em §1, foi `liaison-ops.sh send contracts --thread t1 --kind note --subject "com corpo" --body-file "$T/corpo.md"`, seguido da leitura do `body_ref` gravado no log próprio e do `shasum -a 256` do mesmo arquivo:

```
body_ref     : blobs/e755f276483b56f70f5e8ddee0e585ed94d9d5dc106a49b78a9764e8be8140a7-corpo.md
sha256(bytes): 3da08750dd94fb40ac2595d053b0de8106688be2e0721b69b01b0578cdb7a319
fórmula do gerador: e755f276483b56f70f5e8ddee0e585ed94d9d5dc106a49b78a9764e8be8140a7
bytes > 0x7F no corpo: true
```

O nome gravado reproduz a fórmula do gerador e **não** reproduz `shasum -a 256`, que é a issue #117 pelo caminho real, com o corpo acentuado que a fixture de hoje não tem.

### 2.2 O acervo, remedido por mim — e o número da issue não é o de hoje

A issue reporta 665 de 666 divergentes. Remedi sobre as quatro árvores consumidoras mais os dois hubs (bancada C), e o resultado é mais forte do que o da issue, não mais fraco. O comando, colado inteiro porque ele é a única coisa que faz este parágrafo verificável:

```
$ find ~/Documents/projects/axis-fare-validator/.forge/liaison \
       ~/Documents/projects/axis-go-cloud/.forge/liaison \
       ~/Documents/projects/Axis.PadSimulator/.forge/liaison \
       ~/Documents/projects/forge-harness/.forge/liaison \
       ~/Documents/projects/.forge-liaison-hub ~/.forge/liaison-hub \
       -type d -name blobs -print0 2>/dev/null \
  | node -e '
const fs=require("fs"),path=require("path"),{createHash}=require("crypto");
let buf="";process.stdin.on("data",d=>buf+=d).on("end",()=>{
 const dirs=buf.split("\0").filter(Boolean); const seen=new Map(); let files=0;
 for(const d of dirs){ let e; try{e=fs.readdirSync(d);}catch(x){continue;}
   for(const f of e){ const p=path.join(d,f); let st; try{st=fs.statSync(p);}catch(x){continue;}
     if(!st.isFile())continue; files++; if(!seen.has(f))seen.set(f,p); } }
 let okBytes=0,okGer=0,nenhum=0,alto=0,ex=null;
 for(const [name,p] of seen){ const b=fs.readFileSync(p);
   const bytes=createHash("sha256").update(b).digest("hex");
   const ger=createHash("sha256").update(b.toString("binary"),"utf8").digest("hex");
   const pre=name.split("-")[0], mb=pre===bytes, mg=pre===ger;
   if(mb){okBytes++; if(!ex)ex=name+" (bytes>0x7F: "+b.some(x=>x>0x7F)+", "+b.length+" bytes)";}
   if(mg)okGer++; if(!mb&&!mg)nenhum++; if(b.some(x=>x>0x7F))alto++; }
 console.log(`dirs=${dirs.length} arquivos=${files} nomes_distintos=${seen.size} bate_sha256_bytes=${okBytes} bate_formula_gerador=${okGer} nenhum=${nenhum} com_byte_alto=${alto}`);
 if(ex)console.log("  o único que bate sha256(bytes): "+ex);
});'
dirs=13 arquivos=5079 nomes_distintos=1094 bate_sha256_bytes=1 bate_formula_gerador=1094 nenhum=0 com_byte_alto=1093
  o único que bate sha256(bytes): f07757fdaafa62a99aee8114ffd00b25335866942a3e8a36cd0158d910aa8e78-liaison-guard-survivors-final.md (bytes>0x7F: false, 2338 bytes)
```

**Testemunha de data, não critério.** Os 1094 de hoje eram 1090 quando a revisão 1 rodou o mesmo comando, e serão outro número na semana que vem: o canal está vivo. Nenhum gate desta onda escreve 1094 em lugar nenhum; o que os gates asseveram é a propriedade e o piso, e §2.8 diz onde.

Três leituras, e as três importam. **Primeira: o gerador é consistente com ele mesmo em todos os nomes distintos, `bate_formula_gerador` igual a `nomes_distintos`** — não há um único blob corrompido no acervo, e a hipótese "os arquivos foram adulterados" está descartada por medição, não por argumento. **Segunda: apenas 1 bate com `shasum -a 256`**, e ele é `f07757fd…-liaison-guard-survivors-final.md`, com `bytes > 0x7F: false`, 2338 bytes — coincidência de conteúdo ASCII, exatamente como a issue diz. **Terceira: `nenhum=0`, zero blobs batem com nenhuma das duas fórmulas** — não existe caso ambíguo a decidir.

**O que a revisão 1 afirmava aqui e foi REMOVIDO:** `270 diretórios`, `77193 blobs nomeados` e `nome == sha256(bytes): 85`, números vindos de uma varredura que incluía as subárvores de worktree das quatro árvores. O revisor não os reproduziu porque não varreu worktree, e ele estava certo em não varrer: worktree é cópia efêmera de trabalho, não acervo, e contar blob de worktree infla o denominador com réplicas do mesmo arquivo sem acrescentar um bit de informação sobre o defeito. O universo que decide é o das quatro árvores mais os dois hubs, ele é o que o comando acima varre, e é o único que fica.

**A propriedade que o nome atual preserva, e que decide a §2.3.** `latin1` mapeia cada byte para um ponto de código distinto em `U+0000..U+00FF`, e a codificação UTF-8 desses pontos é injetiva. Logo `bytes → latin1 → utf8` é injetiva, e o nome atual continua sendo um endereço de conteúdo legítimo, com o mesmo risco de colisão do `sha256` e nenhum a mais. Medido:

```
$ node -e 'const s=new Set();for(let b=0;b<256;b++){s.add(Buffer.from(Buffer.from([b]).toString("binary"),"utf8").toString("hex"));}console.log(s.size);'
256
```

O que está errado, portanto, não é o endereço: é **a promessa implícita de que ele é reproduzível por `shasum -a 256`**, e é essa promessa que produz o falso positivo de corrupção em massa que a issue documenta.

### 2.3 O gate que está VERDE por acidente da fixture — e que é o vermelho desta onda

`tests/w110-liaison-core-gate.sh:166-176` já afirma exatamente a propriedade que o defeito viola:

```
sha_expected="$(shasum -a 256 "$T/big.txt" | cut -d' ' -f1)"
…
grep -q "^blobs/$sha_expected" <<<"$blob_ref" || { echo "FAIL [6]: nome do blob não referencia o sha"; exit 1; }
```

Ele passa hoje **porque a fixture é `head -c 4000 /dev/urandom | base64`, que é ASCII puro**, e as duas metades disso estão medidas com o comando colado em outras seções, em vez de numa bancada que já não existe. A metade acentuada é §2.1: pelo caminho real do `send --body-file`, o `body_ref` traz `e755f276…` e `shasum -a 256` do mesmo arquivo devolve `3da08750…`, então a asserção do nome **falha** e é esse o vermelho de #117. A metade ASCII é o par de controle de §2.6: para conteúdo sem byte acima de `0x7F`, `sha256(bytes)` e a fórmula do gerador coincidem (`iguais=true`), e é exatamente por isso que `w110[6]` está verde hoje. O par importa: sem o controle ASCII, trocar a fixture provaria que a fixture mudou, não que o código está errado.

Isto é uma instância da classe da Onda D dentro do subsistema desta onda: um gate ancorado no alvo certo, com a asserção certa, **verde por uma propriedade da fixture e não do código**. Registre-se como tal, porque o remédio — trocar a fixture — é o que produz o vermelho de #117 sem escrever uma linha de gate nova.

### 2.4 Decisões de desenho — FECHADAS

**Decisão 1 — o nome passa a ser VERSIONADO: blob novo nasce `sha256-<hex>-<base>`, blob antigo fica intocado.**

O prefixo `sha256-` torna o esquema **auto-descritivo**, que é a propriedade sem a qual nenhuma das outras alternativas fecha: com dois esquemas produzindo 64 dígitos hexadecimais indistinguíveis por forma, um auditor externo não consegue separar "blob do esquema antigo" de "blob corrompido", e é exatamente essa indistinguibilidade que causou o quase-incidente relatado na issue.

O discriminador é **total e demonstrável**, e não uma convenção que depende de disciplina: o nome legado começa obrigatoriamente por 64 dígitos hexadecimais, e `sha256-` tem `s` na primeira posição, que não é dígito hexadecimal. Nenhum nome legado pode ser confundido com um nome novo, em nenhum conteúdo, e a recíproca vale por construção. Isso vira propriedade sob PBT em §2.7.

**Alternativa A descartada — renomear o acervo. REFUTADA POR MEDIÇÃO, e é a mais importante das três refutações.** `computeContentSha` (`lib/liaison-merge.mjs:44-47`) exclui do digest apenas `content_sha` e `trust`; **`body_ref` está dentro**. A revisão 1 provava isso com os `content_sha` de uma mensagem real de uma bancada que já não existe, o que obrigava o revisor a reconstruir a bancada para conferir. A revisão 2 troca por uma demonstração que qualquer um roda em dois segundos, sobre um envelope sintético, e que prova as duas metades da afirmação — o que está dentro e o que está fora:

```
$ node --input-type=module -e '
import { pathToFileURL } from "url";
const M = await import(pathToFileURL("template/.forge/scripts/lib/liaison-merge.mjs").href);
const base = { msg_id:"repo-a-0002", channel:"contracts", thread_id:"t1", sender:"repo-a", seq:2,
  lamport:2, kind:"note", in_reply_to:null, requires_ack:false, subject:"com corpo",
  body_ref:"blobs/4f2a61f2-corpo.md", refs:{change_id:null,contract_files:[],commit:null},
  created_at:"2026-09-07T00:00:00Z" };
const a = M.computeContentSha(base);
const b = M.computeContentSha({ ...base, body_ref:"blobs/sha256-2ee66d7b-corpo.md" });
const c = M.computeContentSha({ ...base, trust:"untrusted-peer", content_sha:"lixo" });
console.log("original                     :", a);
console.log("só trocando o body_ref       :", b, " iguais?", a===b);
console.log("mexendo em trust/content_sha :", c, " iguais?", a===c);'
original                     : fa5fd22bdd58072be66ff8a0d5de32710189d2c93bcb53c74f4c527d6c62aadc
só trocando o body_ref       : dd47760c7cf658916cf5e4ab326f1151c77d7f035ee8047a4d67739c67e6e2da  iguais? false
mexendo em trust/content_sha : fa5fd22bdd58072be66ff8a0d5de32710189d2c93bcb53c74f4c527d6c62aadc  iguais? true
```

Renomear um blob obriga a reescrever o `body_ref` da mensagem, o que muda o `content_sha` dela, o que é **reescrita de história** pela regra 6 da política de import — toda réplica que já conhece aquela posição a retém em quarentena. A dimensão do dano, medida sobre as quatro árvores, com os dois comandos colados:

```
$ node censo-canal.mjs template/.forge/scripts/lib \
    ~/Documents/projects/{axis-fare-validator,axis-go-cloud,Axis.PadSimulator,forge-harness}
…
mensagens_distintas=2267 com_body_ref=1017 blobs_distintos_referenciados=1084

$ for r in axis-fare-validator axis-go-cloud Axis.PadSimulator forge-harness; do \
    printf '%s: ' "$r"; git -C ~/Documents/projects/$r ls-files -- '.forge/liaison/*/blobs/*' | wc -l; done
axis-fare-validator: 1114
axis-go-cloud: 1104
Axis.PadSimulator: 1101
forge-harness: 158        (total 3477)
```

`censo-canal.mjs` é o script de bancada de §5.1, colado por inteiro lá; ele importa `mergeLogs` do template e lê os arquivos das árvores de campo, sem executar comando do harness dentro delas. Todos esses números são testemunha de data — a revisão 1 media 2264/1014/1080 e 3469 pelos mesmos caminhos, e a diferença é uma semana de conversa no canal. O que decide a alternativa não é o valor, é a ordem de grandeza: milhares de mensagens publicadas em quatro repositórios, e uma migração dessas seria a issue #48 reproduzida deliberadamente em todos ao mesmo tempo.

**Alternativa B descartada — aceitar as duas formas na leitura.** É a que a própria issue sugere na cauda ("manter o nome atual como identificador opaco e gravar o sha256 verdadeiro como campo separado"). Descartada por duas razões, uma medida e uma de método. A medida: um campo novo no envelope reprova nos validadores já instalados, porque `schemas/liaison-message.schema.json:7` é `"additionalProperties": false`, e as três cópias instaladas em campo carregam esse mesmo schema — uma mensagem com campo novo passaria em `validateEnvelope` e reprovaria em `ajv` nos três consumidores, que é divergência de leitor com adotante instalado. A de método: aceitar duas respostas não conserta o gerador, então o acervo continua crescendo com nomes que `shasum` não reproduz, e o falso positivo para quem audita **por fora** do harness — o dano concreto da issue — permanece indefinidamente.

**Alternativa C descartada — mudar `sha256Hex` para hashear `Buffer`.** É a correção que a issue chama de "sugerida", e ela é a mais perigosa das três: `sha256Hex` é a mesma função que calcula `content_sha` de **toda** mensagem (`computeContentSha` a chama), então alterá-la invalidaria de uma vez o `content_sha` de todas as mensagens publicadas — 2267 distintas nas quatro árvores no dia da medição de §2.4, e o que decide é a ordem de grandeza, não o valor. A correção é local a `_write_body_blob`, jamais à função compartilhada — e este parágrafo existe para que ninguém a aplique por engano.

**Decisão 2 — o cálculo do nome sai de `liaison-ops.sh` e vira função exportada de `lib/liaison-merge.mjs`.**

Duas funções, e as duas são puras: `blobName(buf, base)`, que produz o nome do esquema corrente, e `blobNameLegacy(buf, base)`, que reproduz o esquema antigo. Motivo: hoje o nome é calculado dentro de um heredoc `node -` de `liaison-ops.sh`, que é o único lugar do repositório onde ele existe (`grep -rn "toString('binary')" template/ bin/ installer/ plugin/` devolve **1** ocorrência, executado nesta rodada), e um nome que só existe dentro de um heredoc não pode ser testado por unidade nem reusado pelo verificador. `liaison-merge.mjs` é o módulo de funções puras e é onde `sha256Hex` já mora.

**Decisão 3 — nasce `liaison-ops.sh blobs verify <canal>`, com TRÊS estados por blob e um contador agregado.**

Por blob de `blobs/`, o veredito é um de quatro, e a enumeração é exaustiva sobre o nome do arquivo: (a) o nome casa `^sha256-<64hex>-` e o digest dos bytes bate → **íntegro (esquema corrente)**; (b) o nome casa `^<64hex>-` e a fórmula legada bate → **íntegro (esquema legado)**; (c) o nome casa um dos dois padrões e o digest **não** bate → **DIVERGENTE**, que é o único achado que reprova; (d) o nome não casa nenhum dos dois → **NÃO VERIFICADO — esquema de nome desconhecido**, nunca "corrompido". O caso (d) é alcançável e não é hipotético: `tests/w101-update-preserve-gate.sh:102` grava um `blobs/anexo.txt` numa fixture, e cópia manual de blob entre árvores é procedimento documentado no campo.

A esses quatro soma-se um quinto veredito, que é sobre a **mensagem** e não sobre o arquivo: `body_ref` cujo blob não existe em `blobs/` → **AUSENTE**, que é o contador de #107 (§3) visto do outro lado. E um sexto, informativo: blob presente em `blobs/` que nenhuma mensagem referencia → **órfão**, contado e nunca tratado como defeito, porque o import instala por nome e um blob a mais é custo de disco, não perda.

**O contrato de saída do subcomando, e o canal legitimamente vazio.** A revisão 1 deixou este ponto contraditório — §2.4 e §2.5 diziam que DIVERGENTE é o único achado que reprova, e §2.8 mandava reprovar com `universo-vazio` quando o número de blobs examinados fosse zero, o que é estado comum e alcançável num canal recém-aberto. Quem implementasse não teria como saber o que devolver. A saída é separar o que é **rc do subcomando** do que é **guarda de vacuidade do gate**, e nomear o caso vazio em vez de deixá-lo cair num dos outros dois:

| Desfecho | Vocabulário | rc |
|---|---|---|
| nada a verificar — `blobs/` vazio **e** nenhuma mensagem com `body_ref` | `nada a verificar: 0 blob(s) em blobs/, 0 body_ref no log` — nunca o vocabulário de integridade | 0 |
| examinou e nada divergiu | `N blob(s) examinado(s)` mais a decomposição em corrente / legado / não verificado / órfão / ausente | 0 |
| examinou e achou DIVERGENTE | `k blob(s) DIVERGENTE(s)`, nomeando cada um | 1 |
| não consegui verificar — canal não inicializado, `blobs/` ilegível, `node` ausente | `não consegui verificar: <causa>` | 2 |

O caso vazio sai 0 porque não há defeito nele, e a discriminação contra o segundo desfecho vive **no vocabulário e no contador publicado**, não no rc: o subcomando nunca imprime a palavra íntegro quando examinou zero. É a invariante 2 do plano com o cuidado de não transformar canal novo em falha, e o cenário que a prova é `wB1[4b]` (§2.5). O rc 2 existe porque "não consegui ler o diretório" e "li e estava limpo" não podem terminar no mesmo `exit 0` — foi assim que o gate de red-first aprovou um push imprimindo `0 change(s) examinado(s)`.

**Por que subcomando deliberado e não parte do `status`.** Medido sobre o maior acervo local, com o comando colado, porque a decisão pende do custo:

```
$ D=~/Documents/projects/axis-fare-validator/.forge/liaison/axis-contracts/blobs
$ /usr/bin/time -p node -e '
const fs=require("fs"),path=require("path"),{createHash}=require("crypto");
const d=process.argv[1];let n=0,b=0;
for(const f of fs.readdirSync(d)){const buf=fs.readFileSync(path.join(d,f));n++;b+=buf.length;
  createHash("sha256").update(buf).digest("hex");}
console.error(`examinados=${n} bytes=${b}`);' "$D"
examinados=922 bytes=3876534 real 12,45 user 0,14 sys 0,14
examinados=922 bytes=3876534 real  8,03 user 0,11 sys 0,12
examinados=922 bytes=3876534 real 12,80 user 0,13 sys 0,18
```

Três medições, porque uma só não diz nada sobre variância: **8,0 a 12,8 segundos de relógio contra 0,25 a 0,32 s de CPU**. A revisão 1 dizia `6,4 s` e `0,27 s` sem colar o comando, e o número de relógio não sobreviveu — esta máquina estava com uma suíte de baseline rodando, e é justamente por isso que a medição tem de vir com o comando e com a dispersão. A leitura que decide não é o valor: é a **forma** dele. O tempo é dominado por I/O de arquivo pequeno, o CPU é sub-segundo, e o custo cresce com o número de blobs — que cresce a cada mensagem com corpo. O `status` roda no `SessionStart` das quatro árvores (`liaison.auto: true`, medido em `.forge/forge.yaml`) e não pode pagar segundos por sessão em algo que cresce sem teto. O `status` fica com o predicado barato — a existência do arquivo apontado por `body_ref`, que é `existsSync` e não leitura —, e o digest fica no subcomando.

**Decisão 4 — o `send` NÃO deduplica contra o esquema legado.** Um conteúdo já publicado sob nome legado, reenviado depois desta onda, ganha uma segunda cópia sob o nome novo. É duplicação limitada e mensurável (1084 blobs distintos referenciados no dia da medição de §2.4; reenvio do mesmo arquivo é evento raro), e a alternativa — procurar o nome legado antes de escrever o novo — obrigaria o `send` a hashear o conteúdo duas vezes e a manter viva a fórmula antiga no caminho de escrita, que é o oposto de aposentá-la.

### 2.5 O VERMELHO, antes do verde

Casa em dois lugares. Em `w110`, porque a asserção já existe e só está cega; e em `wB1`, porque o verificador não existe.

**`w110[6]` — a fixture ganha ao menos um byte acima de `0x7F`, e a asserção do nome passa a exigir o esquema corrente.** A fixture passa a ser um corpo com acentuação e a asserção de nome passa a ser sobre `^blobs/sha256-<sha_expected>-`. *Como falha hoje:* a asserção do nome falha, e a saída literal está colada em §2.1 — pelo caminho real do `send --body-file` com corpo acentuado, o `body_ref` traz `e755f276…` e `shasum -a 256` do arquivo devolve `3da08750…`. Falha pela ausência real da funcionalidade: não existe no repositório nenhum caminho que produza um nome com prefixo de esquema (`grep -rn 'sha256-' template/.forge/scripts/liaison-ops.sh` devolve zero) e não existe caminho que hasheie o `Buffer` (a única ocorrência de `toString('binary')` é a linha 298). **Par de controle obrigatório:** a asserção antiga, com fixture ASCII, continua num cenário próprio (`w110[6b]`) e continua verde — sem ele, `[6]` não distingue "o esquema mudou" de "esta fixture quebrou por outro motivo".

**`wB1[1]` — `blobName` e `blobNameLegacy` existem e são puras.** `import` do módulo e chamada com um `Buffer` fixo. *Como falha hoje:* `grep -n 'export function blobName' template/.forge/scripts/lib/liaison-merge.mjs` devolve zero linhas.

**`wB1[2]` — o `send --body-file` com corpo acentuado produz nome do esquema corrente, e `shasum -a 256` do arquivo reproduz o hexadecimal dentro dele.** É a propriedade universal que a issue diz estar quebrada, agora afirmada pelo canal real (`send` de verdade, blob em disco de verdade). *Como falha hoje:* o nome sai sem prefixo e com o hexadecimal da fórmula legada; medido em §2.1.

**`wB1[3]` — o verificador diz `íntegro (legado)` para um blob de esquema antigo.** A fixture grava à mão, em `blobs/`, um arquivo nomeado pela fórmula legada, sobre conteúdo **ASCII puro** — e o "ASCII puro" é da fixture, não decorativo: medido, `sha256(bytes)` e a fórmula legada coincidem exatamente quando não há byte acima de `0x7F`, então um blob legado de conteúdo acentuado seria classificado DIVERGENTE e este cenário mediria outra coisa. *Como falha hoje:* `liaison-ops.sh blobs verify` não existe, e um subcomando de topo desconhecido cai no `*)` do `case` principal (`liaison-ops.sh:1294-1296`), com `FAIL: comando desconhecido 'blobs'` e rc 1 — **não** em `_reject_unknown`, que é a guarda de FLAG desconhecida dentro de um subcomando. A asserção de "como falha hoje" cita a mensagem certa porque a errada faria o vermelho passar por outro motivo.

**`wB1[4]` — o verificador diz `DIVERGENTE` e reprova quando o conteúdo de um blob é alterado sem renomear o arquivo.** É o único **achado** que leva o verificador a sair 1.

**`wB1[4b]` — o canal legitimamente vazio: `blobs/` sem arquivo nenhum e nenhuma mensagem com `body_ref`.** Asserções: rc 0; a saída contém `nada a verificar` e o contador zerado; a saída **não** contém a palavra íntegro. É o desfecho que a revisão 1 deixou indefinido entre §2.4 e §2.8, e sem ele o implementador escolheria entre reprovar um canal recém-aberto e dizer que ele está íntegro sem ter olhado para nada — as duas erradas.

**`wB1[5]` — o verificador diz `NÃO VERIFICADO — esquema de nome desconhecido` para `blobs/anexo.txt`, e NÃO reprova.** É o terceiro estado da invariante 2 do plano, e o cenário que impede que a onda entregue um verificador que confunde "não sei ler este nome" com "este arquivo está corrompido".

**`wB1[6]` — o verificador conta `AUSENTE` para `body_ref` sem arquivo, e `órfão` para arquivo sem `body_ref`, e nenhum dos dois reprova.** Distinguir os dois é o ponto: um é dívida de conteúdo (é #107) e o outro é custo de disco.

**`wB1[7]` — os dois esquemas convivem no MESMO canal e o `import` instala os dois.** Duas mensagens, uma com blob legado e outra com blob corrente, num bundle só. *Como falha hoje:* o cenário nem chega a ser escrito, porque o esquema corrente não existe.

### 2.6 Prova de mutação, com controle e recontrole

Alvo: `template/.forge/scripts/lib/liaison-merge.mjs` (função `blobName`).

Protocolo, com o cuidado de LDG-0164 e de `feedback-mutacao-fantasma-restore`:

1. `sha_antes` do alvo, gravado.
2. **Propriedade, não primitivo:** a mutação é aplicada por **substituição integral do arquivo a partir de uma cópia preparada em `$TMPDIR`**, nunca por edição in-place com interpolação de shell ou de perl. `perl -0pi -e 's/x/y$var/'` com `$` sem escape do lado direito interpola variável do **perl**, que é vazia, e transforma a mutação em no-op enquanto o `cmp` confirma que o arquivo mudou — é LDG-0164, e o passo 3 existe para pegá-lo.
3. `sha_mutado`, e **asserção de controle da própria mutação**: `[ "$sha_mutado" != "$sha_antes" ]`.
4. Rodar os cenários e exigir o FAIL **com a mensagem que a asserção declara**. FAIL por outra mensagem não conta.
5. Restaurar por cópia da íntegra; `sha_depois`; asserção `[ "$sha_depois" = "$sha_antes" ]`.
6. **Recontrole:** rodar de novo e exigir PASS.

O alvo é arquivo rastreado e distribuído no pacote npm, então o gate **copia a árvore para `$TMPDIR` e muta a cópia** — LDG-0175 registra o gate desta suíte que usou arquivo rastreado como fixture, não restaurou, e foi encontrado com o arquivo de 70 linhas reduzido a um stub de 3.

| Mutação | Contrafactual que ela precisa produzir | Cenário que morde |
|---|---|---|
| M1 — `blobName` volta a hashear `buf.toString('binary')` | o hexadecimal do nome deixa de ser reproduzível por `shasum -a 256`, e a asserção de `[2]` falha nomeando o nome obtido | `wB1[2]`, `w110[6]` |
| M2 — `blobName` deixa de emitir o prefixo `sha256-`, mantendo o digest dos bytes | com a fixture ACENTUADA de `[2]` o nome vira `<sha256(bytes)>-<base>`, que casa a forma legada e **não** casa a fórmula legada: o veredito é **DIVERGENTE** pela alínea (c), e `[2]` falha por esquema errado | `wB1[2]` apenas |
| M3 — o verificador passa a tratar nome desconhecido como íntegro | `[5]` deixa de observar `NÃO VERIFICADO` e passa a ver um verde, e falha | `wB1[5]` |
| M4 — o verificador para de comparar o digest e só confere a forma do nome | `[4]` deixa de reprovar o blob adulterado | `wB1[4]` |

**A linha de M2 foi reescrita na revisão 2, e a correção é medida.** A revisão 1 declarava que M2 faria o verificador classificar o blob novo como **legado** e que a mutação mordia também `wB1[3]`. As duas metades estavam erradas, e o contrafactual que as derruba é este:

```
$ printf 'corpo com acentuação: não, ação\n' > acc.txt ; printf 'plain ascii body\n' > asc.txt
$ node -e 'const{createHash}=require("crypto"),fs=require("fs");
for(const f of process.argv.slice(1)){const b=fs.readFileSync(f);
 const bytes=createHash("sha256").update(b).digest("hex");
 const leg=createHash("sha256").update(b.toString("binary"),"utf8").digest("hex");
 console.log(`${f} alto=${b.some(x=>x>0x7F)} sha256=${bytes.slice(0,16)}… legado=${leg.slice(0,16)}… iguais=${bytes===leg}`);}' acc.txt asc.txt
acc.txt alto=true  sha256=9752db9c43be5162… legado=5a0fd6404c095ced… iguais=false
asc.txt alto=false sha256=6116bb4ed1f58530… legado=6116bb4ed1f58530… iguais=true
```

Com a fixture acentuada que `wB1[2]` exige, o nome que M2 produz **não** é reproduzível pela fórmula legada, então o veredito correto é DIVERGENTE e não "íntegro (legado)". E `wB1[3]` usa um blob legado **escrito à mão pela fixture**, que M2 não toca em hipótese nenhuma: uma mutação em `blobName` não altera arquivo que a fixture criou fora do caminho de escrita. O veredito de M2 depende do conteúdo da fixture — DIVERGENTE se acentuada, íntegro-legado se ASCII —, e é por isso que `[2]` precisa ser o cenário acentuado.

**M1 e M2 exigem execução contra a implementação real antes de a linha da matriz ser considerada fechada.** Declaro a propriedade e o contrafactual; quem executa prova que o primitivo escolhido discrimina, porque M2 tem um modo de falha silencioso conhecido: se o verificador for tolerante com a ausência do prefixo, M2 vira no-op e mede o engano.

### 2.7 PBT — onde há espaço de entrada

O nome de blob é um serializador sobre um espaço de entrada aberto, então cai na invariante 5 do plano. Três propriedades, sobre `Buffer` gerado (bytes aleatórios incluindo acima de `0x7F`, vazio, e o limite `BLOB_MAX_BYTES = 65536`), e sobre `base` gerado (nomes com acento, com espaço, com barra, vazio):

1. **Discriminação total:** para todo par `(buf, base)`, `blobName` começa por `sha256-` e `blobNameLegacy` **não** começa por `sha256-`. É a propriedade que sustenta a Decisão 1 e ela precisa ser afirmada sobre entrada gerada, não sobre três exemplos.
2. **Reprodutibilidade externa:** para todo `buf`, o hexadecimal extraído de `blobName(buf, base)` é igual a `createHash('sha256').update(buf).digest('hex')`. É a promessa que a issue diz estar quebrada, escrita como propriedade.
3. **Sanidade do nome:** para todo `base`, o nome produzido casa `BODY_REF_RE` quando prefixado por `blobs/`. Sem isso, um `base` com caractere fora de `[A-Za-z0-9._-]` produziria mensagem que o próprio import recusa.

O gerador vive em `lib/pbt.mjs`, que já existe. A revisão 1 dizia que `w169` é quem o usa; medido, `w169-liaison-merge-union-property-gate.sh` traz gerador próprio e não menciona `pbt.mjs` — `grep -rln 'pbt.mjs' tests/` devolve `w121-pbt-harness-gate.sh`, `w130-tasks-graph-gate.sh` e `w132-route-surface-gate.sh`, e são esses os três precedentes a copiar. A escolha do módulo continua certa; a referência é que estava trocada.

### 2.8 Contador de controle, com denominador fixo

`wB1` declara `SCEN_MIN` como **constante escrita no arquivo**, igual ao número de cenários que moram **neste arquivo** — os de §2.5 mais os de §3.4 — e reprova quando `SCEN` não a alcança. O denominador é dos cenários daquele gate e de nenhum outro: `w110[6]` e `w110[6b]`, citados em §2.5, vivem em `w110` e não entram na conta de `wB1`, e contá-los faria o contador de controle medir um universo que o arquivo não tem. É a única exceção legítima a literal em asserção — denominador fixo por construção, cuja divergência é justamente o achado. Não há cenário ambiental em `wB1`: nenhum mexe em `PATH` nem depende de capacidade da máquina além de `node`, que o gate já exige no pré-voo.

**A guarda de vacuidade é do GATE, não do subcomando — e a revisão 1 confundia as duas.** O que reprova com `universo-vazio` é o gate `wB1`, via `forge_universe_check` de `lib/gate-universe.sh` (o mecanismo já usado por `w198[6]`, e uma lib de bancada, sourceada por gate, que produção nenhuma importa), sobre o número de blobs que a **fixture de `wB1` produziu**. A fixture tem blobs por construção — `[2]`, `[3]`, `[4]` e `[5]` escrevem um cada —, então zero ali significa que a fixture quebrou, e é isso que a guarda pega. O subcomando, esse, tem o desfecho `nada a verificar` de §2.4 e sai 0 num canal legitimamente vazio, com `wB1[4b]` a provar. Um verificador de integridade que aprova por não ter olhado para blob nenhum é a falha clássica da invariante 3; um que reprova todo canal recém-aberto é a invariante 18, a guarda de vacuidade disparando no caminho feliz. As duas se evitam separando quem publica o contador (o subcomando) de quem exige piso sobre ele (o gate).

**O denominador do universo NUNCA é literal.** O número de blobs de um canal muda a cada mensagem com corpo; a asserção é `> 0` mais a igualdade contra o total contado na própria fixture, jamais um número escrito no gate. É a invariante 14 do plano, e três especificações desta rodada nasceram com esse defeito.

### 2.9 Retrocompatibilidade — medida, não assumida

**O que já está instalado.** Três consumidores com o harness instalado: `axis-fare-validator` e `axis-go-cloud` em `0.14.0`, `Axis.PadSimulator` em `0.11.0` (lido em `.forge/cache/machinery.lock` e em `.forge/forge.yaml`).

**O nome novo é aceito pelos três, incluindo o de `0.11.0`.** Executado nesta rodada sobre as cópias instaladas:

```
axis-fare-validator: 267:export const BODY_REF_RE = /^blobs\/[A-Za-z0-9._-]+$/;
axis-go-cloud:       267:export const BODY_REF_RE = /^blobs\/[A-Za-z0-9._-]+$/;
Axis.PadSimulator:   211:export const BODY_REF_RE = /^blobs\/[A-Za-z0-9._-]+$/;
--- schema instalado: os três com "pattern": "^blobs/[A-Za-z0-9._-]+$"
--- regex contra "blobs/sha256-<64 hex>-corpo.md": true
```

Ou seja: **o esquema versionado não exige mudança de schema, não exige mudança de `validateEnvelope` e não exige que nenhum consumidor atualize para receber a mensagem.** Um peer em `0.11.0` importa uma mensagem com nome novo hoje, sem nenhuma ação. Esse é o argumento decisivo a favor da Decisão 1 sobre as outras duas, e ele é uma medição, não uma expectativa.

**O que quebra.** Nada em campo. O que muda dentro deste repositório é uma asserção de gate (`w110[6]`, §10), o texto normativo de `template/.forge/commands/harness/liaison.md`, que descreve o layout `blobs/`, e — porque a edição do comando obriga — **o espelho `plugin/forge/commands/liaison.md`, regenerado por `npm run build:plugin` e commitado no mesmo change**. `tests/plugin-sync-gate.sh:19-26` regenera `plugin/forge` a partir de `template/.forge/commands` e exige `diff -r` limpo contra o commitado; sem a regeneração a onda entrega esse gate vermelho, com `FAIL: plugin/forge dessincronizado — rode: npm run build:plugin`. O comando é `npm run build:plugin` e nunca `build-plugin.sh`, que instala em `$HOME`. Entra em §10 e na definição de pronto de §12.

**O que fica divergente por decisão:** o acervo inteiro — 1094 nomes distintos no dia da medição de §2.2 — continua sob nome legado, para sempre, e o verificador continua sabendo lê-lo para sempre. Retirar o suporte ao esquema legado exigiria a migração que §2.4 refutou, e por isso `blobNameLegacy` não tem data de aposentadoria.

---

## 3. ITEM 2 — issue #107: a instalação do blob mora no laço errado

### 3.1 O defeito, reproduzido — e a prova de que o corpo estava ao alcance

`lib/liaison-import.mjs:229-244`: o laço que instala blobs é `for (const [sender, toAdd] of batch)`, e `toAdd` só contém mensagem **nova e dentro do lote**. Mensagem já conhecida é descartada antes, na linha 198 (`const already = existingById.get(raw.msg_id); if (already) { dup++; continue; }`), e mensagem acima do teto `IMPORT_MAX_MESSAGES` nunca entra em `batch`. O `existsSync(dest)` da linha 241 expressa a intenção certa — instalar o que falta — e está no laço errado.

Reproduzido na bancada A, com o corpo apagado de uma réplica que já conhece a mensagem. A sequência é `send --body-file` em A, `sync` em A, `sync` em B (que recebe o blob), `rm` do blob em B, `sync` em B de novo:

```
blob em repo-b antes do rm: SIM
rc=0
OK sync via fs — 0 nova(s), 2 duplicata(s) (no-op), 0 conflito(s), 0 em quarentena
blob em repo-b depois do sync: NAO — o corpo não voltou (ponteiro morto permanece)
o blob está no hub? SIM
```

A última linha é a que transforma o item em recusa a instalar: o corpo está no ponto de encontro, o `sync` volta a passar por ele, e o arquivo não retorna.

**E o corpo estava ao alcance.** Materializei o mesmo `staging` que o `sync` materializa, chamando `_dir_pull` sobre o hub:

```
blob presente na réplica B? NAO
blobs no staging materializado pelo pull: 1
o blob perdido está no bundle? SIM
```

Isto é o que transforma o item de "perda de dado" em "recusa a instalar o que já está na mão": o `_dir_pull` copia **todos** os blobs do hub (`lib/transports/_common.sh:233-237`), o bundle chega completo, e o import não o instala porque a mensagem não é nova.

### 3.2 O censo de hoje — e ele NÃO é o da issue

A issue reporta 145 ponteiros mortos em 29 réplicas. Remedi na bancada C, com o `censo-canal.mjs` colado em §5.1, sobre as quatro árvores principais:

```
$ node censo-canal.mjs template/.forge/scripts/lib \
    ~/Documents/projects/{axis-fare-validator,axis-go-cloud,Axis.PadSimulator,forge-harness}
…
replicas=9 body_refs=3478 PONTEIROS_MORTOS=0
```

**Zero, não cento e quarenta e cinco.** O campo reparou o passivo à mão desde a abertura da issue — o próprio corpo dela cita o commit `843ac08`, "recupera do hub os 14 corpos que o sync não trouxe". Registro isso porque `feedback-medir-antes-de-implementar` é exatamente esta lição: item de ledger envelhece e descreve o defeito maior do que ele é hoje.

**A revisão 1 dizia `355 réplicas`, `96185 body_ref` e `2 ponteiros mortos`, e esses três números foram REMOVIDOS.** Eles vinham da mesma varredura com worktrees que §2.2 descartou, e o revisor, varrendo só as quatro árvores, mediu 9/3466/0 — que é o mesmo que eu meço agora, a menos do envelhecimento de uma semana. Os dois ponteiros mortos da revisão 1 estavam em worktree, isto é, em cópia de trabalho de uma branch, não no acervo do canal; contá-los como passivo de campo era exagerar o item. **O passivo de campo hoje é zero, e o item continua existindo** — porque o que o justifica é o mecanismo de §3.1, reproduzido em bancada, e não o tamanho do estrago acumulado. Um defeito que não deixou passivo hoje deixa amanhã: o próprio commit `843ac08` é a prova de que ele já deixou.

### 3.3 Decisões de desenho — FECHADAS

**Decisão 5 — a reconciliação vira passada própria, sobre TODA mensagem com `body_ref` do bundle, e não sobre `batch`.**

A passada roda depois da escrita dos logs e itera sobre a união de (a) todas as mensagens do bundle com `body_ref` que sobreviveram à passada 1 e (b) todas as mensagens já presentes no log local com `body_ref`. A alínea (b) não é redundante: uma réplica pode ter perdido o corpo de uma mensagem que **não veio neste bundle** — por exemplo, mensagem própria, que `_dir_pull` nunca traz de volta por desenho —, e a reconciliação precisa alcançá-la se o blob estiver no bundle por outro caminho.

**Alternativa descartada — mover o laço de instalação para antes do corte do lote.** Consertaria o caso do teto e deixaria de fora o caso das duplicatas, que é o do campo (`2 duplicata(s) (no-op)` na saída colada acima). Meia correção num defeito cuja causa é acoplamento entre "instalar corpo" e "aceitar mensagem" reintroduz o acoplamento por outra porta.

**Decisão 6 — corpo que continua ausente depois da passada é `WARN` com contador, nunca conflito e nunca recusa.**

O import passa a devolver `bodiesMissing`, e `_apply_bundle` acrescenta à linha de resultado, **apenas quando maior que zero**, um sufixo no mesmo idioma da cauda de backlog que já existe em `liaison-ops.sh:236-240`. Só quando maior que zero, porque as asserções existentes sobre essa linha são `grep` de substring (`w110[8a]`, `w111[9a]`, `w110[7]`, `w110[11a]`) e um sufixo permanente engordaria toda saída sem informar nada — a mesma disciplina de `posBit`/`skewBit` no `status`.

Não é conflito porque conflito é registro em `conflicts/` que exige decisão humana sobre **a mensagem**, e aqui a mensagem está íntegra: o que falta é um arquivo que a origem pode reenviar. Não é recusa porque um import que reprovasse por corpo ausente transformaria uma réplica com um ponteiro morto antigo em réplica que não consegue mais sincronizar — trocaria uma perda silenciosa por uma parada dura, que é pior.

**Decisão 7 — o `status` ganha o contador de corpos ausentes, calculado por `existsSync`.**

Entra na linha agregada e na linha por canal, no mesmo idioma dos contadores que já existem, **e só aparece quando maior que zero**. É o "número que alguém pode zerar" que a issue pede, e ele é barato: `existsSync` por `body_ref`, sem leitura de conteúdo — o custo de digest fica no `blobs verify` (§2.4, Decisão 3).

**Decisão 8 — a enumeração dos transportes, e por onde `bodiesMissing` é de fato alcançável.** A enumeração dos transportes é exaustiva sobre `lib/transports/`: `fs` e `manual` chamam `_dir_pull`, que copia todos os blobs do hub; `git` chama `_dir_pull` sobre o clone (`git.sh:80-82`); `gh` reprova no `t_probe` por construção e nunca chega ao import.

**A revisão 1 errava o caso não coberto, e a correção é medida.** Ela dizia que o caso era `import --from <dir>` com um bundle que não contém o blob, e que "é exatamente para ele que existe o WARN da Decisão 6". É falso sobre o código de hoje: a passada 1 de `applyBundle` (`lib/liaison-import.mjs:170-174`) transforma esse bundle em **conflito**, antes de qualquer deduplicação, com a razão `blob referenciado ausente no bundle`. Medido na bancada B, com a mensagem já conhecida pela réplica:

```
bundle: log com 2 linha(s), blobs/ com 0 arquivo(s)
rc=0
OK import — 0 nova(s), 1 duplicata(s) (no-op), 1 conflito(s), 0 em quarentena
conflicts/ em repo-b: repo-a-0002.json
```

Essa guarda **fica**: ela é o que impede um ponteiro morto novo de entrar no log e o que sustenta a checagem de `BLOB_MAX_BYTES` sobre o blob recebido. Removê-la seria mudança de contrato, e uma que teria de entrar em §10, §11 e na matriz de mutação — esta onda não a faz.

**Logo, `bodiesMissing > 0` só é alcançável pela alínea (b) da Decisão 5:** mensagem que está no **log local** com `body_ref`, cujo blob não está em `blobs/` e cujo log **não veio neste bundle** — mensagem própria, que `_dir_pull` nunca traz de volta por desenho, ou remetente cujo arquivo de log não faz parte deste bundle. Medido, e é este o estado que `wB1[9]` monta:

```
mensagens com body_ref no log local: 1        blobs em blobs/: 0
bundle2: logs = repo-b.jsonl ; blobs = 0
rc=0
OK import — 0 nova(s), 0 duplicata(s) (no-op), 0 conflito(s), 0 em quarentena
$ liaison-ops.sh status contracts
LIAISON/contracts: 1 thread(s) · 2 não lida(s) · 0 em quarentena
```

O import não vê conflito nenhum — corretamente, porque nada de novo chegou —, e **nem o import nem o `status` dizem uma palavra sobre o corpo que falta**. É o vermelho de `wB1[9]`, e ele é o vermelho certo: sem a Decisão 6 a réplica fica com um ponteiro morto que nenhum comando nomeia.

### 3.4 O VERMELHO, antes do verde

**`wB1[8]` — corpo apagado de mensagem JÁ CONHECIDA volta no `sync` seguinte, pelo canal real.** Bancada A: `A` envia com `--body-file`, `A` faz `sync`, `B` faz `sync` e recebe o blob, `rm` do blob em `B`, `B` faz `sync` de novo. Asserções: o arquivo existe de novo em `B/blobs/`; o conteúdo é byte a byte igual ao original; a saída **não** contém o contador de corpos ausentes. *Como falha hoje:* a saída literal está em §3.1 — `rc=0`, `2 duplicata(s) (no-op)`, e o arquivo não volta. Falha pela ausência real da funcionalidade: `grep -n 'body_ref' template/.forge/scripts/lib/liaison-import.mjs` devolve as linhas 165-183 (validação na passada 1) e 238-243 (instalação dentro de `batch`), e **nenhuma** linha fora do laço de novidades.

**`wB1[9]` — o contador de corpos ausentes aparece quando o corpo que falta está no LOG LOCAL e não vem no bundle, e o comando sai 0.** Fixture, e a ordem dela é o cenário: a réplica já conhece uma mensagem com `body_ref`; o blob é removido de `blobs/`; aplica-se por `import --from` um bundle cujo `blobs/` está vazio e cujo `log/` **não contém o arquivo daquele remetente**. Asserções: rc 0; zero conflitos; a saída nomeia quantos corpos faltaram; o `status` do canal repete o número. *Como falha hoje:* a saída literal está colada na Decisão 8 — `0 nova(s), 0 duplicata(s) (no-op), 0 conflito(s)`, e o `status` sem menção nenhuma; e `grep -rn 'bodiesMissing\|corpo(s) ausente' template/.forge/` devolve zero.

**A fixture da revisão 1 era outra e não podia produzir este contador**: ela mandava aplicar um bundle *com* a mensagem e *sem* o blob, que a passada 1 converte em conflito (medido na Decisão 8). Contra a implementação correta de Decisão 5+6, aquele cenário observaria `1 conflito(s)` e nenhum contador de corpos ausentes, e falharia — um vermelho fabricado, que a invariante 1 do plano proíbe. A troca da fixture é a correção, e ela não muda uma vírgula das Decisões 5, 6 e 7.

**`wB1[10]` — o cenário de vacuidade do contador: canal sem nenhuma mensagem com `body_ref` NÃO imprime o contador.** É o par negativo obrigatório: sem ele, um contador que imprimisse sempre `0 corpo(s) ausente(s)` passaria em `[9]` sem medir nada.

**`wB1[11]` — reconciliação de mensagem acima do teto do lote.** Bundle com mais de `IMPORT_MAX_MESSAGES` mensagens, todas com `body_ref`: o primeiro `import` aplica o prefixo e **instala o blob de todas**, inclusive das que ficaram no backlog. *Como falha hoje:* as que ficam fora de `batch` nunca alcançam a linha 239. É o segundo braço do defeito, e a issue não o nomeia — ela descreve só o braço das duplicatas.

### 3.5 Prova de mutação

| Mutação | Contrafactual medido/esperado | Cenário que morde |
|---|---|---|
| M5 — a passada de reconciliação volta a iterar sobre `batch` em vez da lista completa | `[8]` volta a observar o arquivo ausente depois do `sync`, com `rc 0` e `duplicata(s)` na saída — é literalmente o estado de §3.1, que **já medi** | `wB1[8]` |
| M6 — a contagem de corpos ausentes é zerada na origem | `[9]` deixa de ver o contador na saída e falha | `wB1[9]` |
| M7 — a reconciliação instala sem conferir `existsSync(dest)` | o blob local é sobrescrito pelo do bundle a cada sync; `[8]` continua verde e o cenário que morde é um novo `[8b]`, com `mtime`/conteúdo local propositalmente distintos, que não pode ser sobrescrito | `wB1[8b]` |

**M7 é a mutação cujo contrafactual eu NÃO medi**, e digo em letra: ela exige um `[8b]` que ainda não existe e cuja discriminação depende de um sinal que distinga "não tocou" de "reescreveu com o mesmo conteúdo". A invariante 19 do plano nomeia dois primitivos que **não** servem para isso nesta máquina — `git diff-files` não reporta `touch` no mesmo segundo, pela regra racy-clean, e `stat -f %m` tem granularidade de segundo no macOS. Quem implementar escolhe o primitivo e **prova que ele discrimina**, com repetição, antes de escrever a linha de `[8b]`.

O protocolo de mutação é o de §2.6, sem alteração: `sha_antes`, substituição integral a partir de cópia em `$TMPDIR`, asserção de que o `sha` mudou, FAIL com a mensagem declarada, restauração por checksum, recontrole verde.

---

## 4. ITEM 3 — issue #109: o `sync` publica e não deixa marca d'água

### 4.1 O defeito, e o que ele é HOJE

`liaison-ops.sh:1267-1269` é `if [ "$do_push" -eq 1 ]; then t_push || { … }; fi`, e nada é escrito localmente depois de um `t_push` bem-sucedido. Medido na bancada A, depois de um `sync` que publicou duas mensagens:

```
$ cat repo-a/.forge/liaison/contracts/state.json
{"cursors":{}}
$ node -e 'console.log(Object.keys(JSON.parse(...)))'
[ 'cursors' ]
```

E nas quatro árvores de campo, nas nove combinações árvore × canal existentes, medido pelo `censo-canal.mjs` de §5.1: `canais_sem_marca_published=9` e `state.json keys: ["cursors"] em 9`.

**O defeito está LATENTE hoje, e isso muda o que a prova precisa ser.** Comparei o log próprio de cada réplica contra a cópia do mesmo remetente no hub, por `msg_id`. O script de bancada, colado inteiro porque a revisão 1 dava só a tabela e o revisor não a reproduziu:

```
$ cat paridade.mjs
import { readFileSync, readdirSync, existsSync } from 'fs';
import { join, basename } from 'path';
const roots = process.argv.slice(2);
const ids = (p) => existsSync(p)
  ? new Set(readFileSync(p,'utf8').split('\n').filter(l=>l.trim()).map(l=>JSON.parse(l).msg_id))
  : new Set();
for (const root of roots) {
  const base = join(root, '.forge', 'liaison');
  if (!existsSync(base)) continue;
  const yaml = readFileSync(join(base, 'liaison.yaml'), 'utf8');
  const self = (yaml.match(/^self:\s*\n\s+id:\s*(\S+)/m) || [])[1];
  const map = {}; let cur = null;
  for (const line of yaml.split('\n')) {
    let m = line.match(/^ {2}([A-Za-z0-9._-]+):\s*$/); if (m) cur = m[1];
    m = line.match(/^\s+path:\s*"?([^"]+)"?\s*$/); if (m && cur) { map[cur] = m[1]; cur = null; }
  }
  for (const ch of readdirSync(base).filter(d => existsSync(join(base, d, 'log')))) {
    const local = ids(join(base, ch, 'log', `${self}.jsonl`));
    const hub = map[ch] ? ids(join(map[ch], ch, 'log', `${self}.jsonl`)) : new Set();
    const soLocal = [...local].filter(x => !hub.has(x)).length;
    console.log(`${(basename(root)+'/'+ch).padEnd(42)} local=${local.size} hub=${hub.size} SO_LOCAL=${soLocal}`);
  }
}

$ node paridade.mjs ~/Documents/projects/{axis-fare-validator,axis-go-cloud,Axis.PadSimulator,forge-harness}
axis-fare-validator/axis-contracts         local=594  hub=594  SO_LOCAL=0
axis-fare-validator/axis-device-cloud      local=10   hub=10   SO_LOCAL=0
axis-fare-validator/forge-harness          local=116  hub=116  SO_LOCAL=0
axis-go-cloud/axis-contracts               local=623  hub=623  SO_LOCAL=0
axis-go-cloud/axis-device-cloud            local=10   hub=10   SO_LOCAL=0
axis-go-cloud/forge-harness                local=103  hub=103  SO_LOCAL=0
Axis.PadSimulator/axis-contracts           local=477  hub=477  SO_LOCAL=0
Axis.PadSimulator/forge-harness            local=94   hub=94   SO_LOCAL=0
forge-harness/forge-harness                local=4    hub=4    SO_LOCAL=0
```

**Uma nota de bancada que vale mais que a tabela**, e que só apareceu porque desta vez o script foi colado: a primeira versão dele casava a chave do canal com `^ {4}` em vez de `^ {2}`, não achava o `path` de nenhum canal, e imprimia `hub=0 SO_LOCAL=<tudo>` nas nove linhas — isto é, **um passivo inteiro fabricado por um erro de indentação no parser**. O sinal de que o script estava errado e não o campo foi o `hub=0` uniforme; quem cola o script dá ao revisor a chance de ver isso, quem cola só a tabela não.

Nove de nove em paridade, `SO_LOCAL=0` em todas. A issue mediu duas ocorrências reais (`axis-pad-simulator-0067` e `0068`) e um episódio de 90 minutos no `axis-fare-validator`; hoje o estado está limpo. **Consequência para o método:** o vermelho de #109 **não pode** se apoiar no estado de campo, porque ele hoje é silencioso em 9 de 9 — a discriminação tem de ser provada em bancada, com um caso desigual construído e um caso igual pareado, e é assim que §4.3 está escrita.

### 4.2 Decisões de desenho — FECHADAS

**Decisão 9 — a marca é `published: { seq, at }` em `state.json`, escrita ao fim de um `t_push` bem-sucedido, e `at` é relógio de parede.**

`created_at` não serve, e a issue já explica por quê: ele é a data do commit `HEAD` no instante do `send` (`liaison-ops.sh:99`, `_git_date`), deliberadamente. A prova de que o campo já mente sobre tempo é o próprio contador de incoerência que o `status` publica — mensagem cujo `created_at` é ANTERIOR ao da mensagem que ela responde. A revisão 1 citava `195` sem dizer sobre que denominador; remedido com o `censo-canal.mjs` de §5.1, que reusa `mergeLogs` do template e portanto aplica a mesma regra que o `status` aplica, o total sobre as quatro árvores é `created_at_incoerentes=665`. O número é testemunha de data; o que decide é que ele não é zero, e não pode ser, porque a data do commit `HEAD` não tem relação com a ordem em que as mensagens são escritas. O relógio de parede é aceitável aqui pelo mesmo motivo pelo qual já é aceito em `cursors[].read_at`, e o comentário de `liaison-ops.sh:50` diz isso em letra — a marca é **estado local de leitura/publicação**, nunca conteúdo publicado, então ela não entra em nenhum `content_sha` e não atravessa a fronteira.

**Decisão 10 — a marca cobre o LOG, e o texto diz isso.**

Medição minha, não da issue, reexecutada na revisão 2: no caminho `ff`, `_dir_push` devolve **0** com o log publicado e **zero blobs** no hub quando a cópia de blob falha. Reproduzido na bancada A com `chmod 500` no `blobs/` do hub, um `send --body-file` pendente e `sync --push-only`:

```
push rc=0
OK liaison-push-union: hub=0 local=2 união=2
cp: …/hub/contracts/blobs/.373b8f1f…-aaa.md.tmp: Permission denied
OK sync — push-only via fs (log de repo-a publicado)
log publicado no hub? SIM
blobs no hub: 0
```

A causa é o `return 0` incondicional que se segue a `_dir_push_blobs` e descarta o rc dele. E ele não está só no ramo `ff`: **os dois ramos de união repetem o mesmo padrão** — o `0)` em `_common.sh:152-157` e o `1)`, réplica atrasada, em `_common.sh:166-172`. O ramo de reparo declarado (`2)` sob `--repair-own-log`) cai no laço inline do fim da função, que **propaga** o rc; as duas metades do mesmo arquivo discordam. Portanto `published.seq` significa **"o log até este seq foi publicado"** e nada afirma sobre corpos. Escrever a marca com outro nome ou outra promessa seria criar uma segunda afirmação falsa dentro da correção de uma primeira. O defeito do `return 0` **não é corrigido nesta onda** e vira item de ledger (§14, item 1, agora nomeando os dois ramos).

**Decisão 11 — o `status` só fala quando há diferença, e a ausência de marca é SILÊNCIO, não "tudo não publicado".**

É a decisão de retrocompatibilidade mais cara desta onda, e ela é sustentada por medição — `mensagens_proprias=2031` e `canais_sem_marca_published=9` na saída do `censo-canal.mjs` de §5.1, sobre as nove combinações de campo. Um `status` que lesse marca ausente como `seq: 0` imprimiria, na primeira sessão depois do upgrade, nove linhas afirmando que dois mil e tantas mensagens estão por publicar — todas falsas, e todas no `SessionStart`, que é o primeiro texto que o operador lê. Marca ausente é **estado desconhecido**, e o vocabulário para estado desconhecido é o silêncio no contador mais, no `blobs verify`/`doctor`, a menção explícita de que a marca ainda não existe.

**Decisão 12 — a enumeração dos desfechos de push, e os dois casos que não são óbvios.** Exaustiva sobre os quatro `kind`: `fs`, `manual` e `git` escrevem a marca quando `t_push` devolve 0; `gh` reprova no `t_probe` e o `sync` aborta antes de qualquer escrita. Os dois casos que uma enumeração apressada perde: **(a) réplica sem log próprio** — `_dir_push` pula o ramo do log (`[ -f "$own" ]` falso) e devolve 0, e a marca nasce com `seq: 0`, o que faz o `status` calar corretamente; **(b) `git` sem nada novo a publicar** — `t_push` devolve 0 no ramo `git diff --cached --quiet` (`git.sh:65`), e a marca é escrita mesmo assim, o que é correto porque o hub já contém o log. Um terceiro caso, `sync --pull-only`, não escreve marca nenhuma, e o `status` passa a acusar a diferença — que é o comportamento desejado, porque `--pull-only` é literalmente "não publiquei". E um quarto, procurado de propósito porque a invariante 17 manda procurar o caso não coberto em vez de esperar por ele: **canal sem transporte configurado**. `_read_transport` devolve vazio e o comentário de `liaison-ops.sh:151` diz em letra que "o caller decide se isso é erro (`sync`) ou informação (`show`)" — o `sync` aborta antes de qualquer `t_push`, então nenhuma marca é escrita, e é o desfecho certo pelo mesmo motivo do `gh`: não houve publicação. Os quatro `kind` foram conferidos por leitura — `fs.sh`, `git.sh`, `gh.sh` e `manual.sh` definem `t_push`, `_common.sh` não define nenhum —, e o caso sem transporte fica de fora da enumeração por `kind` justamente porque não tem `kind`.

**Decisão 13 — `export` NÃO escreve a marca.** `export` materializa um bundle que pode nunca ser entregue; carimbar publicação ali seria a mesma confiança falsa que a issue ataca, com a agravante de ser produzida pelo próprio conserto.

**Decisão 14 — `published.seq` maior que o maior `seq` próprio é ANOMALIA, nomeada, nunca contador negativo.** Estado alcançável por restauração de backup do log próprio ou por `git checkout` de uma versão anterior de `log/<self>.jsonl`. O `status` imprime uma linha que nomeia a inconsistência e não computa contagem; sem esta decisão, a subtração produziria um número negativo e alguém escreveria `Math.max(0, …)`, que é apagar o sintoma.

**Decisão 15 — o gate de acks continua cego ao outbox, e isso é preservado.** `check-liaison-acks.sh:220-224` cobra apenas o próprio ack sobre mensagem de terceiro, por regra declarada no cabeçalho, e ler o hub de dentro dele reintroduziria a janela de staleness que o cabeçalho recusa. Esta onda **não toca** `check-liaison-acks.sh`, e há um segundo motivo, operacional: aquele arquivo já está no escopo da Onda D (item 7 do censo de §5.1 da spec da Onda D), e duas ondas editando o mesmo arquivo é colisão de merge programada.

### 4.3 O VERMELHO, antes do verde

**`wB2[1]` — depois de um `sync` bem-sucedido, `state.json` contém `published.seq` igual ao maior `seq` próprio, e `published.at` é um instante ISO posterior ao início do teste.** *Como falha hoje:* a saída literal está em §4.1 — `state.json` tem exatamente uma chave, `cursors`. Falha pela ausência real da funcionalidade: `grep -rn 'published' template/.forge/scripts/liaison-ops.sh` devolve zero.

**`wB2[2]` — o par desigual: `send` depois do `sync` faz o `status` acusar `1 própria(s) não publicada(s)`.** *Como falha hoje:* o `status` não tem o campo para comparar e imprime a linha de sempre.

**`wB2[3]` — o par IGUAL, pareado e obrigatório: `send` seguido de `sync` faz o `status` CALAR.** Sem este cenário, `[2]` não distingue "o predicado funciona" de "o predicado alarma sempre" — e é exatamente a distinção que o campo hoje não consegue fazer, porque 9 de 9 combinações estão em paridade (§4.1).

**`wB2[4]` — marca AUSENTE (o estado de todos os consumidores hoje) faz o `status` CALAR, com log próprio não vazio.** Fixture: `state.json` com apenas `cursors` e três mensagens próprias. Asserção: a saída **não** contém o contador de não publicadas. É a Decisão 11 escrita como asserção, e é o cenário que impede a onda de publicar um alarme falso em quatro árvores de produção.

**`wB2[5]` — `sync --pull-only` não escreve a marca, e o `status` acusa.** É o par que prova que a marca é escrita pelo push e não pelo comando, e **a ordem da fixture é o cenário**: `sync` completo primeiro (que grava a marca), depois `send`, depois `sync --pull-only`, e só então `status`. Lido ao pé da letra sem essa ordem — `send`, `--pull-only`, `status` — a marca estaria AUSENTE, a Decisão 11 mandaria calar, e o cenário falharia contra a implementação correta. A asserção é que a marca continua no valor de antes do `send`, e que o contador acusa exatamente a mensagem nova.

**`wB2[6]` — `published.seq` maior que o maior `seq` próprio produz linha de anomalia nomeada e nenhum contador.** Decisão 14 como asserção.

**`wB2[7]` — `gh` reprova no probe e nenhuma marca é escrita.** O `state.json` fica byte a byte idêntico ao de antes da tentativa.

### 4.4 Prova de mutação

| Mutação | Contrafactual que ela precisa produzir | Cenário que morde |
|---|---|---|
| M8 — a escrita da marca é removida do fim do `sync` | `[1]` deixa de encontrar `published` e falha nomeando a chave ausente | `wB2[1]` |
| M9 — o `status` passa a ler a marca como o maior `seq` local (isto é, "finge que já publicou tudo") | `[2]` volta ao silêncio e falha; `[3]` continua verde, o que é o ponto — a mutação precisa derrubar **só** o caso desigual | `wB2[2]` |
| M10 — o `status` passa a tratar marca ausente como `seq: 0` | `[4]` passa a ver o contador e falha; e `[2]`/`[3]` continuam como estavam | `wB2[4]` |

M9 é a mutação que a própria issue já executou, no predicado equivalente (`hub_ids="$local_ids"`), e o efeito relatado lá — o caso que alarmava volta ao silêncio — é o mesmo que a matriz declara. **Ainda assim ela precisa ser reexecutada sobre a implementação real antes de a linha ser dada por fechada**, porque o predicado desta onda lê `state.json` e não o hub.

### 4.5 Contador de controle e PBT

`wB2` declara `SCEN_MIN` como constante no arquivo, e o denominador é dos cenários que moram **neste arquivo**: os sete de §4.3, os três de §5.4 que são `wB2[8]`, `wB2[9]` e `wB2[10]`, e os três de §6.3 que são `wB2[11]`, `wB2[12]` e `wB2[13]`. Ficam de fora `w195[12]`-`[14]`, `w112[8]` e `npx-pack-gate[6]`, que vivem em outros arquivos, e a revisão 1 os contava aqui por engano — o contador de controle só funciona se o denominador for o do próprio gate. Também fica de fora §6.4, que é matriz de mutação e PBT e não tem cenário nenhum. Nenhum é ambiental.

**PBT sobre o comparador de publicação.** Espaço de entrada: pares `(maiorSeqLocal, published)` com `published` ausente, `published.seq` menor, igual, maior e não numérico. Propriedades: (i) a saída é ausente-de-contador quando `published` é ausente; (ii) o contador é `maiorSeqLocal - published.seq` quando positivo; (iii) nunca há contador negativo, em nenhuma entrada; (iv) `published.seq` não numérico cai na anomalia da Decisão 14, jamais em `NaN` impresso. A quarta propriedade existe porque `state.json` é arquivo em disco que qualquer processo pode corromper, e `JSON.parse` aceita `{"published":{"seq":"x"}}` sem reclamar.

---

## 5. ITEM 4 — issue #108: três resíduos

### 5.1 Resíduo 1 — o passivo de cursor pré-#105, medido

A issue diz "dimensão em campo: por medir", e cita números que não foram reproduzidos. Medi na bancada C, contando mensagem de terceiro que **este** repositório ackou e que continua depois do cursor da thread. A revisão 1 dava a tabela sem o script, o revisor não a reproduziu, e ele apontou a razão certa: reproduzir exige a composição de thread mais a regra de ack, que a Decisão 16 proíbe reimplementar. A saída é colar o script — que **não** reimplementa a regra, e sim importa `mergeLogs` do próprio template, exatamente como o `status` faz:

```
$ cat censo-canal.mjs
import { readFileSync, readdirSync, existsSync } from 'fs';
import { join, basename } from 'path';
import { pathToFileURL } from 'url';
const [, , lib, ...roots] = process.argv;
const M = await import(pathToFileURL(join(lib, 'liaison-merge.mjs')).href);
const channels = (root) => { const b = join(root,'.forge','liaison');
  return existsSync(b) ? readdirSync(b).filter(d => existsSync(join(b,d,'log'))).map(d => ({name:d, dir:join(b,d)})) : []; };
const loadAll = (chDir) => { const out=[]; const ld=join(chDir,'log');
  for (const f of readdirSync(ld).filter(f=>f.endsWith('.jsonl')))
    for (const l of readFileSync(join(ld,f),'utf8').split('\n')) if (l.trim()) out.push(JSON.parse(l));
  return out; };
const selfOf = (root) => { const c=join(root,'.forge','liaison','liaison.yaml');
  if (!existsSync(c)) return null;
  const m = readFileSync(c,'utf8').match(/^self:\s*\n\s+id:\s*(\S+)/m); return m ? m[1] : null; };
const TOT = { replicas:0, bodyRefs:0, dead:0, msgs:new Set(), withBody:new Set(), blobs:new Set(),
              skew:0, own:0, noMark:0, stateKeys:new Map() };
for (const root of roots) {
  const self = selfOf(root);
  let ackUnread=0, thr=0, comCursor=0, naoLidas=0, movThreads=0, marcadas=0, colaterais=0;
  for (const c of channels(root)) {
    TOT.replicas++;
    const all = loadAll(c.dir);
    for (const m of all) TOT.msgs.add(m.msg_id);
    for (const m of all) { if (!m.body_ref) continue;
      TOT.bodyRefs++; TOT.withBody.add(m.msg_id); TOT.blobs.add(m.body_ref.slice(6));
      if (!existsSync(join(c.dir, m.body_ref))) TOT.dead++; }
    const { threads, clockSkews } = M.mergeLogs(all);
    TOT.skew += clockSkews.length;
    const st = existsSync(join(c.dir,'state.json')) ? JSON.parse(readFileSync(join(c.dir,'state.json'),'utf8')) : {};
    const kk = Object.keys(st).sort().join(',');
    TOT.stateKeys.set(kk, (TOT.stateKeys.get(kk)||0)+1);
    const cursors = st.cursors || {};
    const ownMsgs = all.filter(m => m.sender === self);
    TOT.own += ownMsgs.length;
    if (!st.published) TOT.noMark++;
    const acked = new Set(all.filter(m => m.kind==='ack' && m.sender===self && m.in_reply_to).map(m => m.in_reply_to));
    const byId = new Map(all.map(m => [m.msg_id, m]));
    for (const tid of Object.keys(threads)) {
      thr++;
      const order = threads[tid].order;
      const cur = cursors[tid] && cursors[tid].msg_id;
      const idx = cur ? order.indexOf(cur) : -1;
      if (cur) comCursor++;
      naoLidas += order.length - (idx + 1);
      let ultimaAckada = -1;
      for (let i = idx+1; i < order.length; i++) { const m = byId.get(order[i]); if (!m) continue;
        if (m.sender !== self && acked.has(m.msg_id)) { ackUnread++; ultimaAckada = i; } }
      if (ultimaAckada > idx) { movThreads++; marcadas += ultimaAckada - idx;
        for (let i = idx+1; i <= ultimaAckada; i++) { const m = byId.get(order[i]); if (!m) continue;
          if (!(m.sender !== self && acked.has(m.msg_id))) colaterais++; } }
    }
  }
  console.log(`${basename(root).padEnd(20)} self=${String(self).padEnd(22)} threads=${thr} com_cursor=${comCursor} nao_lidas=${naoLidas} ACKADAS_E_NAO_LIDAS=${ackUnread} | reparo: threads_que_moveriam=${movThreads} marcadas=${marcadas} colaterais_nao_ackadas=${colaterais}`);
}
console.log('---');
console.log(`replicas=${TOT.replicas} body_refs=${TOT.bodyRefs} PONTEIROS_MORTOS=${TOT.dead}`);
console.log(`mensagens_distintas=${TOT.msgs.size} com_body_ref=${TOT.withBody.size} blobs_distintos_referenciados=${TOT.blobs.size}`);
console.log(`mensagens_proprias=${TOT.own} canais_sem_marca_published=${TOT.noMark} created_at_incoerentes=${TOT.skew}`);
console.log('state.json keys: ' + [...TOT.stateKeys].map(([k,v]) => `["${k.split(',').join('","')}"] em ${v}`).join(' · '));

$ node censo-canal.mjs template/.forge/scripts/lib \
    ~/Documents/projects/{axis-fare-validator,axis-go-cloud,Axis.PadSimulator,forge-harness}
axis-fare-validator  self=axis-fare-validator    threads=131 com_cursor=117 nao_lidas=176 ACKADAS_E_NAO_LIDAS=24 | reparo: threads_que_moveriam=13 marcadas=64 colaterais_nao_ackadas=40
axis-go-cloud        self=axis-go-cloud          threads=131 com_cursor=120 nao_lidas=166 ACKADAS_E_NAO_LIDAS=6  | reparo: threads_que_moveriam=5  marcadas=21 colaterais_nao_ackadas=15
Axis.PadSimulator    self=axis-pad-simulator     threads=128 com_cursor=111 nao_lidas=251 ACKADAS_E_NAO_LIDAS=41 | reparo: threads_que_moveriam=16 marcadas=138 colaterais_nao_ackadas=97
forge-harness        self=forge-harness          threads=29  com_cursor=28  nao_lidas=158 ACKADAS_E_NAO_LIDAS=0  | reparo: threads_que_moveriam=0  marcadas=0  colaterais_nao_ackadas=0
---
replicas=9 body_refs=3478 PONTEIROS_MORTOS=0
mensagens_distintas=2267 com_body_ref=1017 blobs_distintos_referenciados=1084
mensagens_proprias=2031 canais_sem_marca_published=9 created_at_incoerentes=665
state.json keys: ["cursors"] em 9
```

**Setenta e uma mensagens ackadas e ainda não lidas** — a revisão 1 media 68 (24/6/38/0) e a diferença está toda no `Axis.PadSimulator`, que ackou três a mais nesses dias. O número da issue, 148, não sobreviveu à remedição em nenhuma das duas rodadas, e o item continua existindo.

**E medi o efeito do reparo antes de decidir a forma dele**, porque é ele que decide: o reparo marcaria **223** mensagens como lidas em **34** threads, e **152 delas nunca foram ackadas** — razão de 2,2 para 1. Não é defeito do reparo: é a semântica de um cursor, que é marca d'água e não conjunto, e é exatamente o que o `ack` de hoje já faz ao avançar (`liaison-ops.sh:727-739`). Mas é um número que ninguém deve descobrir depois de rodar o comando.

**Estes números são de bancada e envelhecem a cada mensagem do canal — nenhum deles entra em asserção de gate.** O número que vale para o operador é o que o `cursors repair --dry-run` publicar no dia em que ele rodar, calculado pelo próprio subcomando com `advanceCursor` de verdade; a bancada aqui serve para dimensionar a decisão, não para ser a fonte dela. É uma sugestão do revisor da rodada 1, e é a certa.

**Decisão 16 — o reparo é subcomando EXPLÍCITO com `--dry-run`, nunca automático.** `liaison-ops.sh cursors repair <canal> [--dry-run]` reaplica a regra do PR #105 sobre a história: para cada thread, o cursor avança até a mensagem de terceiro mais adiantada que este repositório ackou, por `advanceCursor` com `strict: false` — a mesma função, jamais uma segunda implementação da regra de não regressão, que é a classe de LDG-0014. O `--dry-run` imprime, por thread, quantas mensagens seriam marcadas e **quantas delas não foram ackadas**, que é a coluna de 152.

**Alternativa descartada — reparar automaticamente no `status` ou no `sync`.** Descartada por dois motivos, e o primeiro é o número acima: uma leitura que muta duzentas e tantas posições de estado durável sem o operador pedir (223 no dia da medição acima) é o oposto do que o harness faz em toda outra divergência (`conflicts resolve` é ato explícito, `--repair-own-log` é ato explícito e declarado por extenso). O segundo é de contrato: `status` é comando de leitura, e escrever nele faria com que o `SessionStart` — que roda `status` automaticamente nas quatro árvores — mutasse cursores sem ninguém ter digitado nada.

**Alternativa descartada — só documentar `read --upto` como reparo.** É o que a issue propõe. Descartada porque deixa o passivo medido acima sem detector nenhum — 71 itens em 34 threads no dia da medição —, e porque `read --upto` opera uma thread por vez: reparar dezenas de threads exigiria dezenas de invocações à mão, o que na prática significa não reparar.

### 5.2 Resíduo 2 — o avanço de cursor que falha em silêncio, reproduzido com controle e mutante

`liaison-ops.sh:738` é `} catch { /* o ack já está publicado; o cursor é conveniência, nunca desfaz a publicação */ }`. Bancada A de dois participantes, com a lib de cursor removida por `rm` e restaurada por cópia, com controle, mutante e **recontrole** — a mutação é em cópia de fixture, nunca no arquivo rastreado (LDG-0175):

```
alvo do ack: repo-a-0002
=== CONTROLE: lib de cursor PRESENTE ===
state antes : {"cursors":{}}
ack rc=0
OK ack — repo-b-0001 confirma repo-a-0002
state depois: { "cursors": { "t1": { "msg_id": "repo-a-0002", "read_at": "2026-09-07T21:25:05Z" } } }
=== MUTANTE: lib de cursor AUSENTE ===
ack rc=0
OK ack — repo-b-0002 confirma repo-a-0002
ocorrências de WARN na saída do ack: 0
state depois do ack sem a lib: {"cursors":{}}
read --upto rc=1
node:internal/modules/esm/resolve:271
    throw new ERR_MODULE_NOT_FOUND(
=== RECONTROLE ===
restauração por checksum: OK
ack rc=0
state depois do recontrole: { "cursors": { "t1": { "msg_id": "repo-a-0002", "read_at": "2026-09-07T21:25:11Z" } } }
```

A assimetria da issue #49 está medida: o mesmo estado produz `OK` com rc 0 e **zero ocorrências de WARN** num caminho, e stack cru com rc 1 no outro. O recontrole importa aqui mais do que o de costume, porque a mutação é a remoção de um arquivo e um `restore` que falhasse deixaria toda a bancada seguinte medindo o mutante — é `feedback-mutacao-fantasma-restore`.

**Decisão 17 — o `catch` continua não desfazendo o ack, e passa a IMPRIMIR.** A justificativa do comentário é correta e é preservada: o ack já foi gravado, e falhar ali transformaria um ato de protocolo em erro de uso. O que muda é que o `catch` passa a emitir, em stderr, uma linha `WARN` nomeando a thread, a mensagem alvo e o motivo da exceção, e o rc do `ack` continua 0. Colapsar sucesso e falha do cursor no mesmo silêncio é a invariante 2 do plano; imprimir sem reprovar é o que separa os dois sem quebrar o contrato do comando.

**Decisão 18 — a lib de cursor ausente é DELEGAÇÃO EM ALVO AUSENTE e reprova, no `read --upto`.** Hoje ela já reprova, mas com stack cru. O `read --upto` passa a recusar com mensagem nomeada, do jeito que `check-liaison-acks.sh:53-58` já faz para `lib/forge-root.sh` — o precedente existe no repositório e a regra é a mesma.

### 5.3 Resíduo 3 — o doctor emudece, reproduzido com controle, mutante e recontrole

`doctor.sh:231` é `liaison_line="$(FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/liaison-ops.sh" status 2>/dev/null || true)"` e a linha 232 testa `[ -n "$liaison_line" ]`. Remedido na **bancada D**, que é a fixture do `w112` reconstruída como `mk_repo` a monta, com `state.json` truncado para `{"cursors":` — e o ambiente importa, porque é sobre o ambiente do gate que a afirmação é feita:

```
state: {"cursors":{}}
CONTROLE    rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
     · harness: LIAISON: self=axis-go-cloud · 1 canal(is) · 0 thread(s) · 0 não lida(s) · 0 em quarentena
MUTANTE     rc=1  'harness: LIAISON:'=0  grep -qi liaison => NAO
RECONTROLE  rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
--- status isolado no estado mutante:
SyntaxError: Unexpected end of JSON input   (rc=1, stdout vazio)
```

**A revisão 1 afirmava aqui que `grep -qi "liaison"` devolve SIM nos três estados, e essa afirmação está REFUTADA pela medição acima.** Na fixture do `w112` ela devolve **NAO** no estado defeituoso: a única ocorrência da palavra na saída do doctor daquela fixture é a própria linha do bloco do liaison, e quando ela some, some a palavra. Ou seja, `w112[8]` **não** é cego ao defeito de #108 no ambiente em que ele roda — ele falharia, com a mensagem `FAIL [8]: doctor não reporta o liaison`.

**Onde o predicado é cego, medido.** A linha que empresta a palavra ao predicado é a de gates órfãos, e ela nasce em `doctor.sh:371`, **só** sob `core.hooksPath` customizado com encadeamento parcial — configuração que a fixture do `w112` não tem e que as árvores de campo têm. Reproduzido na bancada D com `git config core.hooksPath .githooks` e um hook que referencia só um gate:

```
--- com core.hooksPath customizado e encadeamento PARCIAL:
hooksPath-custom + state INVÁLIDO  rc=1  'harness: LIAISON:'=0  grep -qi liaison => SIM
     ! harness: core.hooksPath customizado com encadeamento PARCIAL — gates que ninguém invoca: … check-liaison-acks.sh check-liaison-log-integrity.sh …
hooksPath-custom + state ÍNTEGRO   rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
```

**Três leituras, e a segunda mudou de tamanho.** A primeira é o defeito da issue, e continua de pé: a linha do liaison desaparece por inteiro e o rc do doctor não muda — o operador perde o bloco e nada o avisa. A segunda é que `grep -qi "liaison"` é um predicado que **casa por vocabulário compartilhado**, e a cegueira dele é condicional, não estrutural: ela aparece exatamente quando o repositório tem `core.hooksPath` customizado, que é a configuração de campo, e some na fixture. A troca do predicado continua valendo — um predicado que só discrimina em algumas configurações do repositório sob teste não é um predicado, e a linha específica `harness: LIAISON:` discrimina em todas —, mas ela é **endurecimento**, não conserto de falso-verde, e a spec passa a dizer isso. A terceira é que o `2>/dev/null` joga fora a única informação acionável que existe, que é o erro de parse.

**Decisão 19 — o doctor distingue três estados e usa `info`, jamais `miss`.** Os três: canal não inicializado (silêncio, como hoje); `status` respondeu (a linha de hoje, inalterada); `status` reprovou (linha nova, nomeando o canal e a causa, com a primeira linha do stderr preservada). O marcador é `·` (`info`), nunca `✗` (`miss`), e isso é obrigação medida, não estilo: `w112[8]` afirma que não existe `✗.*[Ll]iaison` na saída e que o rc do doctor com liaison é igual ao sem, e `doctor.sh:197-199` declara em letra que o bloco do liaison é advisory e nunca load-bearing.

**Decisão 20 — o `2>/dev/null` sai, e o stderr do `status` é capturado para dentro da mensagem.** Sem isso, o terceiro estado diria "não consegui ler" sem dizer por quê, e o operador ficaria com um diagnóstico que não aponta para arquivo nenhum.

### 5.4 O VERMELHO, antes do verde

**`w195[12]` — `cursors repair --dry-run` relata o passivo e NÃO escreve.** Fixture com três mensagens de terceiro, ack da terceira, cursor parado antes da primeira. Asserções: a saída nomeia a thread, diz `3` marcadas e `2` não ackadas; `state.json` fica byte a byte idêntico. Os números `3` e `2` são da fixture, construídos por ela e fixos por construção — não contam nada da árvore. *Como falha hoje:* `liaison-ops.sh cursors` não existe e cai no `*)` do `case` principal (`liaison-ops.sh:1294-1296`), com `FAIL: comando desconhecido 'cursors'` — não em `_reject_unknown`, que é a guarda de flag desconhecida dentro de um subcomando.

**`w195[13]` — `cursors repair` move o cursor até a ackada mais adiantada, e é IDEMPOTENTE.** Segunda execução relata zero e deixa `state.json` byte a byte idêntico ao da primeira.

**`w195[14]` — `cursors repair` NUNCA regride.** Cursor já adiante da ackada mais adiantada: rc 0, nenhuma escrita, e o valor do cursor lido do `state.json` comparado com o esperado — pareado com o valor, nunca só "não regrediu", que é a disciplina que `w195[6]` já aplica.

**`wB2[8]` — `ack` com a lib de cursor ausente imprime `WARN` e continua saindo 0.** Asserções: rc 0; stdout ainda contém `OK ack`; stderr contém `WARN` nomeando a thread. *Como falha hoje:* a saída literal está em §5.2 — `ack rc=0`, `OK ack`, e **nada** em stderr. Falha pela ausência real: o `catch` da linha 738 tem corpo vazio, e `grep -c 'WARN' template/.forge/scripts/liaison-ops.sh` não devolve nenhuma ocorrência nesse bloco.

**`wB2[9]` — `read --upto` com a lib ausente recusa NOMEANDO a lib, sem stack cru.** *Como falha hoje:* o rc já é 1, mas a saída é `ERR_MODULE_NOT_FOUND` cru, medido em §5.2. A asserção positiva é o nome da lib na mensagem; a negativa é a ausência de `node:internal/modules`.

**`wB2[10]` — `state.json` inválido faz o doctor DIZER, sem `✗` e sem mudar o rc.** Asserções, todas positivas menos a última: a saída contém uma linha `·` que nomeia o canal e diz que o estado não pôde ser lido; a saída contém a causa vinda do stderr do `status`; a saída **não** contém `✗` na mesma linha; o rc é igual ao do mesmo doctor com o `state.json` íntegro. *Como falha hoje:* medido em §5.3 — a contagem de `harness: LIAISON:` cai de 1 para 0 e nenhuma linha substituta aparece.

**`w112[8]` — o predicado deixa de ser `grep -qi "liaison"` e passa a ser a linha específica `harness: LIAISON:`.** É endurecimento, e a spec diz em letra o que ele é e o que ele não é. *Como falha hoje:* **não falha** — medido em §5.3, na fixture do `w112` o predicado antigo já devolve NAO no estado defeituoso, então ele não é um falso-verde ali. O que a troca compra é que o predicado passe a discriminar **em qualquer configuração do repositório sob teste**, e não só nas que não têm `core.hooksPath` customizado; e que a asserção passe a dizer o que o nome dela promete, que é "o doctor reporta o bloco do liaison", em vez de "a palavra liaison aparece em algum lugar da saída". Por não haver vermelho de funcionalidade ausente aqui, a prova de que a troca vale é o **controle negativo**: rodar `w112[8]` com o predicado novo contra a fixture de estado inválido e observá-lo falhar, uma vez, antes de fechar a linha — que é o mesmo protocolo de §7.3.

### 5.5 Prova de mutação

| Mutação | Contrafactual que ela precisa produzir | Cenário que morde |
|---|---|---|
| M11 — `cursors repair` volta a mover o cursor sem consultar os acks (avança sempre até o fim) | `[14]` observa cursor além do esperado e falha; `[12]` relata número maior que o real | `w195[14]` |
| M12 — o `WARN` do `catch` do `ack` é removido | `[8]` deixa de ver a linha em stderr e falha; o rc continua 0, que é o ponto — a mutação tem de derrubar **só** a asserção de stderr | `wB2[8]` |
| M13 — o `2>/dev/null` volta ao `doctor.sh` na chamada do `status` | `[10]` deixa de encontrar a causa na saída e falha, enquanto a linha `·` continua presente | `wB2[10]` |
| M14 — a guarda de três estados do doctor volta a ser `[ -n "$liaison_line" ]` | `[10]` deixa de encontrar qualquer linha de liaison e falha, nomeando a ausência da linha `·` de estado ilegível | `wB2[10]` apenas — **medido** |

**A linha de M14 foi reescrita na revisão 2, e o contrafactual está medido.** A revisão 1 declarava que M14 derrubaria também `w112[8]` no predicado novo, "o que prova que a correção do predicado tem valor". Não derruba, e a mutação foi executada na bancada D com controle da própria mutação e recontrole para provar:

```
=== M14 (guarda revertida para [ -n "$liaison_line" ]) sobre fixture SAUDÁVEL ===
M14-ANTES (guarda de hoje)     rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
controle da mutação: o arquivo MUDOU (7540aff0… -> a0f73bff…)
M14-MUTADO (fixture saudável)  rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
restauração: OK
M14-RECONTROLE                 rc=1  'harness: LIAISON:'=1  grep -qi liaison => SIM
```

A razão é simples e a spec devia tê-la visto: `w112[8]` roda o doctor sobre uma fixture **saudável**, em que o `status` responde normalmente, e nessa fixture a guarda antiga e a nova concordam — as duas imprimem a linha. M14 só se manifesta no estado em que o `status` reprova, e o único cenário que monta esse estado é `wB2[10]`. A linha da matriz passa a nomear só ele, que é a saída que a invariante 16 pede: rodar a mutação, observar o efeito real, e só então declarar o que ela derruba.

---

## 6. ITEM 5 — LDG-0153: o doctor não informa divergência da maquinaria local

### 6.1 O que o item afirma, e o que a medição acrescenta

O item já corrige a si mesmo: a justificativa antiga ("não há referência local") é falsa, porque `.forge/cache/machinery.lock` grava o `sha256` do **template** por path (`bin/forge.mjs:361,384`) e `bin/forge.mjs:617-643` já computa exatamente essa comparação em `driftWarned`. A restrição real é que sem `machinery.lock` não há referência, e é nesse caso que a perda é totalmente muda.

Confirmei que não existe leitor: `grep -n 'machinery.lock' template/.forge/scripts/doctor.sh` devolve zero, e o único arquivo do repositório que a menciona fora de `bin/forge.mjs` é `tests/w101-update-preserve-gate.sh`.

**E medi o passivo, que é a parte que o item não tem.** Sobre as quatro árvores, com o comando colado — ele é também o esqueleto do que `lib/machinery-drift.mjs` vai fazer, e serve de referência para quem implementar:

```
$ for r in axis-fare-validator axis-go-cloud Axis.PadSimulator forge-harness; do node -e '
const fs=require("fs"),path=require("path"),{createHash}=require("crypto");
const root=process.argv[1], lock=path.join(root,".forge","cache","machinery.lock");
if(!fs.existsSync(lock)){console.log(`${path.basename(root)}: SEM machinery.lock`);process.exit(0);}
const ENRICH=["agents","rules","skills","templates"];
let n=0,aus=0,enr=0,maq=0,ver="?";
for(const line of fs.readFileSync(lock,"utf8").split("\n")){
  const t=line.trim(); if(!t)continue;
  if(t.startsWith("#")){const m=t.match(/v[0-9.]+/); if(m&&ver==="?")ver=m[0]; continue;}
  const m=t.match(/^([0-9a-f]{64})\s+(.+)$/); if(!m)continue; n++;
  const rel=m[2], p=path.join(root,".forge",rel);
  if(!fs.existsSync(p)){aus++;continue;}
  if(createHash("sha256").update(fs.readFileSync(p)).digest("hex")===m[1])continue;
  if(ENRICH.includes(rel.split("/")[0]))enr++; else maq++;
}
console.log(`${path.basename(root).padEnd(20)} lock ${ver}, ${n} entradas, ${aus} ausentes, ${enr} enriquecíveis divergentes, MAQUINARIA DIVERGENTE = ${maq}`);
' ~/Documents/projects/$r; done
axis-fare-validator  lock v0.14.0, 401 entradas, 0 ausentes, 4 enriquecíveis divergentes, MAQUINARIA DIVERGENTE = 34
axis-go-cloud        lock v0.14.0, 402 entradas, 3 ausentes, 12 enriquecíveis divergentes, MAQUINARIA DIVERGENTE = 28
Axis.PadSimulator    lock v0.11.0, 396 entradas, 0 ausentes, 3 enriquecíveis divergentes, MAQUINARIA DIVERGENTE = 41
forge-harness: SEM machinery.lock
```

Números de testemunha, como todos os outros: o que decide é que as três árvores com lock têm **dezenas** de arquivos de maquinaria divergentes e que a quarta não tem referência nenhuma — não os valores 34, 28 e 41, que mudam a cada `update` e a cada conserto local.

A separação entre as duas colunas é o desenho, não estatística: `ENRICHABLE_DIRS = ['agents','rules','skills','templates']` (`bin/forge.mjs:352`) é preservado pelo update por construção, então divergência ali é **customização legítima** e reportá-la seria ruído. Divergência nos demais é **fix local em maquinaria que o próximo `forge update` reverte**, hoje com um único `WARN` emitido durante o update, isto é, depois do fato.

**E o arquivo que o item nomeia é um caso real, agora, com conteúdo que importa.** O `lib/transports/_common.sh` de `axis-fare-validator` diverge do lock e do template:

```
axis-fare-validator: 6d51f13226064fab2d8d30cdb4622dfc089281b8b5215e9bce574ebe85fa6e80
axis-go-cloud:       50f684c86a57114a6ba46362e568109c7cf3ac8097709d936c683ca890744da5
Axis.PadSimulator:   68e4bb642238d1481e09801533b8a2542082dbba6cf2cac005801129da8fcd9c
template:            50f684c86a57114a6ba46362e568109c7cf3ac8097709d936c683ca890744da5
```

E o `diff` mostra o que está em risco: 268 linhas contra 239, com `_liaison_hub_hash` e um **compare-and-swap otimista** em `_dir_push_union` — "se o hub mudar entre a leitura que alimentou a união e o `mv` que a publica, o cálculo já está obsoleto" — mais sufixo por processo (`$$`) no temporário, contra o nome fixo do template. É o compare-and-swap que a memória do projeto registra em `axis-go-cloud-0085`. **Um `forge update` hoje apaga esse conserto sem que nada, antes do fato, avise que ele existe.**

### 6.2 Decisões de desenho — FECHADAS

**Decisão 21 — o check espelha o que o doctor JÁ FAZ para o lockfile de adapter, incluindo o terceiro estado.** `doctor.sh:137-161` lê `.forge/adapters/*.lock.yaml`, compara `sha256`, imprime `ok "… sem drift (lockfile íntegro)"` ou `miss "… com drift"`, e quando não encontra lockfile nenhum imprime `info "harness: nenhum lockfile de adapter"`. Os três estados já estão ali, para a outra referência. O harness sabe fazer isto para um lock e não faz para o outro, e essa assimetria é o item.

**Decisão 22 — a linha é `info`, nunca `miss`, e isso é obrigação medida.** `tests/npx-pack-gate.sh:134` exige que `doctor.sh --report` saia **0** depois de um `update` via tarball, e `miss` seta `MISSING_DIAG=1`, que leva o doctor a sair 1. `w112[8]` exige que o rc do doctor com liaison seja igual ao sem. Uma linha bloqueante quebraria os dois. Além disso a semântica está certa: drift de maquinaria é decisão do operador (fazer upstream o fix, ou aceitar que ele será revertido), não defeito do harness.

**Decisão 23 — três estados, e o terceiro é a restrição que o item nomeia.** (a) sem `machinery.lock` → `INCONCLUSIVO`, nomeando que a referência só nasce no primeiro `update`; (b) `node` ausente → `INCONCLUSIVO`, capacidade dura; (c) lock presente e legível → contagem, separada em maquinaria e enriquecível. O estado (a) é o de `forge-harness` hoje, medido, e é o que a Fase 1 do plano-mestre passa a resolver ao instalar a maquinaria na raiz.

**Decisão 24 — o cálculo vive em `lib/machinery-drift.mjs`, não em `bash`.** Motivo medido, com o comando colado e três repetições, porque a revisão 1 dava o intervalo sem o comando:

```
$ L=~/Documents/projects/axis-go-cloud/.forge/cache/machinery.lock
$ /usr/bin/time -p node -e '
const fs=require("fs"),path=require("path"),{createHash}=require("crypto");
const [lock,root]=process.argv.slice(1); let n=0,div=0,aus=0;
for(const line of fs.readFileSync(lock,"utf8").split("\n")){
  const t=line.trim(); if(!t||t.startsWith("#"))continue;
  const m=t.match(/^([0-9a-f]{64})\s+(.+)$/); if(!m)continue; n++;
  const p=path.join(root,m[2]);
  if(!fs.existsSync(p)){aus++;continue;}
  if(createHash("sha256").update(fs.readFileSync(p)).digest("hex")!==m[1])div++;
}
console.error(`entradas=${n} ausentes=${aus} divergentes=${div}`);' "$L" ~/Documents/projects/axis-go-cloud/.forge
entradas=402 ausentes=3 divergentes=40 real 2,87 user 0,10 sys 0,06
entradas=402 ausentes=3 divergentes=40 real 1,19 user 0,09 sys 0,04
entradas=402 ausentes=3 divergentes=40 real 1,58 user 0,09 sys 0,04

$ for i in 1 2 3; do /usr/bin/time -p node -e '0'; done
real 0,52 …   real 0,47 …   real 0,53 …
```

**1,2 a 2,9 s de relógio** para as 402 entradas num processo `node` só, contra **0,47 a 0,53 s** só para subir o `node` — a revisão 1 dizia `1,3-1,6 s` e `0,22 s`, e nenhum dos dois sobreviveu à repetição numa máquina com a suíte de baseline rodando ao lado. O que decide continua de pé e fica mais claro com a dispersão: quase metade do custo do caso pequeno é **partida de processo**, então a alternativa em shell — 402 invocações de `shasum`, cada uma com a sua partida — é uma ordem de grandeza pior por construção, e não por medição de sorte. Em fixture o custo é nulo, porque fixture sem `update` não tem lock e o check sai no estado (a) antes de abrir arquivo nenhum.

**Decisão 25 — a lista completa não vai para a tela.** O doctor imprime a linha de resumo e, no máximo, os dez primeiros paths em ordem, com o comando que lista todos. Quarenta e uma linhas de `·` num doctor é ruído que ensina o operador a ignorar o doctor, que é o dano que o comentário de `doctor.sh:197-199` já nomeia para o liaison. O corte de dez é limite de exibição, não asserção, e não envelhece.

**Decisão 26 — a comparação é local, e a peça cross-repositório continua fora.** O item já registra que o harness não enxerga a árvore do consumidor. Esta onda entrega o check local, que é o que o item diz ser viável, e não tenta a peça que ele diz não ser.

### 6.3 O VERMELHO, antes do verde

**`wB2[11]` — lock fabricado, um arquivo de maquinaria editado: o doctor NOMEIA o path.** Fixture com `.forge/cache/machinery.lock` escrito à mão a partir dos `sha256` reais do template, depois um byte alterado em `scripts/lib/transports/_common.sh`. Asserções: a saída contém `·` com o path; o rc do doctor é igual ao da mesma fixture sem a edição. *Como falha hoje:* nenhuma linha do doctor lê o lock (`grep -n 'machinery.lock' template/.forge/scripts/doctor.sh` → zero), então a saída não menciona nem o path nem o lock.

**`wB2[12]` — arquivo ENRIQUECÍVEL editado NÃO entra na contagem de maquinaria.** A mesma fixture, com a edição em `rules/README.md` em vez de em `scripts/`. Asserção: a contagem de maquinaria é zero e a linha, se existir, classifica a divergência como customização. É o cenário que impede a onda de entregar um check que grita 38 vezes em `axis-fare-validator` sobre customização legítima.

**`wB2[13]` — sem `machinery.lock`, o doctor diz `INCONCLUSIVO` e não afirma "sem drift".** É o estado de `forge-harness` hoje. Asserções: a saída contém `INCONCLUSIVO` nomeando o lock ausente; a saída **não** contém uma afirmação de integridade da maquinaria. *Como falha hoje:* não há linha nenhuma, e "nenhuma linha" é indistinguível de "está tudo certo" — que é a invariante 2 do plano.

**`npx-pack-gate[6]` — o canal REAL, e é o que `gate-delivery-channel.md` exige.** O cenário já paga `npm pack`, `init` e `update` via tarball. Ganha, depois do `update`: (a) o doctor afirma que a maquinaria está íntegra contra o `machinery.lock` e sai 0; (b) um byte é alterado em `.forge/scripts/doctor.sh` do projeto instalado; (c) o doctor **do próprio projeto instalado** nomeia o path; (d) o rc continua 0. Sem (a) e (d) a asserção não distingue "o check funciona" de "o check reprova sempre", e (d) é a que protege a linha 134 do próprio gate.

**E a asserção (a) obriga a ESTREITAR um predicado existente, no mesmo change — é a invariante 15, e a revisão 1 a perdeu.** `npx-pack-gate.sh:135` é hoje `grep -qi 'sem drift' "$T/upd-doctor.log"`, e ele discrimina a linha `ok "harness: adapter $aname sem drift (lockfile íntegro)"` porque `grep -n 'sem drift' template/.forge/scripts/doctor.sh` devolve **exatamente uma** ocorrência, a linha 156. Se a linha nova da maquinaria também disser "sem drift", a linha 135 passa a casar as duas e deixa de provar qualquer coisa sobre o lockfile de **adapter**: a verificação de adapter poderia regredir por inteiro e o gate continuaria verde pela linha da maquinaria. Isso é o falso-verde por vocabulário compartilhado — a mesma classe de §5.3 e o item 3 de §14 —, introduzido dentro da onda que existe para combatê-la. Duas correções, e as duas entram na definição de pronto: a linha 135 é **estreitada** para casar nominalmente a linha do adapter (`harness: adapter .* sem drift`), e a linha nova da maquinaria usa vocabulário **próprio**, que não colide com o do adapter nem com o do grafo.

### 6.4 Prova de mutação e PBT

| Mutação | Contrafactual que ela precisa produzir | Cenário que morde |
|---|---|---|
| M15 — `machinery-drift.mjs` passa a comparar apenas a existência do arquivo, não o `sha256` | `[11]` deixa de nomear o path editado e falha | `wB2[11]` |
| M16 — a separação enriquecível/maquinaria é removida | `[12]` passa a ver `rules/README.md` na contagem de maquinaria e falha | `wB2[12]` |
| M17 — lock ausente passa a ser tratado como "sem drift" | `[13]` deixa de ver `INCONCLUSIVO` e falha | `wB2[13]` |

**PBT sobre o parser do lock.** O formato é `"<sha256>  <rel>"` por linha, com comentários `#` e linhas em branco, e `bin/forge.mjs:363-373` já conta as ilegíveis. Propriedades sobre entrada gerada: (i) `parse(render(map))` devolve `map`, para paths com espaço, com acento e com `..` no meio do nome; (ii) linha ilegível é **contada**, nunca descartada em silêncio, e a presença de ilegíveis nunca produz o veredito "sem drift"; (iii) entrada vazia produz `INCONCLUSIVO`, jamais zero divergências. A terceira é a que fecha a porta do falso verde: um lock truncado a zero bytes existe no disco e não é referência nenhuma.

---

## 7. ITEM 6 — LDG-0163: fechar por prova, não por código

### 7.1 O que o item afirma, e a prova que ele pede

O caminho `ff` de `_dir_push` publicava, por `cp`/`mv`, um log próprio contaminado com mensagem de terceiro, com rc 0. O item registra que o defeito **já foi resolvido** no mesmo commit que trouxe a união, e pede a prova de que o caminho atual recusa, com o cenário do `w198`.

Executei o cenário e instrumentei o galho, porque "o push recusou" não prova que o galho exercitado foi o `ff`:

```
--- classificação: verdict='ff' rc=0  (0=ff, 1=behind, 2=diverged)
--- push rc=1
FAIL liaison-push-union: log local linha 3 tem sender="repo-b", esperado "repo-a" — o log próprio não pode conter mensagem de terceiro; nada foi publicado
FAIL: push pelo transporte fs
--- hub INTACTO byte a byte
--- rc do módulo isolado: 4
```

Os quatro fatos são os quatro que o item pede: o galho é o `ff`, a recusa acontece, ela nomeia a linha e o remetente inesperado, e o hub não muda.

### 7.2 A prova de mutação, EXECUTADA

Mutei `lib/liaison-push-union.mjs` numa cópia de fixture, trocando a guarda `if (m.sender !== self) {` por `if (false) {`, por substituição integral a partir de cópia preparada — nunca `perl -0pi` com `$` do lado direito. Reexecutada na revisão 2, com o hub reposto ao estado pré-mutação antes do recontrole:

```
log próprio de repo-a: 3 linhas; senders = repo-a,repo-b
--- classificação do galho (0=ff, 1=behind, 2=diverged):
verdict='ff' rc=0
=== CONTROLE (guarda intacta): push ===
push rc=1
FAIL liaison-push-union: log local linha 3 tem sender="repo-b", esperado "repo-a" — o log próprio não pode conter mensagem de terceiro; nada foi publicado
hub: 2 linha(s); senders = repo-a
=== MUTAÇÃO: sender !== self -> false ===
controle da mutação: o arquivo MUDOU (82f60ea2… -> 317c6051…)
push rc=0
OK liaison-push-union: hub=2 local=3 união=3
OK sync — push-only via fs (log de repo-a publicado)
hub: 3 linha(s); senders = repo-a,repo-b
=== RESTAURAÇÃO E RECONTROLE (hub reposto ao estado pré-mutação) ===
restauração por checksum: OK
push rc=1
FAIL liaison-push-union: log local linha 2 tem sender="repo-b", esperado "repo-a" — …
```

O estado mutado é **exatamente** o defeito descrito em LDG-0163: rc 0, log contaminado publicado, hub com a mensagem alheia dentro do arquivo do dono. A restauração bateu por checksum e o recontrole voltou a recusar.

**Duas lições de bancada que só apareceram por reexecutar, e as duas viram obrigação para quem implementa.** A primeira: na execução da revisão 1 o recontrole rodou **sem repor o hub**, e a recusa que ele observou nomeava a linha do **hub**, não a do log local — isto é, o recontrole passou por acidente, medindo uma recusa de causa diferente da do controle. Recontrole depois de mutação que escreve em estado compartilhado exige repor o estado compartilhado, não só o arquivo mutado; senão a prova de retorno ao verde é sobre outro cenário. A segunda: o índice da linha citada na mensagem **mudou de 3 para 2** entre o controle e o recontrole, porque a união do push mutado reordenou o log próprio por `seq` e a linha contaminada trocou de posição — verificado depois, lendo o arquivo. Logo a asserção do gate afirma **o `sender` nomeado**, jamais o número da linha, que não é estável entre execuções.

### 7.3 O que muda no código: nada. O que muda no gate: duas asserções

`w198[5]` hoje afirma `rc5 -ne 0` e `cmp` do hub. Ele não afirma o galho nem a causa, então um dia em que a recusa passasse a vir de `behind` ou de `diverged` ele continuaria verde sobre um cenário que deixou de exercitar o `ff`.

**`w198[5]` ganha duas asserções:** (a) `_dir_push_classify` sobre a mesma fixture devolve `ff` com rc 0, verificado antes do push — medido em §7.2, `verdict='ff' rc=0`; (b) a saída da recusa nomeia o `sender` inesperado, **e nada além dele** — nem o índice da linha, pelo motivo medido no fim de §7.2. E **`w198[7]` ganha uma linha de matriz**: a mutação de §7.2, com o contrafactual medido — hub contaminado e rc 0.

*Como falha hoje:* a asserção (a) não existe, e sem ela `[5]` é um cenário cuja pré-condição não é verificada. Não é vermelho por ausência de funcionalidade — a funcionalidade existe e funciona —, e **isto é dito em letra**: LDG-0163 é o único item da onda que não tem vermelho de funcionalidade ausente, porque ele fecha por evidência. A invariante 1 do plano exige vermelho por ausência real; aqui o que está ausente é a **asserção**, e o vermelho correspondente é `[5]` reprovando quando a asserção (a) é introduzida contra uma fixture que não exercite o `ff` — que é o controle negativo que o implementador deve rodar uma vez, para provar que a asserção discrimina, antes de dar a linha por fechada.

### 7.4 Uma nota de bancada, medida, para quem for escrever o gate

Ao instrumentar `_dir_push_classify` fora de um repositório-fixture, sourceando `_common.sh` diretamente do `template/`, a resolução de `libdir` em `_dir_push_union` — que é `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)` — devolveu um caminho **errado** nesta máquina, e o push reprovou com "a união do log exige node e '<caminho errado>'". Sourceando a cópia dentro da fixture, via `bash -c`, resolveu certo. Não investiguei a causa e **não afirmo que há defeito em `_common.sh`**; registro porque a bancada precisa sourcear a cópia da fixture, exatamente como `w198[7]` já faz, e porque um implementador que sourceie o template direto vai perder tempo com um sintoma que não é o do item.

---

## 8. Onde entram PBT, contrato, integração e E2E

| Nível | Onde entra nesta onda | Justificativa |
|---|---|---|
| **PBT** | nome de blob (§2.7, três propriedades), comparador de publicação (§4.5, quatro propriedades), parser do `machinery.lock` (§6.4, três propriedades) | Os três são serializador ou parser sobre espaço de entrada aberto — a definição da invariante 5. `lib/pbt.mjs` já existe, e os consumidores a copiar são `w121-pbt-harness-gate.sh`, `w130-tasks-graph-gate.sh` e `w132-route-surface-gate.sh` — medido por `grep -rln 'pbt.mjs' tests/`. A revisão 1 dizia que era `w169`, e não é: aquele gate traz gerador próprio. |
| **Contrato** | `body_ref` versionado aceito por `validateEnvelope` **e** por `ajv` sobre `liaison-message.schema.json`, nos dois sentidos | É a fronteira publicada com adotante instalado. A medição de §2.9 diz que o schema **não muda** — a asserção existe para que ele continue não mudando, e para que ninguém "melhore" o `pattern` restringindo-o a 64 hex. |
| **Contrato (2)** | `state.json` com `published` continua legível pelos dois leitores de hoje (`advanceCursor` e `status`), e `advanceCursor` PRESERVA a chave | `state.json` não tem schema e não é lido por ferramenta de adotante, mas é lido por duas funções deste repositório, e a preservação de chave desconhecida é o que torna o campo retrocompatível. |
| **Integração** | #107 e #109 exercitam `sync` de verdade contra hub `fs` de verdade; #108-3 e LDG-0153 invocam `doctor.sh` de verdade | Os quatro são defeitos de **fiação**, não de função: `applyBundle` chamado por unidade nasceria verde em #107, porque a função faz o que o laço manda. É a invariante 7. |
| **E2E** | `npx-pack-gate[6]`, que já paga `npm pack` + `init` + `update` via tarball, ganha a asserção de drift de maquinaria | É o único ponto do repositório onde existe um `machinery.lock` produzido pelo caminho real. Fabricar o lock em fixture prova a lógica; só este cenário prova o **canal**, que é o que `gate-delivery-channel.md` exige. |
| **Não se aplica** | teste de contrato sobre `forge.schema.json` | Medido: nenhuma chave de `forge.yaml` é lida ou escrita por esta onda. `grep -n 'liaison' template/.forge/schemas/forge.schema.json` cobre apenas `liaison.auto` e `liaison.enforce`, e nenhum dos dois muda. |
| **Não se aplica** | benchmark de performance | O único custo novo mensurável é o do `blobs verify` (8 a 13 s de relógio sobre 922 blobs, com o comando e as três repetições em §2.4) e o do drift (1,2 a 2,9 s sobre 402 entradas, idem em §6.2), e os dois estão em caminho deliberado do operador, não em hook. As duas medições foram feitas com a suíte de baseline rodando ao lado, o que as torna teto pessimista e não piso otimista. |

---

## 9. Retrocompatibilidade consolidada — o que está instalado e o que quebra

| Superfície | O que está instalado | O que esta onda faz | Quebra? |
|---|---|---|---|
| `BODY_REF_RE` e `pattern` do schema | idênticos nos três consumidores, incluindo o de `0.11.0` (medido, §2.9) | nada — o nome versionado já casa | não |
| Acervo de blobs sob nome legado | 1084 referenciados, 3477 arquivos rastreados em git nas quatro árvores (medido, §2.4) | nada — ficam como estão, e `blobNameLegacy` os verifica para sempre | não |
| `content_sha` das mensagens publicadas | 2267 distintas em quatro repositórios (medido, §2.4) | nada — nenhuma mensagem é reescrita | não |
| `state.json` das nove combinações de campo | só `cursors`, em 9 de 9 (medido, §4.1) | ganha `published` no primeiro `sync` depois do upgrade; até lá, silêncio (Decisão 11) | não |
| Cursores de campo | 71 mensagens ackadas e não lidas (medido, §5.1) | nada automático; o reparo é ato explícito com `--dry-run` (Decisão 16) | não |
| Maquinaria divergente em campo | 34, 28 e 41 arquivos nas três árvores com lock (medido, §6.1) | passa a ser **informada** pelo doctor, sem bloquear (Decisão 22) | não, mas fica visível — que é o ponto |
| `npx-pack-gate.sh:135`, `grep -qi 'sem drift'` | discrimina hoje a linha do lockfile de adapter, única com esse vocabulário (medido, §6.3) | é **estreitada** para casar nominalmente a linha do adapter, junto com a asserção nova | não — mas sem o estreitamento a asserção antiga deixa de provar o que provava |
| `_apply_bundle`, linha de resultado | asserções por substring em `w110[7]`, `w110[8a]`, `w110[11a]`, `w111[9a]`, `w111[9b]` | acrescenta sufixo condicional, só quando maior que zero (Decisão 6) | não |
| `plugin/forge/commands/liaison.md` | espelho commitado, conferido por `diff -r` em `plugin-sync-gate[1]` | regenerado por `npm run build:plugin` no mesmo change em que `commands/harness/liaison.md` muda | não — **se regenerado**; sem isso o gate fica vermelho |
| `README.md` — badge `gates-N` e linha `scripts/ (N)` | conferidos contra a árvore por `w200[6]` e `w200[1]` | os dois números mudam nesta onda e são atualizados nela (§10) | não — **se atualizados**; sem isso os dois cenários ficam vermelhos |
| Linha `LIAISON:` do `status` | comparação de igualdade exata em `doctor.sh:232` e `on-session-start.sh:45`, contra `"LIAISON: não inicializado"` | acrescenta sufixos condicionais à linha **inicializada**; a string do caso não inicializado não muda | não |

**O único consumidor que fica em estado desconhecido é `Axis.PadSimulator`**, em `0.11.0`: ele recebe o nome novo (medido) e não tem o verificador nem os contadores até atualizar. Isso é atraso de funcionalidade, não quebra.

---

## 10. O que esta onda edita fora dos gates novos — gates, README e espelho do plugin (invariante 15)

Varredura executada antes de propor qualquer mudança de string. Nenhuma string de produção que algum gate afirme é **removida** por esta onda; três são **acrescentadas de** condição, dois predicados são **estreitados**, e dois artefatos derivados precisam ser regenerados no mesmo change. A lista é nominal e entra na definição de pronto.

| Gate / arquivo | Cenário | O que muda | Por quê |
|---|---|---|---|
| `tests/w110-liaison-core-gate.sh` | `[6]` | fixture ganha byte acima de `0x7F`; a asserção do nome passa a exigir `^blobs/sha256-<sha>-`; nasce `[6b]`, controle ASCII | é o vermelho de #117 (§2.5), e o gate está verde por acidente de fixture (§2.3) |
| `tests/w112-liaison-session-gate.sh` | `[8]` | o predicado `grep -qi "liaison"` passa a ser a linha específica `harness: LIAISON:` | endurecimento: medido, o predicado atual casa por vocabulário compartilhado e só é cego sob `core.hooksPath` customizado (§5.3) |
| `tests/w198-liaison-push-union-gate.sh` | `[5]`, `[7]` | `[5]` ganha a asserção do galho `ff` e do `sender` nomeado; `[7]` ganha a linha de matriz de §7.2 | é a prova que fecha LDG-0163 (§7.3) |
| `tests/w195-liaison-monotonicity-gate.sh` | novos `[12]`, `[13]`, `[14]` | cenários de `cursors repair` | é onde a fixture de cursor já existe (§5.4) |
| `tests/npx-pack-gate.sh` | `[6]` e a **linha 135** | quatro asserções de drift de maquinaria depois do `update`; e a linha 135 é **estreitada** para casar nominalmente `harness: adapter .* sem drift` | é o único canal real com `machinery.lock` produzido pelo caminho real (§6.3), e sem o estreitamento a asserção antiga deixa de provar o lockfile de adapter |
| `tests/plugin-sync-gate.sh` | `[1]` | nenhuma edição no gate; o que muda é o **artefato** que ele confere — `plugin/forge/commands/liaison.md`, regenerado por `npm run build:plugin` e commitado | `plugin-sync-gate.sh:19-26` regenera `plugin/forge` de `template/.forge/commands` e exige `diff -r` limpo; §2.9 edita `commands/harness/liaison.md`, logo o espelho sai de sincronia |
| `tests/w200-readme-inventory-gate.sh` | `[6]` e `[1]` | nenhuma edição no gate; o que muda é o **README.md** — o badge `gates-N` e a linha `scripts/ (N)` do bloco `## 📁 Estrutura` | os dois números são conferidos contra a árvore, e esta onda muda a árvore dos dois lados |

**A armadilha do literal que envelhece na própria onda, nominal e medida.** `w200[6]` (linhas 260-272) exige que o badge do README case com `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`; hoje `grep -oE 'gates-[0-9]+' README.md` devolve `gates-131` e a contagem da árvore devolve `131`, os dois em paridade. Os **dois gates novos** de §13 levam a árvore a 133 com o badge parado, e o cenário reprova com "o badge do README diz 131 gate(s) e a árvore tem 133". `w200[1]` confere cada linha `<dir>/ (N)` contra `find template/.forge/<dir> -type f ! -name 'README.md' | wc -l`; hoje o README declara `scripts/ (136)` e a árvore tem `136`, e o arquivo novo `lib/machinery-drift.mjs` da Decisão 24 a leva a 137. **Nenhum outro `<dir>/ (N)` do bloco muda**: esta onda não acrescenta arquivo a `agents/`, `commands/`, `contracts/`, `skills/`, `rules/` nem `schemas/` — edita `commands/harness/liaison.md`, que já existe. E os números 133 e 137 **não entram nesta especificação como asserção**: quem implementa recalcula pelos dois comandos acima no momento da entrega e escreve o resultado no README, e quem confere é o `w200`. É a invariante 14, e é a armadilha que duas ondas deste lote já pisaram.

**Varredura das strings, executada.** `grep -rn 'não lida(s)\|em quarentena\|LIAISON:' tests/ template/` devolve as asserções de `w110[8a]`, `w110[8b]`, `w111[9a]`, `w111[9b]`, `w140[7]` e as duas comparações exatas de `doctor.sh:232` e `on-session-start.sh:45`; todas são `grep` de substring sobre trechos que esta onda **não** altera, ou comparação com a string do canal não inicializado, que não muda. `grep -rn 'nova(s)\|duplicata\|OK sync\|push-only' tests/*.sh` devolve `w110[11a]`, `w111[6]`, `w198[2]`, `w198[4]`, `w198[5]`, todas por substring. `grep -n 'sem drift' template/.forge/scripts/doctor.sh` devolve **uma** ocorrência, a linha 156 do adapter — e é por isso que a linha nova da maquinaria precisa de vocabulário próprio e a linha 135 do `npx-pack-gate` precisa ser estreitada, as duas coisas juntas (§6.3).

**A varredura do `OK ack`, que a revisão 1 não fez e que a Decisão 17 obriga.** O `WARN` novo do `catch` do `ack` acrescenta linha à saída do comando, e `grep -rn 'OK ack' tests/*.sh` devolve três asserções: `w166[6]` e `w166[7]`, por substring sobre a saída (a `[6]` sem merge de stderr, a `[7]` também), e `w201[P3]:306`, que **funde stderr** (`2>&1`) e usa `grep -q "^OK ack"` com âncora de início de linha. Nenhuma das três quebra, e a razão é dupla: o `WARN` vai para **stderr** e em linha própria, então a âncora `^` de `w201` continua casando a linha do `OK ack`; e o `WARN` só é emitido quando o avanço de cursor lança, estado que nenhuma das três fixturas produz. As três entram nesta lista porque a invariante 15 pede a lista nominal, não porque exijam edição — e porque, se alguém mais tarde mover o `WARN` para stdout **na mesma linha**, é `w201[P3]` que morde primeiro, e é bom que o próximo leitor saiba disso sem refazer a varredura.

---

## 11. O que a Onda B explicitamente NÃO faz

1. **Não renomeia o acervo de blobs**, e §2.4 refuta a alternativa com a medição de `content_sha`.
2. **Não altera `sha256Hex`**, que calcula o `content_sha` de todas as mensagens publicadas (2267 distintas na medição de §2.4).
3. **Não altera o schema `liaison-message.schema.json`**, nem acrescenta campo ao envelope — §2.4 mede por que um campo novo reprovaria nos três validadores instalados.
4. **Não toca `check-liaison-acks.sh` nem `check-liaison-log-integrity.sh`**, que estão no escopo da Onda D (itens 7 e 8 do censo dela). Duas ondas no mesmo arquivo é colisão programada.
5. **Não publica automaticamente depois do `send`**, nem lê o hub de dentro do `send` — a issue #109 recusa as duas, e a obrigação 5 da rule `liaison-protocol.md` não está em disputa.
6. **Não repara cursores automaticamente** — §5.1 mede 152 mensagens nunca ackadas que um reparo automático marcaria como lidas.
7. **Não corrige o `return 0` que engole a falha de `_dir_push_blobs`** (§4.2, Decisão 10). Medido nesta rodada, item novo de ledger (§14).
8. **Não implementa a peça cross-repositório de LDG-0153**, que o próprio item declara fora de alcance.
9. **Não bloqueia nada**: todas as linhas novas do doctor são `info`, e §6.2 mede por que uma linha bloqueante quebraria `npx-pack-gate[6]` e `w112[8]`.
10. **Não mede recall nem falso positivo do `blobs verify` sobre corpus real**, porque o corpus real tem `nenhum=0` e `bate_formula_gerador == nomes_distintos` (§2.2), isto é, zero divergentes e nenhum caso ambíguo — não há amostra positiva em campo, e a discriminação é provada em bancada.

---

## 12. Ordem de execução e definição de pronto

**Ordem, e cada passo tem uma razão de estar onde está.**

1. **`w110[6]` primeiro**, com a fixture acentuada, para observar o vermelho de #117 **antes** de qualquer implementação. É o vermelho mais barato da onda e o único que já tem asserção escrita.
2. `blobName`/`blobNameLegacy` em `liaison-merge.mjs`, com PBT, e `_write_body_blob` passando a usá-los. `w110[6]` fica verde.
3. `blobs verify` e `wB1[1]`-`[7]`.
4. A passada de reconciliação de blob em `liaison-import.mjs`, com o contador; `wB1[8]`-`[11]`.
5. A marca d'água no `sync` e o comparador no `status`; `wB2[1]`-`[7]`. **Antes** dos itens de cursor, porque os dois escrevem em `state.json` e é melhor que o segundo já encontre o primeiro no lugar.
6. `cursors repair`, o `WARN` do `ack` e a recusa nomeada do `read --upto`; `w195[12]`-`[14]`, `wB2[8]`-`[9]`.
7. O terceiro estado do doctor para o liaison, e a correção do predicado de `w112[8]`; `wB2[10]`.
8. `machinery-drift.mjs` e a linha do doctor; `wB2[11]`-`[13]` e as asserções de `npx-pack-gate[6]`.
9. As duas asserções de `w198[5]` e a linha de matriz de `w198[7]`, que fecham LDG-0163.
10. Provas de mutação M1-M17, cada uma com controle da própria mutação, restauração por checksum e **recontrole verde**.
11. `bash -n` limpo em tudo que for tocado; `bash` 3.2, sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray`.

**Definição de pronto.**

- Os seis itens fechados: #117, #107, #109 e #108 por `resolved` com gate que morde; LDG-0153 por `resolved` com gate que morde; LDG-0163 por `resolved` com a evidência de §7 registrada no ledger.
- Os cinco gates editados de §10 verdes, e os dois novos verdes.
- **`README.md` atualizado nos dois números que esta onda envelhece**, e cada um recalculado pelo comando no momento da entrega, nunca copiado desta especificação: o badge, por `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`, e a linha `scripts/ (N)` do bloco `## 📁 Estrutura`, por `find template/.forge/scripts -type f ! -name 'README.md' | wc -l`. Confirmado por `w200[6]` e `w200[1]` verdes.
- **`npm run build:plugin` rodado e `plugin/forge/commands/liaison.md` commitado no mesmo change** em que `template/.forge/commands/harness/liaison.md` muda — nunca `build-plugin.sh`, que instala em `$HOME`. Confirmado por `plugin-sync-gate[1]` verde.
- **`npx-pack-gate.sh:135` estreitado** para casar nominalmente a linha do adapter, no mesmo commit em que a asserção (a) de `npx-pack-gate[6]` entra — as duas juntas, porque só a segunda sem a primeira converte uma asserção existente em falso-verde (§6.3).
- A suíte inteira verde, rodada pelo **orquestrador**, serializada — nunca pelo implementador em paralelo com outra frente (`feedback-suite-sem-concorrencia`).
- As dezessete mutações executadas, com o contrafactual **observado** e não declarado, e com recontrole.
- `git status` limpo em `template/`: nenhum arquivo rastreado deixado mutado por gate, que é LDG-0175.
- `CHANGELOG.md` com as seis entradas, e as três mensagens de liaison de ack para as threads que pediram estes consertos, **depois** do merge, para que o ack carregue a entrega e não uma promessa (Onda I do plano).

---

## 13. Alocação de ordinal

Os dois gates novos recebem ordinal do **orquestrador**, uma vez, no momento de escrever o arquivo, conferido contra `origin/*` **e** contra as branches em voo desta rodada. É a invariante 10 do plano e o defeito de LDG-0167/0173. Medido nesta rodada, `gate-ordinal.sh next --path <raiz>` devolve `w208`, "derivado do tronco remoto 'origin/develop' (máximo remoto w207) e da árvore local (máximo local w0)" — **e esse número não pode ser usado por esta especificação**, porque outras ondas desta mesma rodada escrevem gates em paralelo e o `next` de hoje lê só o tronco. Nesta especificação os gates são `wB1` e `wB2`, e a substituição é do orquestrador.

**E ela é pré-requisito de o arquivo existir, não passo posterior.** `wB1` e `wB2` são marcadores de redação e **não podem chegar ao disco com esses nomes**: `tests/w193-tree-derived-state-gate.sh` roda `gate-ordinal.sh check --path <tests>` sobre a própria árvore, e a suíte é descoberta por glob `tests/*-gate.sh` em `run-all.sh` — um arquivo chamado `wB1-…-gate.sh` entraria na suíte com um ordinal que o alocador não reconhece. A ordem correta é: o orquestrador aloca o ordinal, e só então o arquivo nasce com o nome definitivo.

---

## 14. Achados fora do escopo, registrados para não sumir

1. **`_dir_push` devolve 0 com o log publicado e zero blobs no hub quando a cópia de blob falha.** Medido em §4.2, e o achado é maior do que a revisão 1 dizia: o `return 0` incondicional que descarta o rc de `_dir_push_blobs` está nos **dois** ramos de união — o `0)` (`ff`, `_common.sh:152-157`) e o `1)` (réplica atrasada, `_common.sh:166-172`) —, e não só no primeiro. O ramo de reparo declarado, em `_common.sh:209-217`, tem uma cópia inline do mesmo laço que **propaga** o rc; as duas metades do mesmo arquivo discordam. Item novo de ledger, P2, `known-bug`, com a reprodução colada e os dois ramos nomeados.
2. **`w110[6]` era um gate verde por propriedade da fixture, não do código.** Esta onda o corrige, mas a classe merece varredura própria: quantos outros gates da suíte usam `/dev/urandom | base64` ou fixture ASCII onde o alvo é sensível a bytes altos. Item novo de ledger, P3.
3. **`grep -qi "liaison"` de `w112[8]` casa por vocabulário compartilhado, e a cegueira é CONDICIONAL.** Medido em §5.3, com as duas metades: na fixture do `w112` o predicado antigo **cai para NAO** no estado defeituoso, então ali ele não é falso-verde; sob `core.hooksPath` customizado com encadeamento parcial ele devolve SIM nos dois estados, porque a linha de gates órfãos nomeia `check-liaison-acks.sh`. Esta onda troca o predicado por endurecimento, não por conserto. A classe — predicado de gate cuja discriminação depende da **configuração do repositório sob teste**, e não do código sob teste — é a mesma de `w197[6]`, que já a resolveu para `phase:`, e ela é pior do que "predicado frouxo": um gate assim é verde na bancada e cego no campo. Item novo de ledger, P3, para varrer os demais `grep -qi` de uma palavra só em `tests/`, com o critério explícito de procurar **onde a palavra aparece por outro caminho**.
4. **O passivo de 34, 28 e 41 arquivos de maquinaria divergente nos três consumidores** não é resolvido por esta onda: ela o torna visível. A reconciliação — fazer upstream o compare-and-swap de `axis-fare-validator`, decidir sobre os demais — é trabalho de campo e pertence à Onda I e à issue #101, na Onda C.
5. **A saída de recusa de `liaison-push-union` cita o índice da linha, e o índice não é estável.** Medido em §7.2: a união do push reordena o log próprio por `seq`, e a mesma mensagem contaminada foi nomeada como "linha 3" antes e "linha 2" depois. A mensagem continua útil para o humano; o que não pode é gate nenhum asseverar o número. Item novo de ledger, P3, para varrer `tests/` atrás de asserção sobre índice de linha em saída de produção.

---

## 15. Respostas ao veredito da revisão 1

Sete bloqueadores, onze afirmações numéricas não reproduzidas e seis ressalvas de redação. Remedi cada afirmação do revisor com comando meu antes de aceitá-la — o veredito não é autoridade, é hipótese com evidência —, e **os sete aceites abaixo são aceites porque a minha própria medição confirmou**, não porque vieram no veredito. Refutação nenhuma sobrou: desta rodada o revisor acertou em tudo o que afirmou como fato, e em dois pontos onde ele ofereceu duas saídas eu escolhi uma delas e digo por quê — o bloqueador 3, em que preservo o conflito da passada 1, e o bloqueador 5, em que não dou a `w112[8]` um segundo estado.

### 15.1 Bloqueadores

**Bloqueador 1 — literal do README que a onda envelhece. ACEITO, remedido em §10 e §12.** Confirmei os dois lados: `grep -oE 'gates-[0-9]+' README.md` → `gates-131` e `find tests -maxdepth 1 -name '*-gate.sh' | wc -l` → `131`; `README.md:235` declara `scripts/ (136)` e `find template/.forge/scripts -type f ! -name 'README.md' | wc -l` → `136`. Os dois gates novos e o `lib/machinery-drift.mjs` movem as duas contagens, e `w200[6]` e `w200[1]` reprovariam no dia da entrega. §10 lista o `README.md` como artefato editado, §12 põe as duas atualizações na definição de pronto, e — porque a armadilha é exatamente esta — **os valores novos não estão escritos nesta especificação**: estão os dois comandos que os produzem. Conferi também que nenhuma outra linha `<dir>/ (N)` do bloco muda.

**Bloqueador 2 — espelho do plugin não listado. ACEITO, remedido em §2.9, §9, §10 e §12.** Confirmei que `plugin-sync-gate.sh:19-26` regenera `plugin/forge` a partir de `template/.forge/commands` e exige `diff -r` limpo, que `plugin/forge/commands/liaison.md` e `template/.forge/commands/harness/liaison.md` têm hoje o mesmo tamanho em bytes, e que `npm run build:plugin` existe em `package.json:23` e aponta para `plugin-build.mjs` com `--out plugin/forge`. **Declaração de método, e ela importa por causa da armadilha E:** eu **não** executei `npm run build:plugin` — executá-lo reescreveria artefato rastreado fora do escopo desta especificação. O que fiz foi ler o script no `package.json` e a mensagem de recusa do próprio gate, que prescreve esse comando em letra. A especificação prescreve o comando do gate, não um comando meu.

**Bloqueador 3 — vermelho fabricado em `wB1[9]`. ACEITO, e reproduzi o contrafactual do revisor byte a byte.** Bancada B, mensagem já conhecida, bundle com o log e sem o blob: `OK import — 0 nova(s), 1 duplicata(s) (no-op), 1 conflito(s), 0 em quarentena`, rc 0, `conflicts/repo-a-0002.json` gravado — porque `liaison-import.mjs:170-174` converte esse bundle em conflito na passada 1. A fixture de `wB1[9]` foi trocada pela única que alcança `bodiesMissing > 0` com a passada 1 intacta, e eu montei e medi essa também (Decisão 8): mensagem com `body_ref` no **log local**, blob ausente, bundle sem aquele log — hoje sai `0 nova(s), 0 duplicata(s), 0 conflito(s)` e o `status` não diz nada. Escolhi **não** remover o conflito da passada 1: a alternativa que o revisor descreve é mudança de contrato que admite ponteiro morto novo no log e derruba junto a checagem de `BLOB_MAX_BYTES`, e o preço é maior que o benefício. A Decisão 8 foi reescrita porque a sua afirmação sobre `import --from` era falsa sobre o código de hoje.

**Bloqueador 4 — contrato de saída do `blobs verify` contraditório. ACEITO, remedido em §2.4 e §2.8, com cenário novo `wB1[4b]`.** A contradição era real e minha: §2.4/§2.5 diziam que DIVERGENTE é o único desfecho diferente de zero e §2.8 mandava reprovar por `universo-vazio` num estado comum. A separação é a que o revisor propõe e ela ficou explícita: `forge_universe_check` é **lib de gate** (`lib/gate-universe.sh`, sourceada por `tests/`), e passa a guardar a fixture de `wB1`, que tem blobs por construção; o subcomando ganha uma tabela de quatro desfechos com rc declarado, e o canal legitimamente vazio é o terceiro estado nomeado — `nada a verificar`, rc 0, sem nunca usar o vocabulário de integridade.

**Bloqueador 5 — contrafactual errado em M14. ACEITO, e executei a mutação para provar.** Bancada D, fixture saudável, mutação por substituição integral com controle de `sha` (`7540aff0… -> a0f73bff…`) e restauração conferida: sob M14 a linha `harness: LIAISON:` continua sendo impressa, `grep -qi liaison` continua SIM, e o predicado novo **passa**. A linha da matriz passa a nomear só `wB2[10]`. Não dei a `w112[8]` um segundo estado com `state.json` inválido, e digo por quê: esse estado já é `wB2[10]`, e duplicá-lo em outro arquivo criaria dois cenários que caem juntos pela mesma causa, o que infla o contador de controle sem acrescentar discriminação.

**Bloqueador 6 — contrafactual errado em M2. ACEITO, remedido em §2.6 com a medição colada.** Para conteúdo acentuado `sha256(bytes)` e a fórmula legada divergem (`iguais=false`), então o nome que M2 produz é DIVERGENTE pela alínea (c), não "íntegro (legado)"; para conteúdo ASCII elas coincidem (`iguais=true`), que é o mesmo fato que explica §2.3. E `wB1[3]` usa blob escrito à mão pela fixture, fora do caminho de escrita, que M2 não toca. A linha foi reescrita e o veredito esperado passou a depender explicitamente do conteúdo da fixture.

**Bloqueador 7 — falso-verde introduzido em `npx-pack-gate:135`. ACEITO, e é o achado mais desconfortável do veredito**, porque a onda existe para combater exatamente essa classe e ia introduzi-la. Confirmei que `grep -n 'sem drift' template/.forge/scripts/doctor.sh` devolve **uma só** ocorrência, a linha 156 do lockfile de adapter, e que a linha 135 do gate discrimina hoje por causa disso. §6.3 e §10 passam a exigir duas coisas juntas, no mesmo commit: a linha 135 estreitada para `harness: adapter .* sem drift`, e vocabulário próprio para a linha nova da maquinaria. Dizer que a linha 135 "continua casando a linha do adapter" era verdade e insuficiente, como o revisor escreveu.

### 15.2 As medições que não reproduziram

Onze itens. **Sete foram remedidos com o comando colado ao lado do número, quatro foram removidos.** A régua que usei: fica o que um revisor consegue reexecutar a partir do que está escrito aqui; sai o que dependia de uma bancada que já não existe ou de um universo que ninguém reconstrói.

| Afirmação da revisão 1 | Desfecho | Onde |
|---|---|---|
| §5.3, `grep -qi liaison` = SIM nos três estados | **REMEDIDA e REFUTADA por mim** — na fixture do `w112` ela devolve NAO no estado defeituoso; o SIM só aparece sob `core.hooksPath` customizado, e medi os dois | §5.3, §5.4, §14 item 3 |
| §2.2, `270 diretórios` / `77193 blobs` / `85` batendo | **REMOVIDA** — vinha de varredura com worktrees; fica o universo das quatro árvores + dois hubs, com o comando colado | §2.2 |
| §3.2, `355 réplicas` / `96185 body_ref` / `2 ponteiros mortos` | **REMOVIDA** pelo mesmo motivo; o passivo de campo hoje é zero, medido, e o item continua de pé pelo mecanismo | §3.2 |
| §5.1, `68` ackadas-e-não-lidas e o efeito do reparo | **REMEDIDA** com o `censo-canal.mjs` colado por inteiro (71, 223, 152, 34 hoje) | §5.1 |
| §4.1, as nove linhas de paridade e `2026 mensagens próprias` | **REMEDIDA** com o `paridade.mjs` colado por inteiro; nove de nove em paridade, `mensagens_proprias=2031` | §4.1 |
| §2.4, `6,4 s` e `0,27 s` do `blobs verify` | **REMEDIDA** com o comando e três repetições: 8,0 a 12,8 s de relógio, 0,25 a 0,32 s de CPU | §2.4 |
| §6.2, `1,3-1,6 s` do drift e `0,22 s` do `node -e '0'` | **REMEDIDA** com o comando e três repetições: 1,2 a 2,9 s e 0,47 a 0,53 s | §6.2 |
| §2.4, os `content_sha` da mensagem real e os totais de campo | **REMOVIDA** a parte da mensagem real, substituída por demonstração sintética que qualquer um roda; **REMEDIDOS** os totais, com os dois comandos | §2.4 |
| §4.2, o experimento do hub com `blobs/` sem escrita | **REMEDIDA** por reexecução; e o achado cresceu, porque o `return 0` está nos dois ramos de união | §4.2, §14 item 1 |
| §5.2, a bancada do `ack` com a lib de cursor ausente | **REMEDIDA** por reexecução, agora com recontrole | §5.2 |
| §7.2, a mutação `sender !== self` | **REMEDIDA** por reexecução, e ela expôs dois defeitos do meu próprio protocolo: o recontrole da revisão 1 passava por acidente, e o índice de linha da mensagem não é estável | §7.2, §7.3, §14 item 5 |
| §4.2, `195 created_at incoerente(s)` | **REMOVIDA** como estava (sem denominador) e **REMEDIDA** como `created_at_incoerentes=665` sobre as quatro árvores, pelo `censo-canal.mjs` | §4.2 |

### 15.3 Ressalvas de redação

Todas as seis aceitas e corrigidas, e três delas eram erro de fato, não de estilo. Os denominadores de `SCEN_MIN` de `wB1` e `wB2` passam a contar só os cenários **daquele arquivo** (§2.8, §4.5). `lib/pbt.mjs` é usado por `w121`, `w130` e `w132`, não por `w169` — medido por `grep -rln` (§2.7, §8). Subcomando de topo desconhecido cai no `*)` do `case` principal com `FAIL: comando desconhecido`, não em `_reject_unknown`, que é guarda de flag (§2.5, §5.4). A fixture de `wB2[5]` ganhou a ordem escrita — `sync` completo, `send`, `--pull-only`, `status` (§4.3). §13 passou a dizer que `wB1`/`wB2` não podem chegar ao disco, porque `w193` roda `gate-ordinal.sh check` sobre a árvore e `run-all.sh` descobre por glob. §14 item 1 nomeia os dois ramos de união.

### 15.4 Varredura das cinco armadilhas, na especificação inteira

Feita depois de fechar os bloqueadores, sobre o documento todo e não só sobre o que o revisor tocou.

**A — literal que envelhece em asserção.** Achados: os dois do README (bloqueador 1), agora em §10 e §12 com o comando em vez do valor. Varri o resto e o resultado é que **nenhuma asserção desta onda carrega literal de árvore**: o denominador do `blobs verify` é propriedade mais piso contado na própria fixture (§2.8); os `3` e `2` de `w195[12]` são da fixture, construídos por ela e fixos por construção; `SCEN_MIN` é a exceção legítima que a invariante 14 nomeia. Todos os números de campo do documento — acervo, réplicas, mensagens, entradas de lock, cursores, tempos — estão marcados como testemunha de data, e a regra que abre o documento diz isso de uma vez.

**B — string de produção mudada sem varrer `tests/`.** Achados: o espelho do plugin (bloqueador 2) e a colisão de "sem drift" (bloqueador 7). Varri as três outras superfícies que esta onda toca e listei nominalmente em §10: a linha de resultado do `_apply_bundle` (cinco asserções por substring, nenhuma quebra porque o sufixo é condicional), a linha `LIAISON:` do `status` (duas comparações de igualdade exata, contra a string do canal **não** inicializado, que não muda), e o `OK ack` — que a revisão 1 não tinha varrido — com `w166[6]`, `w166[7]` e `w201[P3]`, este último fundindo stderr e usando âncora de início de linha.

**C — linha de matriz sem contrafactual medido.** Dezessete mutações. **Quatro têm contrafactual observado e colado**: M5 (o estado de §3.1), M14 (bancada D, §5.5), M2 (a divergência acentuado/ASCII, §2.6) e a linha nova de `w198[7]` (§7.2). As demais declaram **propriedade e contrafactual** e estão marcadas, no texto de cada seção, como pendentes de execução pelo implementador contra a implementação real — que é a divisão de trabalho da invariante 19, não uma dispensa. Duas estão marcadas com o modo de falha silencioso conhecido: M2, que vira no-op se o verificador for tolerante com a ausência do prefixo, e M7, cujo primitivo de discriminação ainda não existe e cujos dois candidatos óbvios (`git diff-files`, `stat -f %m`) a invariante 19 já mediu que não servem nesta máquina.

**D — enumeração que se diz exaustiva.** Quatro enumerações. Decisão 3, os vereditos por blob: ganhou o caso alcançável que faltava, o canal legitimamente vazio, com desfecho nomeado e cenário próprio. Decisão 8, os transportes: continua exaustiva sobre `lib/transports/` (conferido por leitura — quatro `t_push`, nenhum em `_common.sh`), mas o "caso não coberto" que ela nomeava estava **errado**, e foi trocado pelo caminho que de fato alcança `bodiesMissing`. Decisão 12, os desfechos de push: ganhou um quarto caso procurado de propósito, canal **sem transporte configurado**, que não tem `kind` e por isso escapava da enumeração por `kind`. Decisão 23, os três estados do drift de maquinaria: mantida, e o estado (a) é o de `forge-harness` hoje, medido.

**E — prescrição de comando que nunca executei.** Esta é a que me obriga a declarar em vez de afirmar. **Executei e colei**: os censos de §2.2, §2.4, §3.2, §4.1, §5.1 e §6.1; as bancadas de §2.1, §3.1, §4.2, §5.2, §5.3, §7.2 e da Decisão 8; os tempos de §2.4 e §6.2; `gate-ordinal.sh next --path .`, que devolve `w208` com a mesma justificativa da revisão 1; as contagens do README e da árvore. **Não executei, e digo qual é a base de cada um**: `npm run build:plugin` — lido em `package.json:23` e prescrito pela mensagem de recusa do próprio `plugin-sync-gate`; **nenhum gate da suíte**, por `feedback-suite-sem-concorrencia`, e é por isso que §10 lista o que cada gate afirma por leitura do arquivo e não por execução dele. Onde a especificação diz "o implementador escolhe o primitivo e prova que ele discrimina", é porque eu não o executei e não vou fingir que executei — é o caso de M7 e do controle negativo de `w112[8]` e de `w198[5]`.
