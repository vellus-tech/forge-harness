# Onda D — falso-verde: aprovar sem ter olhado

Especificação implementável. Insumo: `docs/plans/2026-09-07-backlog-zero.md`, seções "Invariantes", "Definição de pronto do plano inteiro" e "Onda D". Fecha #119, #106 e LDG-0157.

Data das medições: 2026-09-07. Árvore: `/Users/milton/Documents/projects/forge-harness`, branch `fix/strix-achados-medios`. Todo número abaixo veio de um comando citado no próprio parágrafo, com **uma** exceção nomeada e isolada: o "8 gates, 33 worktrees" do `axis-device-platform` em §7, que é dado do corpo da issue #119 e está marcado como tal, porque o repositório não existe nesta máquina. Nenhum outro número é herdado de relatório de terceiro.

**Revisão 1 (2026-09-07):** esta spec foi reprovada por um revisor cético e reescrita. As correções estão no corpo, cada uma com a medição que a motiva, e a §11 as lista bloqueador a bloqueador — incluindo as duas medições do veredito que **não** procedem e o número em que o revisor e eu erramos juntos.

**Revisão 3 (2026-09-07) — mudança de método, e ela vale para o documento inteiro.** A invariante 19 do plano-mestre passou a ser normativa nesta rodada: *uma especificação não prescreve mecanismo que ela não executou*. Varri os **24** comandos que esta spec prescreve ao implementador ou ao gate — prescrição, não medição já citada com saída. Destes, **17 foram executados nesta rodada, com a saída colada ao lado da prescrição**; **5** viraram declaração de propriedade mais contrafactual, devolvendo a escolha do primitivo a quem executa, com a obrigação de provar a discriminação por controle e recontrole; e **2** ficam com a medição datada da revisão 1, marcados como tal no ponto de uso. A varredura encontrou **três prescrições erradas** que nenhuma das três revisões nomeou, e as três estão corrigidas no corpo: `check-secrets.sh path <arquivo com segredo plantado>` devolve **rc 0** e `WARN`, não rc 1, porque o `enforce` de fábrica é `warn` (§5.2, `[12]`); `grep -q 'INCONCLUSIVO test'` casa também `INCONCLUSIVO test-surface`, o que tornava a asserção (3) de `[7]` vermelha sobre a implementação certa (§3.4); e a constante `VETOR_FIXTURE1` não é literalmente igual à linha que a produção publica, de modo que "a igualdade literal do vetor" não era executável como escrita (§3.6). A §13 responde ao veredito da revisão 3 e reporta a varredura inteira.

Nenhum gate da suíte foi executado na produção desta especificação — a suíte completa roda em outro processo e gate manual concorrente produz falha fantasma em gate alheio (`feedback-suite-sem-concorrencia`). As reproduções abaixo usam bancadas em `$TMPDIR` que extraem blocos dos arquivos de produção por `sed`, sem editá-los.

---

## 1. O eixo comum, e por que ele não admite três remendos

Os três itens colapsam **"não verifiquei"** em **"está limpo"** (#119 e #106) ou em **"está sujo"** (LDG-0157). As duas direções são o mesmo defeito: o desfecho de uma verificação que não aconteceu recebe o rótulo de uma verificação que aconteceu.

Consertar cada um no seu sítio produziria três vocabulários. Este repositório já pagou esse preço em LDG-0152 (`fm_field` triplicado) e quase publicou uma allowlist envenenada quando um leitor novo reimplementou a regra de extração de um arquivo que já tinha leitor canônico. A onda entrega, portanto, **um vocabulário e um lib**, e os três itens passam a ser três chamadores dele.

### 1.1 O vocabulário já existe no harness — a onda promove, não inventa

Medido (`grep -rn 'inconclusive\|INCONCLUSIVE\|NÃO VERIFICADO\|NO-GATES\|universo-vazio\|abortou' template/`):

| Token | Ocorrências | Arquivos | Onde |
|---|---|---|---|
| `inconclusive` | 15 | 4 | `pentest-ops.sh` (10), `lib/api-surface.mjs` (3), `agents/quality/analyzer.md` (1), `rules/testing/gate-delivery-channel.md` (1) |
| `INCONCLUSIVO` (maiúsculo, português) | 5 | 3 | `pentest-ops.sh:523,1004,1021`, `rules/testing/gate-delivery-channel.md:56`, `commands/waves/pentest.md:135` |
| `NÃO VERIFICADO` | 2 | 1 | `hooks/git/pre-push:143`, `hooks/git/pre-push:181` |
| `NO-GATES` | 10 | 4 | `run-gates.sh`, `pre-push` |
| `universo-vazio` | 9 | 3 | `lib/gate-universe.sh`, allowlist |
| `abortou` | 3 | 3 | `check-shell-pipeline.sh:68`, `check-secrets.sh:193`, `check-heredoc-hash.sh:68` |
| `INCONCLUSIVE` (maiúsculo, inglês) | 0 | 0 | — |

A coluna "Onde" de `inconclusive` foi **corrigida na revisão 1** e vale a medição que a corrige, porque a versão anterior desta tabela atribuía 12 ocorrências ao `pentest-ops.sh` e omitia o `lib/api-surface.mjs`: `grep -rn 'inconclusive' template/ | awk -F: '{print $1}' | sort | uniq -c` devolve `10 pentest-ops.sh`, `3 lib/api-surface.mjs`, `1 agents/quality/analyzer.md`, `1 rules/testing/gate-delivery-channel.md` — 15 no total, em 4 arquivos.

`template/.forge/scripts/pentest-ops.sh:516-528, 882-894, 1000-1006` já implementa exatamente o que os três itens pedem: veredito por condição em `pass|refuse|inconclusive`, token fixo por condição (`STRIX_R_TOKEN`), agregação declarada ("recusa vence inconclusivo") e código de saída próprio — `0` aprovado, `3` recusado, `4` inconclusivo. Isso foi publicado na 0.14.0.

E `template/.forge/rules/testing/gate-delivery-channel.md` já normatiza o estado em letra: *"um gate que não pôde rodar por falta de credencial não pode ser reportado como aprovado, e também não pode bloquear quem não tem credencial na máquina"*.

**Decisão fechada:** o token é `INCONCLUSIVO` no início da linha, e o corpo da linha nomeia a capacidade ausente e como obtê-la.

**Alternativa descartada:** o literal `NÃO VERIFICADO` que LDG-0157 propõe como texto. A justificativa anterior desta spec dizia que adotá-lo "criaria um segundo nome para um estado que a 0.14.0 já publicou sob outro nome" — **isso estava invertido, e a medição da própria grade acima o mostra**: `grep -rn 'NÃO VERIFICADO' template/` devolve `hooks/git/pre-push:143` e `hooks/git/pre-push:181`, ambas com a semântica exata do terceiro estado (*"o script está ausente, esta checagem não rodou agora"*). Os dois nomes **já coexistem hoje**, e é `INCONCLUSIVO` que chega como terceiro no `pre-push`. A escolha por `INCONCLUSIVO` continua de pé, mas pelo motivo verdadeiro: ele já tem código de saída publicado (`pentest-ops.sh`, rc 4), já tem forma de linha estável (`INCONCLUSIVO <chave> — <mensagem>`) e já é o token que uma rule normativa do harness usa (`gate-delivery-channel.md:56`). `NÃO VERIFICADO` tem duas ocorrências, nenhum rc, nenhuma chave e nenhum leitor. A intenção de LDG-0157 é atendida integralmente — o que ela pede é que o desfecho deixe de ser imputado como violação, não que a palavra seja aquela.

**Decisão fechada — o destino dos dois sítios de `NÃO VERIFICADO`: migram nesta onda.** `pre-push:143` (`check-liaison-log-integrity.sh` ausente) e `pre-push:181` (`check-worktree-prereqs.sh` ausente) passam a emitir a linha `INCONCLUSIVO` no lugar do `NÃO VERIFICADO`, **sem nenhuma mudança de desfecho**: os dois continuam não bloqueando, pelo motivo que o comentário de `pre-push:300-305` já registra (worktree com `core.hooksPath` absoluto compartilhado e `.forge/scripts/` próprio — issue #73). **As duas linhas por extenso, porque a ressalva da revisão 3 procede e reticências não são decisão fechada.** As de hoje foram lidas com `grep -rn 'NÃO VERIFICADO' template/.forge/hooks/ template/.forge/scripts/`, executado nesta rodada, que devolve exatamente as duas:

| Linha | Hoje | Depois da migração |
|---|---|---|
| `pre-push:143` | `pre-push: liaison-log-integrity (issue #80) NÃO VERIFICADO — check-liaison-log-integrity.sh ausente em .forge/scripts/ (rode 'npx forge-harness update' para instalar). …` | `pre-push: INCONCLUSIVO liaison-log-integrity capacidade=ambiental — check-liaison-log-integrity.sh ausente em .forge/scripts/ (rode 'npx forge-harness update' para instalar). merge=union nunca perde mensagem, só duplica, e post-merge (quando presente) já teria sinalizado — mas esta checagem específica não rodou agora.` |
| `pre-push:181` | `pre-push: worktree-prereqs (issue #81) NÃO VERIFICADO — check-worktree-prereqs.sh ausente em .forge/scripts/ (rode 'npx forge-harness update' para instalar). …` | `pre-push: INCONCLUSIVO worktree-prereqs capacidade=ambiental — check-worktree-prereqs.sh ausente em .forge/scripts/ (rode 'npx forge-harness update' para instalar). Os gates abaixo ainda reprovam se algo faltar — só não juntos.` |

**Quem acrescenta a cauda é o próprio `pre-push`, e ele não usa `forge_verdict_require` nestes dois sítios — a ressalva da revisão 4 procede e a resposta é uma linha.** `forge_verdict_require` tem quatro argumentos e produz a linha que termina no `(<como-obter>)`, e ela não ganha um quinto para carregar cauda; os dois sítios do `pre-push` chamam `forge_verdict_say <chave> inconclusive:ambiental "<mensagem>"`, cuja mensagem é tudo o que vem depois do travessão — o script ausente, o `(rode 'npx forge-harness update' para instalar)` e a cauda de hoje, preservada byte a byte. A forma da linha é a mesma nos dois casos (`INCONCLUSIVO <chave> capacidade=<natureza> — <mensagem>`), e é `forge_verdict_say` que a emite para os vereditos `inconclusive:dura` e `inconclusive:ambiental`. Nas duas, o nome do script ausente continua **dentro** do corpo da linha, que é o que `w160[4]` exige; o número da issue sai da linha porque a chave (`liaison-log-integrity`, `worktree-prereqs`) passa a carregar a identificação, e o texto de cauda de cada uma fica intacto. É migração de vocabulário, não de severidade: `sed -n '142,144p;180,182p' template/.forge/hooks/git/pre-push` mostra que os dois vivem num ramo `elif [ -d "$ROOT/.forge/scripts" ]` que só imprime. A migração é assertada no gate da classe, cenário `[11]` de §5.2 (`grep -rn 'NÃO VERIFICADO' template/.forge/hooks/ template/.forge/scripts/` → 0), e sem ela a linha de DoD *"nenhum outro vocabulário concorrente aparece"* seria inalcançável por construção.

**E a migração edita dois gates rastreados JUNTO, no mesmo PR — a revisão 2 mediu o que faltava e procede inteiro.** As duas linhas do `pre-push` são afirmadas literalmente pela suíte, e implementar a migração sem tocar nos gates deixaria dois vermelhos com dois caminhos errados à mão (reverter a migração, ou afrouxar `[11]`). Medido, `grep -rn 'NÃO VERIFICADO' tests/` devolve exatamente duas linhas, e as duas rodam sobre o `pre-push` de produção copiado para a fixture (`cp -R "$WS/template/.forge" …` em `w160:39` e `w160:142`; `w168:104`):

| Gate | Linha | Asserção de hoje | Asserção depois da migração |
|---|---|---|---|
| `tests/w160-prepush-preflight-gate.sh` `[4]` | 134 | `case "$out4" in *check-worktree-prereqs.sh*"NÃO VERIFICADO"*\|*"NÃO VERIFICADO"*check-worktree-prereqs.sh*)` | casa `INCONCLUSIVO worktree-prereqs` **e** continua exigindo que a saída nomeie `check-worktree-prereqs.sh` |
| `tests/w168-liaison-log-merge-union-gate.sh` `[5]` | 128 | `grep -qi "NÃO VERIFICADO" <<<"$pp5_out"` | `grep -q "INCONCLUSIVO liaison-log-integrity" <<<"$pp5_out"` |

O que aqueles dois cenários realmente protegem fica intacto e continua assertado: `w160[4]` mantém `rc4 -eq 0` e `*"pre-push OK"*`, `w168[5]` mantém `pp5_rc -eq 0` e `grep -q "check-liaison-log-integrity"`. É troca de token, não de desfecho.

**Por que `capacidade=ambiental` e não `dura` nestes dois sítios, já que o alvo ausente é um script do próprio `.forge/scripts/`.** Porque a ausência aqui é ambiental por desenho, e o comentário de `w168:122-125` já escreve o motivo: `core.hooksPath` é compartilhado por todos os worktrees, mas `.forge/scripts/` é conteúdo próprio de cada um (issues #41, #73 e #81), então uma worktree legítima pode não ter trazido o commit daquele script. Isso é exatamente a alínea "ambiental por desenho" de §1.2, e é o que sustenta o não bloqueio. A regra de §1.2 sobre `lib/` do harness continua valendo para `lib/`, que é carregado por `source` e cuja ausência é fatal, não degradável.

### 1.2 A severidade é do chamador, e a natureza da capacidade é DECLARADA — não é derivada da fase

O `pre-push` já escreve esse princípio em letra, nas linhas 413-417 (`grep -n 'A severidade é do' template/.forge/hooks/git/pre-push` → 414; o parágrafo inteiro vai de 413 a 417, e a citação anterior desta spec dizia 411-415):

> `# A severidade é do CHAMADOR, e o hook é o chamador que bloqueia: run-gates.sh e spec-verify.sh seguem silenciosos no mesmo estado. Duas severidades para o mesmo fato, declaradas — o inaceitável seria ficarem implícitas.`

**Decisão fechada:** `INCONCLUSIVO` **nunca é verde e nunca é silêncio**; se ele bloqueia é decisão do chamador, governada por uma regra única:

- Quando a capacidade ausente é **dependência dura declarada do harness** — `node`, `git`, `bash`, um lib do próprio `.forge/scripts/lib/` — o chamador de publicação (`pre-push`, `commit-msg`) **bloqueia**. Justificativa medida: `template/.forge/scripts/lib/forge-runtime.sh:69-70` declara em letra que *"Node já é dependência dura do harness (é pacote npm consumido via /forge:init)"*, e 21 scripts de `template/.forge/scripts/` já abortam sem `node` (`grep -rn 'command -v node' template/.forge/scripts/*.sh | grep '||' | wc -l` → 21 linhas, em 21 arquivos distintos).
- Quando a capacidade ausente é **ambiental por desenho** — credencial, rede, cluster, `node_modules` de terceiro — o chamador **não bloqueia**, mas imprime a linha `INCONCLUSIVO` e o desfecho nunca é reportado como aprovado. É literalmente o que `gate-delivery-channel.md` manda para as fases `pre-deploy`/`post-deploy`.

**Correção de desenho da revisão 1 — a fase NÃO discrimina, e a versão anterior desta seção estava errada ao dizer que sim.** A revisão mediu o contraexemplo dentro da própria onda: `check-test-surface.sh` (§3) é gate de fase `source` e produz o terceiro estado em duas situações que as duas alíneas acima mandam tratar de forma **oposta** — sem `node` (dependência dura, o `pre-push` bloqueia) e com superfície de teste descoberta (ambiental, o `pre-push` imprime e segue). Mesmo gate, mesma fase, mesmo estado. Nenhuma leitura da fase separa os dois, e um chamador que tentasse derivar a severidade da fase acertaria um dos casos e erraria o outro em silêncio.

**Decisão fechada, substituindo a anterior:** a natureza da capacidade ausente é **um argumento declarado na chamada** — `dura` ou `ambiental` —, transportada por **dois códigos de saída distintos** (rc 4 = inconclusivo por capacidade dura; rc 5 = inconclusivo por capacidade ambiental) **e** por um campo literal na linha impressa (`capacidade=dura` / `capacidade=ambiental`). O chamador nunca infere: ele lê o rc, que é o canal que `pre-push`, `run-gates.sh` e `spec-verify.sh` já leem hoje. A fase do gate é **um insumo da regra de escolha** entre as duas alíneas acima — não o discriminante, e nunca o único.

`5` está livre, medido: `grep -rn 'exit 5\|-eq 5 \]\|rc.*== 5' template/.forge/` devolve **zero**. Duas linhas de `run-gates.sh` e do `pre-push` mapeiam hoje qualquer rc diferente de zero para bloqueio, então o rc 5 nasce fail-closed em todo chamador que ainda não o conhece — a direção segura.

A fase continua sendo o que o harness já carrega em `runtime.gates` desde a 0.11.0, e continua sendo o insumo que decide a alínea para os gates declarados. Não é um campo novo, e a onda não cria nenhum.

**Alternativa descartada:** deixar a severidade em cada gate, por flag. Descartada porque flag de quem invoca é exatamente a porta que `lib/gate-universe.sh:17-19` fecha para a isenção de universo vazio — *"O terceiro estado NÃO é operado por memória de agente nem por flag de quem invoca"* —, e reabri-la aqui contradiria o lib irmão dentro do mesmo diretório.

### 1.3 Códigos de saída — decisão fechada

| rc | Significado | Já em uso? |
|---|---|---|
| 0 | examinei e está limpo | sim, todos os gates |
| 1 | examinei e encontrei violação | sim, 14 de 14 `check-*.sh` |
| 2 | uso incorreto do próprio gate | sim, `check-ai-attribution.sh`, `check-suite-wiring.sh` |
| 4 | **não consegui examinar — capacidade DURA ausente** | sim, `pentest-ops.sh` — passa a valer para todo gate |
| 5 | **não consegui examinar — capacidade AMBIENTAL ausente** | não — nasce nesta onda (§1.2) |

`1` permanece "violação encontrada" e não é renumerado: medido por `grep -l 'exit 1' template/.forge/scripts/check-*.sh | wc -l`, os **14** gates `check-*.sh` usam `exit 1` para violação, e `run-gates.sh:101-105` e `pre-push:214-219` mapeiam qualquer rc diferente de zero para bloqueio (a citação anterior desta spec dizia 214-220; `sed -n '214,220p'` mostra que 220 é o `fi` e o mapeamento vive em 214-219). Renumerar seria um contrato quebrado sem ganho.

`3` fica deliberadamente sem uso no vocabulário geral, porque `pentest-ops.sh` já o consome como `refused` num contexto próprio, e reaproveitá-lo com outro sentido seria a mesma ambiguidade que a onda combate. Num chamador que não seja o perfil `strix`, um rc 3 cai no ramo `*` da tabela de §3.3 e **bloqueia**, nomeando o rc — por decisão, não por esquecimento.

**Os rc que esta tabela não enumera, e o que acontece com eles.** A tabela cobre um vocabulário, não o domínio de `0..255`. Ficam de fora, e chegam na prática: `126` (alvo presente e não executável), `127` (comando ou função inexistente — medido em §2.3, Decisão 2, onde uma função ausente capturada por substituição devolve exatamente 127) e `128+N` (morte por sinal; `137` é o `SIGKILL` de um watchdog ou do OOM killer). Nenhum deles é veredito de gate: são rc do shell sobre uma invocação que não chegou a acontecer. **Decisão:** todos caem no ramo `*` de §3.3 e bloqueiam com o rc nomeado, e nenhum é traduzido para `INCONCLUSIVO` — traduzir um `137` em "não consegui examinar" seria correto por acidente e errado por método, porque apagaria a diferença entre uma capacidade ausente e um processo morto, que pedem ações opostas de quem lê o log.

**Retrocompatibilidade do rc 4, medida, e a correção de escopo da revisão 1.** A versão anterior desta seção dizia que os três lints "usam `exit 2` para node ausente" e que "a onda os move para 4", como se o arquivo inteiro fosse migrado. Remedi, e a revisão 3 acrescentou um quarto arquivo à conta (adiante). Executado nesta rodada, `grep -c 'exit 2'` devolve **3** em `check-shell-pipeline.sh`, **3** em `check-heredoc-hash.sh`, **5** em `check-secrets.sh` e **3** em `check-suite-wiring.sh` — **14 linhas** nos quatro —, e a maioria é *uso incorreto de verdade* (`--path exige um argumento`, `modo desconhecido`, `<rev-range> obrigatório`, `--root exige um argumento`). A migração é **por linha**, e a lista literal veio de um comando executado nesta rodada — `grep -nE 'command -v node|mktemp' template/.forge/scripts/check-*.sh | grep -E 'exit 2'` —, que devolve **sete** linhas em **quatro** arquivos:

| Linha | Hoje | Passa a ser |
|---|---|---|
| `check-shell-pipeline.sh:29` | `FAIL shell-pipeline — node >= 20 necessário`, `exit 2` | `INCONCLUSIVO shell-pipeline capacidade=dura`, rc 4 |
| `check-heredoc-hash.sh:32` | idem, `exit 2` | rc 4 |
| `check-secrets.sh:48` | idem, `exit 2` | rc 4 |
| `check-shell-pipeline.sh:42` | `mktemp falhou`, `exit 2` | `INCONCLUSIVO shell-pipeline capacidade=ambiental`, rc 5 |
| `check-heredoc-hash.sh:45` | idem, `exit 2` | rc 5 |
| `check-secrets.sh:98` | idem, `exit 2` | rc 5 |
| `check-suite-wiring.sh:39` | `FAIL suite-wiring — mktemp falhou`, `exit 2` | `INCONCLUSIVO suite-wiring capacidade=ambiental`, rc 5 |

**A sétima linha entrou na revisão 3, o bloqueador Novo 1 procede, e eu o remedi antes de aceitar.** A versão anterior desta tabela tinha seis linhas e escrevia, em `[9]` de §5.2, que o predicado casa "as 6 linhas nomeadas aqui". Executado, ele casa **sete**: `check-suite-wiring.sh:39` é `TMP="$(mktemp -d /tmp/forge-wiring.XXXXXX)" || { echo "FAIL suite-wiring — mktemp falhou" >&2; exit 2; }`, o **mesmo idioma**, com a mesma justificativa desta seção — "não consegui criar o diretório de trabalho é literalmente não consegui examinar". Ele não chegava pelos outros caminhos da onda: `grep -n 'node' template/.forge/scripts/check-suite-wiring.sh` devolve **zero** ocorrências, executado nesta rodada, então o arquivo não está entre os 11 gates que invocam `node` (§4.4, Decisão 2) e não entra por `[8]` de §5.2. Deixá-lo de fora seria decisão em aberto disfarçada de fechada — o implementador que seguisse a tabela migraria seis e ficaria com um vermelho fabricado em `[9]`. Ele entra, e vira o sítio **21** de §5.1.

As **sete** linhas restantes de `exit 2` nesses quatro arquivos ficam **intocadas** (14 medidas menos as 7 que migram): elas são uso incorreto do gate, que é o que o rc 2 significa. Incluir as de `mktemp` não é alargamento gratuito — "não consegui criar o diretório de trabalho" é literalmente "não consegui examinar", e deixá-las como `exit 2` manteria dentro do arquivo já editado a mesma confusão que a onda existe para fechar.

A mudança é invisível para todo chamador existente: `grep -rn 'rc.*-eq 2\|-eq 2 \]' template/.forge/scripts/*.sh template/.forge/hooks/git/*` devolve **zero** ocorrências, executado nesta rodada, e nenhum gate de `tests/` afirma rc 2 vindo desses três (`grep -rn 'check-shell-pipeline\|check-secrets\|check-heredoc-hash' tests/*.sh | grep -i 'rc\|exit'` devolve duas linhas, ambas de outro assunto). O mesmo vale para o quarto arquivo, conferido nesta rodada porque ele entrou agora: o único gate que exercita `check-suite-wiring.sh` é `tests/w146-suite-invocation-gate.sh`, e ele afirma `rc -eq 0` (linha 52) e `rc -ne 0` (linha 72), nunca um rc 2 nominal — e a linha 39, que migra, só dispara quando o `mktemp` falha, o que não acontece na fixture dele. A mudança só passa a ser observável depois que os chamadores aprendem o `4` e o `5`, o que acontece nesta mesma onda.

### 1.4 O lib compartilhado — decisão fechada

Nasce `template/.forge/scripts/lib/gate-verdict.sh`, irmão de `lib/gate-universe.sh`, com cinco funções e nada mais:

```
forge_verdict_require <gate-key> <dura|ambiental> <capacidade> <como-obter>
      # 0 se presente e nada impresso; se ausente, imprime
      #   INCONCLUSIVO <gate-key> capacidade=<dura|ambiental> — <capacidade> ausente (<como-obter>)
      # e devolve 4 (dura) ou 5 (ambiental)
forge_verdict_say     <gate-key> <pass|fail|inconclusive:dura|inconclusive:ambiental> <mensagem>
      # imprime a linha do veredito com a MESMA forma de forge_verdict_require:
      #   INCONCLUSIVO <gate-key> capacidade=<dura|ambiental> — <mensagem>
      # nos dois vereditos inconclusivos; a <mensagem> é livre e carrega tudo o que
      # vem depois do travessão, o que é como os dois sítios de pre-push (§1.1)
      # preservam a cauda de hoje sem que require ganhe um quinto argumento
forge_verdict_rc      <pass|fail|inconclusive:dura|inconclusive:ambiental>   # ecoa 0 | 1 | 4 | 5
forge_verdict_is_inconclusive <rc>   # 0 quando rc é 4 OU 5 — para o lado do CHAMADOR
forge_verdict_kind    <rc>           # ecoa "dura" (4), "ambiental" (5), "" nos demais
```

A quarta e a quinta funções existem para o lado do chamador: `forge_verdict_is_inconclusive` responde *"foi inconclusivo?"* sem que o `pre-push` precise conhecer os dois números, e `forge_verdict_kind` responde *"e de que tipo?"*, que é a pergunta cuja ausência a revisão 1 mediu como decisão em aberto (§1.2). O campo `capacidade=` na linha impressa é redundante com o rc de propósito: o rc serve ao chamador, o campo serve a quem lê o log depois, e um log é o único artefato que sobrevive à sessão.

**Por que arquivo novo e não dentro de `lib/gate-universe.sh`:** `gate-universe.sh` responde *"quantos itens examinei"* e este responde *"consegui examinar?"* — são perguntas diferentes, e a segunda antecede a primeira. Além disso `gate-universe.sh` está publicado desde a 0.11.0 e seu contrato inclui o formato de `.forge/empty-universe-allowlist.txt`, que consumidores já editaram; ampliar um arquivo com contrato instalado é risco que um arquivo novo não tem. **Alternativa descartada:** fundir os dois num `lib/gate-state.sh`. Descartada pelo mesmo motivo, e porque a fusão obrigaria todo consumidor do contador a carregar o vocabulário de capacidade que ele não usa.

**Por que bash e não `.mjs`:** o lib precisa funcionar quando `node` está ausente — é a condição que ele existe para detectar. Um lib em node que detecta a ausência de node é a tautologia mais óbvia possível.

---

## 2. Item 1 — issue #119: a guarda dispara pela forma do frontmatter

### 2.1 O defeito, reproduzido

O comentário de `template/.forge/hooks/git/pre-push:406-411` declara o gatilho:

> `# indistinguível de "nenhum gate declarado". O gatilho do bloqueio é a INDISPONIBILIDADE DO LEITOR, nunca a forma do frontmatter`

E a linha 418 condiciona a guarda inteira à forma: `if [ -z "$_gates_inline" ]; then`. Confirmado por `sed -n '406p;411p;418p;419p;431p' template/.forge/hooks/git/pre-push`.

**Bancada.** Duas árvores com o **mesmo** `FORGE.md` (8 gates em CSV escalar) e os **mesmos** 8 scripts de gate presentes e executáveis. Única variável: `lib/forge-runtime.sh`. A árvore A recebe a lib de `15ce493^` (anterior ao commit que criou `forge_runtime_gate_entries`); a árvore C recebe a lib de hoje mais `gate-phase.mjs`. A sonda é o bloco das linhas 400-436 do `pre-push`, extraído por `sed -n '400,436p'` sem uma edição, mais duas linhas que imprimem `_n_all`/`_n_src` e o ramo tomado.

Confirmação de que a variável é a que digo: `grep -c 'forge_runtime_gate_entries' A/.forge/scripts/lib/forge-runtime.sh` → **0**; o mesmo em C → **4**; `grep -c 'forge_get_runtime()'` em A → **1**, ou seja, a lib antiga tem o leitor genérico e não tem o de entradas de gate.

Saída literal da árvore A:

```
sonda.sh: line 36: forge_runtime_gate_entries: command not found
SONDA: _gates_inline_len=191 _n_all=0 · _n_src=0
pre-push: runtime.gates NO-GATES — 0 gate(s) declarado(s) no FORGE.md
  EXIT=0
```

Saída literal da árvore C, controle positivo:

```
SONDA: _gates_inline_len=191 _n_all=8 · _n_src=8
pre-push: runtime.gates — 8 gate(s) de fase 'source' de 8 declarado(s)
  EXIT=0
```

Nas duas árvores o `FORGE.md` declara 8 gates (`awk '/^  gates:/{...split(",")}'` → 8) e há 8 scripts no disco (`ls .forge/scripts/*.sh | wc -l` → 8). A árvore A afirma zero, e sai zero.

`_gates_inline_len=191` nas duas é a prova de que a guarda da linha 418 **nunca entra** na forma CSV: `_gates_inline` é não-vazio, então o bloco 419-429 é pulado inteiro, e é ele quem examina a disponibilidade do leitor.

### 2.2 O defeito é maior do que a issue descreve — cinco sítios, não um

A versão anterior desta tabela listava quatro sítios e **trocava `spec-verify.sh:92` por `lib/forge-runtime.sh:87`**, que é o leitor e não um chamador; a revisão 1 mediu a troca e ela procede. Remedi: `grep -rn 'forge_runtime_gate_entries\|forge_runtime_gates_phase' template/ bin/ installer/` devolve o leitor mais **quatro chamadores**, e `grep -rn 'command -v forge_runtime\|type forge_runtime\|declare -f forge_runtime' template/ bin/` devolve **zero** — nenhum deles confere que a função existe depois do `source`:

| Sítio | Papel | Forma do colapso | Consequência |
|---|---|---|---|
| `scripts/lib/forge-runtime.sh:87` | **o leitor** | `node "$script_dir/gate-phase.mjs" entries "$root" 2>/dev/null \|\| true` | leitor presente mas com crash ⇒ 0 gates, calado |
| `hooks/git/pre-push:431` | chamador | `$(forge_runtime_gate_entries "$ROOT" \|\| true)` | função ausente ⇒ 0 gates ⇒ `NO-GATES`, exit 0 |
| `scripts/run-gates.sh:58` | chamador | `< <(forge_runtime_gates_phase "$PHASE" "$ROOT")` | rc de substituição de processo é inobservável ⇒ 0 gates ⇒ `NO-GATES`, exit 0 |
| `scripts/spec-verify.sh:92` | chamador | `done < <(forge_runtime_gates_phase source "$ROOT")` | **idêntico ao de `run-gates.sh`** ⇒ `CHECKS_YAML` sem gate algum ⇒ `verification.yaml` gravado afirmando verificação que não houve |
| `scripts/doctor.sh:427` | chamador | `… 2>/dev/null \| awk … \|\| true` | cruzamento de gate órfão vira "nenhum órfão" |

`run-gates.sh` tem `set -euo pipefail` (linha 29) e mesmo assim não vê a falha, porque `set -e` não observa o rc de `< <(...)`. O `pre-push` tem só `set -u` (linha 5), então o `|| true` da 431 é ainda mais gratuito: sem ele o script já seguiria, só que com o rc visível numa variável.

**`spec-verify.sh:92` é o sítio de consequência mais grave dos cinco, e a versão anterior desta spec não lhe dava decisão nem asserção.** Medido: `sed -n '92,93p' template/.forge/scripts/spec-verify.sh` mostra a mesma substituição de processo; numa árvore com lib anterior à 0.11.0 o laço não itera, nenhum gate entra em `CHECKS_YAML`, a linha 93 (`[ -n "$CHECKS_YAML" ] || echo "  (no checks declared in FORGE.md runtime: — skipping check phase)"`) imprime a mensagem de "nada declarado", e o `verification.yaml` do change nasce sem gate nenhum. Esse artefato é o que sustenta a transição para `verified`. Onde `run-gates.sh` produz uma wave fechada em falso, `spec-verify.sh` produz **evidência arquivada** em falso — e evidência arquivada sobrevive à sessão.

**Isto amplia o escopo declarado da issue e é deliberado:** corrigir só o `pre-push` deixaria `run-gates.sh` — o executor que `/forge:wave close` invoca — imprimindo `NO-GATES` e saindo 0 na mesma árvore.

### 2.3 Decisões de desenho fechadas

**Decisão 1 — o leitor passa a poder dizer "não consegui ler".** `forge_runtime_gate_entries` ganha rc próprio: `0` quando leu (inclusive quando leu legitimamente zero entradas) e `4` quando não pôde ler — `node` ausente, `gate-phase.mjs` ausente, ou `gate-phase.mjs` com rc diferente de zero. O `2>/dev/null || true` da linha 87 sai.

**O desfecho que esta enumeração NÃO cobre, dito em voz alta.** Existe um quarto estado: `gate-phase.mjs` presente, executado, rc 0, e **saída vazia ou malformada**. Na forma CSV ele é detectável, e é exatamente o que o backstop da Decisão 2 cobre (declaração não vazia contra zero entradas lidas). Na forma **mapeada**, "o `FORGE.md` declara zero gates" e "o leitor devolveu zero" são indistinguíveis por construção, porque não há um segundo canal com a contagem declarada para confrontar. **Decisão:** a onda **não** fecha esse buraco, e o `NO-GATES` da forma mapeada continua possível. Fecha-lo exigiria um contador declarado no próprio `FORGE.md` — um campo novo, que §1.2 recusa criar. Fica escrito para que o próximo revisor saiba que é fronteira decidida, e não esquecimento; e para que a onda K, que herda o vocabulário, saiba onde a cobertura termina.

**Restrição de implementação, medida, que nenhuma revisão anterior nomeou: no caminho feliz a saída não muda em um byte.** `tests/w171-gate-phase-contract-gate.sh` compara a saída de `run-gates.sh` com três goldens versionados por `cmp` — `[0a]` contra `tests/fixtures/w171/golden-no-gates.txt` (duas linhas: `  (nenhum gate declarado em runtime.gates do FORGE.md — nada a executar)` e `NO-GATES`), `[0b]` contra `golden-ok-source.txt` e `[0c]` contra `golden-fail-source.txt`, este com `LOGDIR` normalizado. A fixture do `w171` copia `template/.forge` inteiro, então ela roda com a lib de hoje e o leitor **disponível** — o `NO-GATES` dela é o legítimo, e a mudança de `run-gates.sh:58` precisa preservá-lo byte a byte. Qualquer linha de diagnóstico impressa quando o rc do leitor é **zero** derruba os três cenários de uma vez. A variável intermediária da Decisão 3 imprime **apenas** quando o rc é diferente de zero. Consequência aceita e registrada: depois da onda, `w171[0a]` passa a depender de `node` estar presente na máquina que roda a suíte, porque hoje ele produziria a mesma saída com o leitor engolindo o erro — que é precisamente o silêncio que a onda remove.

*Alternativa descartada (a), a da própria issue:* acrescentar `|| ! command -v forge_runtime_gate_entries` ao teste da linha 419. Descartada por duas razões medidas: obriga cada chamador a saber **qual** leitor a declaração daquela árvore precisa, e não cobre o caso de o leitor existir e falhar — que é o sítio `forge-runtime.sh:87`, onde um `gate-phase.mjs` com erro de sintaxe vira zero gates em silêncio.

**Decisão 2 — a contradição interna é backstop, não a correção.** A verificação `[ -n "$_gates_inline" ] && [ "$_n_all" -eq 0 ]` — sugestão (b) da issue — entra, mas como segunda linha de defesa, porque ela só cobre a forma CSV: na forma mapeada `_gates_inline` é vazio por construção e a contradição não existe para ser detectada.

*Justificativa corrigida na revisão 1.* A versão anterior dizia que o backstop "é o que resta quando a função inteira está ausente e o rc é 127" — **e isso está errado**, medido: `bash -c 'set -u; rc=0; v="$(fn_inexistente)" || rc=$?; echo $rc'` devolve **127**, ou seja, a captura explícita da Decisão 3 já observa a função ausente nas duas formas declaráveis, CSV e mapeada. O backstop não é "o que resta"; ele é **redundância deliberada** contra um modo de falha diferente — um leitor que exista, rode, saia 0 e devolva lista vazia sobre um `FORGE.md` que declara gates em CSV (um `gate-phase.mjs` regredido, um filtro de fase quebrado). Manter o backstop continua certo; a justificativa é que precisava ser esta, porque um implementador que confiasse na anterior poderia concluir que a Decisão 3 não cobre a forma mapeada com lib antiga — e cobre.

**Decisão 3 — o rc do leitor passa a ser observável nos cinco sítios, e a propriedade não pode depender das opções de shell de quem chama.** O `|| true` sai, a substituição de processo sai, e a captura do rc entra. A **propriedade** é esta, e é ela que o implementador precisa provar: *quando o leitor não consegue ler, o rc que o chamador observa é o do leitor — em qualquer chamador, com qualquer combinação de `set -e`, `set -u` e `pipefail`.* O contrafactual que a mutação tem de produzir está em §2.5 e nos cenários `[14b]` e `[15b]` de §2.4.

O idioma abaixo é o que esta spec sugere para a captura, e ele **não** é suficiente sozinho — a medição desta rodada explica por quê:

```sh
_gate_entries=""; _reader_rc=0
_gate_entries="$(forge_runtime_gate_entries "$ROOT")" || _reader_rc=$?
```

Em `run-gates.sh:58` **e em `spec-verify.sh:92`** a substituição de processo dá lugar a uma variável intermediária, porque a substituição de processo não expõe rc nenhum, sob opção de shell nenhuma. São os dois únicos sítios com essa forma, executado nesta rodada: `grep -rn '< <(forge_runtime_gates_phase' template/.forge/` devolve exatamente `spec-verify.sh:92` e `run-gates.sh:58`.

**O bloqueador Novo 2 da revisão 3 afirma que a variável intermediária captura zero nesses dois sítios, e a medição mostra que ela captura 4. REFUTO a medição, e mesmo assim mudo a decisão — pelo motivo verdadeiro, que é outro.** O revisor mediu numa bancada com o shell no default e concluiu que o rc do leitor "morre no pipe" de `forge_runtime_gates_phase`. O corpo da função é mesmo um pipe (`sed -n '93,96p' template/.forge/scripts/lib/forge-runtime.sh`, executado: `forge_runtime_gate_entries "$root" | awk -F'\t' -v p="$phase" '$2==p{print $1}'`), mas opções de shell em bash são **dinâmicas, não léxicas**: a função é carregada por `source` no shell do chamador e o pipe dela roda sob as opções *daquele* shell. E os dois chamadores nomeados declaram `pipefail`, executado nesta rodada: `grep -n '^set ' template/.forge/scripts/run-gates.sh` → linha 29, `set -euo pipefail`; o mesmo em `spec-verify.sh` → linha 12, `set -euo pipefail`; `doctor.sh` → linha 19, `set -u`; `pre-push` → linha 5, `set -u`.

Bancada em `$TMPDIR`, com o corpo **real** da função extraído por `sed` e um leitor que devolve 4, os dois chamadores reproduzidos pelas suas opções reais:

```
CHAMADOR-COM-pipefail (run-gates.sh/spec-verify.sh): rc=4 out=[]
CHAMADOR-SO-set-u (doctor.sh/pre-push):              rc=0 out=[]
```

Ou seja: nos dois sítios que o bloqueador nomeia, a variável intermediária **observa** o rc 4 hoje; no sítio que ele cita de passagem — `doctor.sh:427`, que tem só `set -u` **e** pipe próprio com `|| true` — o rc morre mesmo, e ali ele está certo.

**Por que mudo a decisão assim mesmo.** Uma propriedade que só vale porque o chamador por acaso declarou `pipefail` é acoplamento invisível, e é a mesma classe de defeito da onda: o desfecho certo por um motivo que não está escrito em lugar nenhum. Um chamador novo com `set -u` — e `doctor.sh` é exatamente esse — perde a observabilidade sem que nada acuse, e um `set +o pipefail` local em `run-gates.sh`, no dia em que alguém precisar de um, apaga a guarda sem tocar nela. **Decisão fechada, acrescentada nesta revisão:** `forge_runtime_gates_phase` deixa de propagar o rc do leitor por herança de opção de shell e passa a propagá-lo **explicitamente**. A spec declara a propriedade e não prescreve o primitivo — variável intermediária dentro da função, `PIPESTATUS`, `set -o pipefail` local com restauração, ou eliminação do pipe: a escolha é de quem executa, e a obrigação é provar a discriminação com o par de bancadas acima, `set -u` puro incluído. O mesmo vale para o `awk` de `doctor.sh:427`, que perde o `|| true` pela mesma razão. E `forge_runtime_gates_phase` entra na lista de sítios de §5.1 (item 22) e no passo 3 de §10.

**Decisão 4 — quem faz o quê, nos cinco sítios.**

| Chamador | Desfecho com leitor indisponível | Por quê |
|---|---|---|
| `pre-push:431` | **bloqueia**, com `INCONCLUSIVO … capacidade=dura` | é o chamador de publicação; dependência dura, §1.2 |
| `run-gates.sh:58` | **reprova** com rc 1 e a linha `INCONCLUSIVO` | é chamado no fechamento de wave, e "não consegui ler os gates" não pode virar wave fechada |
| `spec-verify.sh:92` | **reprova** (`fail=1`) **e grava** `status: inconclusive` no `verification.yaml`, nunca lista vazia com rc 0 | é o produtor de evidência arquivada; a transição para `verified` não pode se apoiar num artefato que omite o estado |
| `doctor.sh:427` | **não** bloqueia; imprime `info` nomeando a causa | já é diagnóstico, e já tem na linha 421 a linha `info` correta para o caso da lib ausente; ganha a mesma para o caso do leitor presente e quebrado |
| `lib/forge-runtime.sh:87` (o leitor) | devolve rc 4, sem imprimir | quem imprime é o chamador — o leitor não conhece a severidade |

**Sobre o `commit-msg`, corrigido na revisão 1.** A versão anterior desta decisão atribuía comportamento ao `commit-msg` no contexto do leitor de `runtime.gates`, e ele **não lê `runtime.gates`**: medido, `grep -n 'forge_runtime' template/.forge/hooks/git/commit-msg` devolve vazio; ele consome apenas `check-ai-attribution.sh`. O `commit-msg` entra nesta onda pelo item 3 (§4), como chamador de um gate que passa a falar `INCONCLUSIVO`, e pela regra genérica de §1.2 — não como consumidor do leitor. Fica escrito assim para que ninguém procure um sítio que não existe.

### 2.4 O vermelho, antes do verde

Casa em `tests/w190-pre-push-gate-reader-gate.sh`, que já tem a bancada de canal real — `git init`, hooks por `core.hooksPath` **absoluto**, remoto `--bare`, `git push` de verdade — e já tem contador de cenários (`SCEN`).

**`w190[12]` — CSV escalar com lib sem a função: o push é RECUSADO.** A fixture recebe `.forge/` do template, sobrescreve `lib/forge-runtime.sh` pela versão de `15ce493^`, declara 8 gates em CSV e cria os 8 scripts. Asserções: o push termina com rc diferente de zero; a saída contém `INCONCLUSIVO` nomeando o leitor de `runtime.gates`; a saída **não** contém `NO-GATES`.

*Como falha hoje:* o push termina rc 0 e a saída contém `pre-push: runtime.gates NO-GATES — 0 gate(s) declarado(s) no FORGE.md` — a string exata medida em §2.1. A asserção falha porque **não existe caminho no `pre-push` que compare declarado contra lido**; nenhuma linha do arquivo faz essa comparação (`grep -n '_n_all' template/.forge/hooks/git/pre-push` devolve as linhas 433-445, todas de contagem e impressão, nenhuma de contradição). Não é fixture torta: é ausência de funcionalidade.

**`w190[12c]` — controle positivo, obrigatório e pareado.** A **mesma** fixture, o **mesmo** `FORGE.md`, os **mesmos** 8 scripts, e a lib de hoje: o push passa e a saída diz `8 gate(s) de fase 'source' de 8 declarado(s)`. Sem esse par, `[12]` não distingue "a guarda funciona" de "esta fixture não empurra por outro motivo qualquer".

**`w190[13]` — forma mapeada com `gate-phase.mjs` que falha.** `gate-phase.mjs` é substituído por um arquivo com `process.exit(1)` na primeira linha. Asserções: push recusado, `INCONCLUSIVO` presente. *Como falha hoje:* `forge-runtime.sh:87` engole o rc com `2>/dev/null || true`, `_n_all=0`, e o hook cai no `NO-GATES` verde — este cenário não é coberto por `[6a]` nem por `[6b]`, que testam ausência de arquivo e ausência de binário, nunca falha de execução.

**`w190[14]` — `run-gates.sh` no mesmo estado.** Sobre a fixture de `[12]`, chamada direta a `bash .forge/scripts/run-gates.sh <id>`: rc diferente de zero e `INCONCLUSIVO` na saída. *Como falha hoje:* imprime `NO-GATES` e sai 0, medido pela leitura de `run-gates.sh:73-83`, cujo ramo de `${#gates[@]} -eq 0` é incondicional quando `PHASE_EXPLICIT` é 0.

**`w190[15]` — `spec-verify.sh` no mesmo estado: o `verification.yaml` carrega `inconclusive`, nunca uma lista vazia com rc 0.** Cenário exigido pela revisão 1, e é o de consequência mais grave dos cinco sítios (§2.2). Sobre a fixture de `[12]` — mesmo `FORGE.md` com 8 gates em CSV, mesmos 8 scripts em disco, `lib/forge-runtime.sh` de `15ce493^` — mais um change ativo mínimo em `.forge/specs/active/`, chamada direta a `bash .forge/scripts/spec-verify.sh <change-id>`. Asserções, todas positivas: (a) o rc é diferente de zero; (b) a saída contém `INCONCLUSIVO` nomeando o leitor de `runtime.gates`; (c) o `verification.yaml` gravado contém `status: inconclusive` para a entrada de gates; (d) a saída **não** contém `(no checks declared in FORGE.md runtime: — skipping check phase)`.

*Como falha hoje:* medido por leitura, `spec-verify.sh:92` é `done < <(forge_runtime_gates_phase source "$ROOT")` e `spec-verify.sh:93` é `[ -n "$CHECKS_YAML" ] || echo "  (no checks declared in FORGE.md runtime: — skipping check phase)"`. Com a lib antiga o laço não itera, `CHECKS_YAML` fica vazio, a linha 93 imprime a mensagem de "nada declarado" e o script segue para gravar o artefato. As quatro asserções falham por ausência de funcionalidade: `grep -n 'INCONCLUSIVO\|inconclusive' template/.forge/scripts/spec-verify.sh` devolve **zero**, e o schema de hoje sequer admite o valor (§6, contrato 1).

**`w190[14b]` e `[15b]` — o leitor PRESENTE e quebrado, contra `run-gates.sh` e contra `spec-verify.sh`. Cenários novos da revisão 3, e a substância do bloqueador Novo 2 procede mesmo com a medição dele refutada (§2.3, Decisão 3).** `[14]` e `[15]` cobrem o modo *função ausente* — a lib de `15ce493^`, onde a substituição de comando devolve 127; confirmado nesta rodada: `git show '15ce493^:template/.forge/scripts/lib/forge-runtime.sh'` tem **50** linhas, **0** ocorrências de `forge_runtime_gate_entries` e **0** de `forge_runtime_gates_phase`, contra **4** de `forge_get_runtime`. Nenhum dos dois cobre o modo que §2.2 nomeia como o do sítio `lib/forge-runtime.sh:87` — *leitor presente mas com crash* —, que hoje só é exercitado por `[13]`, e só pelo `pre-push`, que chama `forge_runtime_gate_entries` direto e não passa por `forge_runtime_gates_phase`.

Os dois cenários usam a fixture de `[12]` com a lib **de hoje** e o `gate-phase.mjs` substituído por um arquivo que sai diferente de zero — o mesmo construto de `[13]`, que é manipulação de arquivo e roda em qualquer máquina. `[14b]` chama `bash .forge/scripts/run-gates.sh <id>` e `[15b]` chama `bash .forge/scripts/spec-verify.sh <change-id>`; as asserções são as mesmas de `[14]` e `[15]`, respectivamente, com uma a mais em cada: a saída **não** contém `NO-GATES` (em `[14b]`) e **não** contém `(no checks declared in FORGE.md runtime: — skipping check phase)` (em `[15b]`).

*Como falham hoje:* o `2>/dev/null || true` de `forge-runtime.sh:87` engole o rc do `node`, o leitor devolve lista vazia com rc 0, e os dois chamadores seguem como se a declaração fosse vazia — exatamente o desfecho de `[13]` no `pre-push`, agora nos dois chamadores que produzem wave fechada e evidência arquivada. É vermelho por ausência de funcionalidade, não por fixture.

**E os dois são o controle da decisão nova de §2.3.** Uma implementação que se apoiasse no `pipefail` do chamador ficaria verde aqui **hoje** e vermelha no dia em que alguém trocasse as opções de `run-gates.sh` — por isso a prova de discriminação que §2.3 exige do implementador roda também num chamador com `set -u` puro, e não só nos dois reais.

### 2.5 Prova de mutação

Alvo: `template/.forge/hooks/git/pre-push` e `template/.forge/scripts/lib/forge-runtime.sh`.

Protocolo, com o cuidado de LDG-0164 e de `feedback-mutacao-fantasma-restore` — **nunca** `perl -0pi -e` com `$` do lado direito, que em perl é variável vazia e transforma a mutação em `cp "" ""`:

1. `sha_antes=$(shasum -a 256 <alvo> | awk '{print $1}')`, gravado. **Prescrição executada nesta rodada**, para que ela não seja mais uma que a spec escreve sem rodar: `shasum -a 256 template/.forge/scripts/check-secrets.sh | awk '{print $1}'` devolve `7fb579226aca819c4db0d4114c5bf124ada5b36cc4f56a4fa5323505bd901937` — um digest de 64 hex por linha, disponível no macOS sem instalar nada, que é a única coisa que o protocolo precisa dele.
2. **Propriedade, não primitivo:** a mutação é aplicada por **substituição integral** do arquivo a partir de uma cópia preparada em `$TMPDIR`, nunca por edição in-place com interpolação de shell ou de perl. O conteúdo da mutação, aqui, é restaurar o `|| true` na linha 431 e remover a comparação de contradição. O primitivo é de quem executa; a obrigação é o passo 3, que prova que a substituição de fato ocorreu — `perl -0pi -e` com `$` do lado direito, que em perl é variável vazia e transforma a mutação em `cp "" ""`, é o caso de LDG-0164 e é o que o passo 3 pega.
3. `sha_mutado=$(shasum -a 256 <alvo> | awk '{print $1}')`; **asserção de controle da própria mutação**: `[ "$sha_mutado" != "$sha_antes" ]`. Sem ela, uma mutação que não mutou faz o passo 4 medir o engano — o defeito exato de LDG-0164.
4. Rodar `w190[12]` contra a árvore mutada e exigir **FAIL**, com a mensagem que a asserção declara. Um FAIL por outra mensagem não conta.
5. Restaurar por `cp` da cópia íntegra; `sha_depois`; asserção `[ "$sha_depois" = "$sha_antes" ]`.
6. **Recontrole:** rodar `w190[12]` de novo e exigir **PASS**. Sem o passo 6 a prova não vale — é o caso registrado em `feedback-mutacao-fantasma-restore`, em que um `restore()` quebrado deixou a mutação eterna e ninguém viu.

O alvo da mutação é arquivo **rastreado**, então o gate copia a árvore inteira para `$TMPDIR` e muta a cópia. Isso não é preciosismo: LDG-0175 registra um gate desta suíte que usou arquivo rastreado e distribuído como fixture, não restaurou, e foi encontrado com o arquivo de 70 linhas reduzido a um stub de 3.

### 2.6 Contador de controle — duas constantes, porque um dos cenários é ambiental

`w190` já tem `SCEN`, e a versão anterior desta seção mandava trocar a régua atual (`forge_universe_check`, que só reprova em zero) por "o total nominal fixo", sem olhar para o que o `w190` faz hoje. A revisão 1 mediu o problema e ele procede: **existe um incremento de `SCEN` condicionado ao AMBIENTE**, e um denominador fixo cru transformaria o gate em vermelho fabricado.

Remedi, e a contagem é esta. `grep -n 'SCEN=\$((SCEN + 1))' tests/w190-pre-push-gate-reader-gate.sh` devolve 13 sítios; `sed -n '176,190p;219,245p'` mostra a estrutura de cada um. Dos 13:

- **11 são incondicionais** (linhas 149, 156, 163, 174, 203, 260, 276, 288, 300, 314, 325), reconhecíveis por estarem à margem esquerda.
- **1 está dentro de um `for form in csv seq`** (linha 189, indentado com 2 espaços) e, portanto, incrementa **sempre 2** — o laço não tem `continue` nem `break` condicional. Não é ambiental.
- **1 é ambiental** (linha 240, indentado com 4 espaços): o `[6b]` só chega lá se a máquina permitir montar um `PATH` sem `node` (guarda da linha 219) **e** se o bloqueio observado tiver sido o da guarda do leitor (guarda da linha 239).

Total nominal de hoje: **13 obrigatórios + 1 ambiental = 14**. Hoje isso é inofensivo porque a asserção final é `forge_universe_check "w190/cenarios" "$SCEN" …` (linha 331), que só reprova em zero — confirmado lendo `lib/gate-universe.sh:62-65`, cujo ramo `[ "$count" -gt 0 ]` devolve `OK` e retorna 0.

**Decisão fechada:** o gate passa a declarar **duas constantes escritas no arquivo**, e nenhuma delas é derivada do que rodou:

```sh
SCEN_MIN=20          # obrigatórios: 13 de hoje (11 + os 2 do laço csv/seq) + [12] [12c] [13] [14] [14b] [15] [15b]
SCEN_AMB_NOMINAL=1   # dependem do ambiente: [6b], e só ele
```

Com os sete cenários novos de §2.4 (`[12]`, `[12c]`, `[13]`, `[14]`, `[14b]`, `[15]`, `[15b]`), `SCEN_MIN` passa de 13 para **20** e `SCEN_AMB_NOMINAL` continua **1** — nenhum dos sete novos depende do ambiente, porque nenhum deles remove `node` do `PATH` (todos operam trocando a **lib** ou o **`gate-phase.mjs`**, que é manipulação de arquivo, não de ambiente). Os dois últimos, `[14b]` e `[15b]`, entraram na revisão 3 e são os que exercitam o leitor **presente e quebrado** contra `run-gates.sh` e `spec-verify.sh`. O gate mantém dois contadores separados, `SCEN` e `SCEN_AMB`, e encerra com:

- `[ "$SCEN" -eq "$SCEN_MIN" ]` — reprova quando qualquer cenário obrigatório não rodou, com a mensagem que manda remedir e atualizar a constante.
- quando `SCEN_AMB` é menor que `SCEN_AMB_NOMINAL`, o gate imprime `INCONCLUSIVO w190/[6b] capacidade=ambiental — não foi possível montar um PATH sem 'node' nesta máquina; [6a] prova a guarda pelo mesmo canal real` e **não** reprova. É o vocabulário da própria onda aplicado ao seu próprio gate, que é o mínimo de coerência exigível.

**E `[6b]` precisa ser reescrito nesta onda, senão `SCEN_AMB` fica em zero para sempre e a linha acima vira ruído permanente em vez de sinal.** Medido: hoje `w190:239-247` só incrementa `SCEN` quando a saída casa `não pôde ser lida`, e cai num `SKIP` declarado quando outro check bloqueia antes — o comentário de `w190:228-229` registra que, sem `node`, quem bloqueia primeiro é `check-ai-attribution.sh`, "que invoca `node`, falha fechado e ainda reporta 'assinatura de IA detectada' — um diagnóstico falso, sobre um commit limpo". Essa antecipação **não desaparece** com a onda; §4.5 diz em letra que ela continua, agora com `INCONCLUSIVO` no lugar da acusação falsa. Se `[6b]` continuasse exigindo que o bloqueio fosse o da guarda do leitor, ele cairia no `SKIP` interno em **toda** execução, `SCEN_AMB` seria sempre 0 e o gate imprimiria a linha de ambiental numa máquina em que o `PATH` montou perfeitamente. **Decisão:** `[6b]` passa a afirmar o invariante que §4.5 já declara como o verdadeiro — *sem `node` o push é recusado, e a recusa nomeia a capacidade ausente (`INCONCLUSIVO`), em vez de imputar uma violação inexistente* — mantendo as duas asserções que ele já tem (`rc6b -ne 0` e a presença de `BLOQUEADO`, preservada pela composição de linha decidida em §2.3) e acrescentando a negativa `não contém 'assinatura de IA detectada'`. Com essa redação o cenário volta a **contar**, e o único motivo de não contar passa a ser o `PATH` não montar — que é o ambiental legítimo que `SCEN_AMB` existe para registrar. O isolamento da guarda do leitor permanece com `[6a]`, que é onde ele sempre esteve.

**A alternativa que a revisão 1 sugeriu foi medida e REFUTADA.** A sugestão era trocar a remoção do binário do `PATH` por "um wrapper `node` que sai 127". Medido:

```
$ mkdir -p "$T/shim"; printf '#!/bin/sh\nexit 127\n' > "$T/shim/node"; chmod +x "$T/shim/node"
$ PATH="$T/shim:$NB" bash -c 'command -v node'    # → /…/shim/node, rc=0
$ PATH="$T/shim:$NB" bash -c 'node --version'     # → rc=127
```

Com o wrapper, `command -v node` **encontra** `node` e devolve rc 0 — ou seja, o wrapper não reproduz o predicado que o `[6b]` testa (`node` ausente do `PATH`), e sim um predicado **diferente** (`node` presente e quebrado), que é justamente o de `[13]` e o de `w120[12]`. Substituir um pelo outro trocaria a asserção calada, que é a classe de defeito desta onda. O mecanismo de scrub do `PATH` fica.

E ele funciona nesta máquina, medido três vezes na mesma bancada, reconstruindo o `$NB` do `w190:205-218` (2185 links) e repetindo o predicado da linha 219: `run1: PATH sem node MONTADO`, `run2: PATH sem node MONTADO`, `run3: PATH sem node MONTADO` — três de três. O `SCEN_AMB` existe para o parque de máquinas onde ele não montar, não para esta.

---

## 3. Item 2 — issue #106: `runtime.test` é texto livre sem guarda de cobertura

### 3.1 O defeito, reproduzido

O `pre-push` executa o comando declarado e nada mais: `template/.forge/hooks/git/pre-push:325` é `run_check "test" "$(fm_field test)"`. Não há confronto com a superfície do repositório — `grep -rn 'sln\|csproj' template/.forge/hooks/` devolve **2** ocorrências, ambas em `pre-tool-use/` e ambas sobre nomes de arquivo, nenhuma sobre cobertura de teste.

**Bancada.** Repositório em `$TMPDIR` com `git init`, **2** arquivos `.sln` e **5** `.csproj` (`git ls-files '*.sln' | wc -l` → 2; `'*.csproj'` → 5), um `pnpm-workspace.yaml` que declara só `packages/*`, um `packages/web` com teste que passa, e `.forge/FORGE.md` com `runtime.test: pnpm test`. A sonda é o bloco das linhas 184-221 do `pre-push` — `fm_field`, `gate_deps_ready` e `run_check`, extraídos por `sed` sem edição — seguido da chamada real `run_check "test" "$(fm_field test)"`.

Saída literal:

```
pre-push: test OK
SONDA: rc do bloco = 0
EXIT=0
```

Verde, com 2 solutions e 5 projetos que o comando declarado não alcança por construção.

**Duas variantes da mesma função, medidas na mesma bancada.** `run_check` tem outros dois desfechos que dizem "não verifiquei" com a voz de quem verificou:

```
# runtime.test vazio
pre-push: test não definido — skip
EXIT=0

# test: pnpm test, sem node_modules
pre-push: test PULADO — node_modules/ ausente (rode 'pnpm install' ou deixe para /forge:verify)
EXIT=0
```

São `pre-push:206` e `pre-push:207-210`. Nenhum dos três desfechos carrega um token que distinga cobertura de ausência de cobertura num log.

**Uma quarta cópia, no artefato de evidência.** `template/.forge/scripts/spec-verify.sh:52-66` tem um `run_check` próprio que produz `passed|failed` e é chamado por `[ -n "$cmd" ] && run_check "$check" "$cmd"` — comando vazio some do `CHECKS_YAML` inteiro, e o `verification.yaml` de um change sem comando de teste declarado simplesmente não tem a entrada, sem dizer por quê.

### 3.2 Confirmação independente do campo

A issue mede quatro consumidores. Remedi hoje. A revisão 1 mediu que a coluna `gradle` da versão anterior desta tabela **não reproduzia com glob nenhum** — e ela tinha razão: o número vinha de um glob que a spec não citava. A correção não é redigir melhor, é fixar o glob de cada classe **no texto**, porque é ele que `check-test-surface.sh` vai implementar. O comando é literalmente este, por repositório:

```sh
git -C <repo> ls-files '*.sln'                                   # dotnet, solutions
git -C <repo> ls-files '*.csproj'                                # dotnet, projetos
git -C <repo> ls-files '*build.gradle' '*build.gradle.kts' '*pom.xml'   # jvm
git -C <repo> ls-files '*pyproject.toml' '*setup.py'             # python
git -C <repo> ls-files '*go.mod'                                 # go
git -C <repo> ls-files '*package.json'                           # node
```

| Repositório | sln | csproj | jvm | python | go | node | `runtime.test` declarado |
|---|---|---|---|---|---|---|---|
| `axis-go-cloud` | 24 | 261 | 0 | 0 | 0 | 7 | `pnpm test` |
| `axis-fare-validator` | 0 | 0 | 4 | 0 | 0 | 0 | `./gradlew-jdk11.sh :app:testDevDebugUnitTest …` |
| `azim-crm` | 1 | 260 | 0 | 4 | 0 | 61 | `dotnet test …` (5 projetos) |
| `Axis.PadSimulator` | 1 | 8 | 0 | 0 | 0 | 1 | `dotnet test backend/AxisPadSimulator.sln … && pnpm --dir frontend test` |

**Por que os números da revisão 1 divergem dos meus, e por que o glob dela é o errado para esta guarda.** A revisão mediu `git -C ~/Documents/projects/axis-fare-validator ls-files '*.gradle'` → **5** e `git -C ~/Documents/projects/axis-go-cloud ls-files '*.gradle*'` → **18**. Os dois números reproduzem, e os dois são inúteis como sinal de classe JVM presente, medido:

```
$ git -C ~/Documents/projects/axis-fare-validator ls-files '*.gradle'
app/build.gradle
build.gradle
companion-app/build.gradle
settings.gradle          ← não é módulo: é o arquivo de agregação
tools/simulator/build.gradle

$ git -C ~/Documents/projects/axis-go-cloud ls-files '*.gradle*' | head -3
docs/t10-validator/SCR916_20241113_v1.9/src/MinimalAipaClient/.gradle/8.2/checksums/checksums.lock
docs/t10-validator/SCR916_20241113_v1.9/src/MinimalAipaClient/.gradle/8.2/checksums/md5-checksums.bin
docs/t10-validator/SCR916_20241113_v1.9/src/MinimalAipaClient/.gradle/8.2/checksums/sha1-checksums.bin
```

As 18 do `axis-go-cloud` são, **todas**, cache de build de um Gradle 8.2 dentro de um diretório `.gradle/` versionado por engano sob `docs/` — nenhuma é um script de build, e o repositório não tem projeto JVM. Contar `*.gradle*` faria a guarda anunciar uma classe JVM inexistente no consumidor que ela precisa acusar por outro motivo, e um falso positivo numa guarda nova é a via mais curta para ela ser desligada (§3.3, decisão de granularidade). O glob `'*build.gradle' '*build.gradle.kts' '*pom.xml'` devolve **4** no `axis-fare-validator` (os quatro módulos, sem o `settings.gradle`) e **0** no `axis-go-cloud`, que é a leitura correta dos dois.

O `axis-go-cloud` reproduz o achado: 24 solutions e 261 projetos, e um comando de teste que o `package.json` resolve para o filtro de workspace. Os outros três declararam de forma que alcança a classe presente. O par de controle que a issue exige — vermelho contra o primeiro, verde contra os demais — existe e é medível na máquina.

O `azim-crm` é o caso que fixa a granularidade: 260 `.csproj` e cinco projetos de teste nomeados. Uma guarda por **projeto** o acusaria, e ele está certo.

### 3.3 A seção "O que resolveria" da issue: adotada no mecanismo, recusada na colocação e na severidade

**Adotado:** enumerar a superfície presente, confrontar com o comando declarado, e falar quando uma **classe inteira** ficar com zero.

**Recusado — a colocação inline no hook.** A issue mostra o `case`/`git ls-files` dentro do `pre-push`. Recusado por três razões: seria a **quarta** cópia de enumeração de superfície no template (`lib/discover-lite.mjs`, `doctor.sh:509` via `find_marker`, `dotnet-baseline.sh:56`), e LDG-0152 existe por causa da terceira cópia de outra coisa; um fragmento de hook não pode ser declarado em `runtime.gates` nem executado por um consumidor que queira diagnosticar; e não há como testá-lo sem montar o canal de push inteiro. **Decisão:** nasce `template/.forge/scripts/check-test-surface.sh`, invocado pelo `pre-push`.

Do bloco `SHELL_LINTS` a onda herda **uma** coisa e só uma: a **guarda de delegação em alvo ausente** de `pre-push:306-313` — script declarado e ausente em disco é erro, e não silêncio. O tratamento de rc de `pre-push:314-318` **não** é herdado, e a versão anterior desta spec errou ao dizer "o padrão que `SHELL_LINTS` (linhas 300-321) já usa" sem essa distinção: medido, `sed -n '314,318p' template/.forge/hooks/git/pre-push` mostra `if ! _lint_out="$(… bash "$_s" …)"; then … exit 1; fi`, que **bloqueia em qualquer rc diferente de zero** — exatamente o oposto do que a decisão de severidade abaixo exige para o rc 5. (As linhas também derivaram: o bloco é 306-320, não 300-321.)

**Recusado — "aviso já resolve".** Um aviso sem token é o mesmo silêncio com mais linhas. **Decisão:** o desfecho de superfície descoberta é `INCONCLUSIVO test-surface capacidade=ambiental — …`, no vocabulário de §1.1, com **rc 5**; o `pre-push` imprime e **não bloqueia**, porque a declaração pode ser deliberada e porque a superfície descoberta é ambiental. A diferença em relação ao aviso da issue é que o estado passa a ser greppável, contável e transportável para o `verification.yaml`.

**Decisão — a tabela completa de rc → ação do `pre-push` para `check-test-surface.sh`.** A revisão 1 mediu que o mesmo gate, na mesma fase, produz o terceiro estado por duas causas que exigem severidades opostas, e que a spec não dizia como o hook decide. É a decisão que faltava, e ela é esta — nenhuma linha fica implícita, e o ramo `*` é fail-closed:

| rc do gate | Significado | O que o `pre-push` faz |
|---|---|---|
| 0 | examinei todas as classes presentes e o comando declarado alcança cada uma | imprime `pre-push: test-surface OK — N classe(s) examinada(s)`, segue |
| 1 | violação encontrada | **bloqueia** — este gate não emite 1 hoje, e um 1 vindo dele é contrato quebrado, que não pode virar verde |
| 2 | uso incorreto do próprio gate (argumento inválido) | **bloqueia** — é defeito de fiação do hook, e o hook é quem fia |
| 4 | inconclusivo, capacidade **dura** (`node` ausente, `lib/test-surface.mjs` ausente) | **bloqueia**, §1.2, com a linha `INCONCLUSIVO … capacidade=dura` e a saída (`npx forge-harness update` / instale Node) |
| 5 | inconclusivo, capacidade **ambiental** (classe presente e não alcançada pelo comando declarado) | **imprime e segue** — a declaração pode ser deliberada |
| qualquer outro | desconhecido | **bloqueia**, nomeando o rc — rc que o hook não conhece nunca vira verde |

O discriminante entre as linhas de rc 4 e rc 5 não é a fase e não é heurística de mensagem: é o rc que o próprio gate escolhe ao chamar `forge_verdict_require <chave> dura …` ou `forge_verdict_require <chave> ambiental …` (§1.2 e §1.4). O `pre-push` lê `forge_verdict_kind "$rc"` e ramifica sobre `dura`/`ambiental`, sem reimplementar a tabela.

**Forma da linha quando o `pre-push` BLOQUEIA por capacidade dura — decisão fechada, e ela existe para não quebrar um quinto gate que a varredura de strings encontrou.** A linha compõe os dois vocabulários, nesta ordem: `pre-push BLOQUEADO: INCONCLUSIVO <chave> capacidade=dura — <capacidade> ausente (<como obter>)`. Motivo medido: `tests/w190-pre-push-gate-reader-gate.sh:238` exige `grep -q "BLOQUEADO" "$T/out.txt"` sobre um push com `node` fora do `PATH`, e depois da onda quem bloqueia primeiro nesse cenário continua sendo `check-ai-attribution.sh` (§4.5). Uma linha que trocasse `BLOQUEADO` por `INCONCLUSIVO` deixaria `w190[6b]` vermelho; uma que só dissesse `BLOQUEADO` perderia o token que a onda existe para criar. A composição preserva os dois, e é coerente com as linhas 99, 118 e 139 do próprio arquivo, todas na forma `pre-push BLOQUEADO: <o quê>`. O `commit-msg` usa a mesma composição, que é o que `w120[16]` afirma.

**Decisão — `run_check` do `pre-push` ganha os mesmos três desfechos, com token próprio.** Medido, hoje ele tem três saídas e nenhum token as separa num log: `sed -n '204,220p' template/.forge/hooks/git/pre-push` mostra `pre-push: $label não definido — skip` (linha 206, rc 0), `pre-push: $label PULADO — node_modules/ ausente (…)` (linha 208, rc 0) e `pre-push: $label OK` (linha 215, rc 0). As duas primeiras são "não verifiquei" com a voz de quem verificou. `run_check` passa a imprimir:

| Situação | Linha de hoje | Linha nova | rc |
|---|---|---|---|
| `runtime.<label>` não declarado | `pre-push: test não definido — skip` | `pre-push: INCONCLUSIVO test capacidade=ambiental — runtime.test não declarado no FORGE.md` | 0 (não bloqueia: campo vazio é o estado de fábrica) |
| dependências ausentes | `pre-push: test PULADO — node_modules/ ausente (…)` | `pre-push: INCONCLUSIVO test capacidade=ambiental — node_modules/ ausente (rode 'pnpm install' ou deixe para /forge:verify)` | 0 |
| comando rodou e passou | `pre-push: test OK` | `pre-push: test OK — comando declarado executado` | 0 |
| comando rodou e falhou | `pre-push BLOQUEADO: test falhou — tail:` | inalterado | 1 |

**A linha verde conserva a ordem `<label> OK`, e a revisão 2 tem razão em cobrar isso — a versão anterior desta tabela escrevia `OK test`, e essa inversão não era exigida por nada.** Duas medições a derrubam. A primeira é de gate: `tests/w135-push-refs-export-gate.sh:149-150` exige `grep -q 'typecheck OK'` e `grep -q 'test OK'` sobre a saída de um push de mais de 1,2 MB, e a forma invertida não contém nenhuma das duas substrings, enquanto a forma conservada contém — medido literalmente, `grep -q 'test OK'` casa `pre-push: test OK — comando declarado executado` e **não** casa `pre-push: OK test — comando declarado executado`. A segunda é de vocabulário interno: `pre-push:320` já imprime `pre-push: shell-lints OK — $_sh_n arquivo(s) .sh varrido(s)`, ou seja, a forma `<label> OK — <detalhe>` é o precedente do próprio arquivo, e a invertida seria a única linha do `pre-push` com o token antes do rótulo. O token que a onda precisa criar é `INCONCLUSIVO`, e ele nasce no início do corpo da linha; `OK` já existia e não estava ambíguo.

**A troca da linha de `PULADO` edita `tests/w97-hook-portability-gate.sh` `[3]` junto, e as DUAS asserções dele, não só a positiva.** Medido: `w97:44` é `grep -q 'typecheck PULADO' <<<"$out"` (positiva, sem `node_modules`) e `w97:50` é `grep -q 'typecheck PULADO' <<<"$out2" && FAIL` (negativa, com `node_modules`); o gate usa o hook de produção (`HOOKS="$WS/template/.forge/hooks"`, `cp "$HOOKS/git/pre-push"` em `w97:32`). Se só a positiva fosse migrada, a negativa passaria a ser satisfeita por vacuidade — a string `PULADO` deixaria de existir no arquivo e o `grep` nunca casaria, em nenhum estado. Uma asserção negativa que ninguém pode falhar é o falso-verde desta onda dentro do gate que a onda edita. As duas migram para `INCONCLUSIVO typecheck`: a de `w97:44` passa a exigir `grep -q 'INCONCLUSIVO typecheck'` e a de `w97:50` passa a reprovar quando `INCONCLUSIVO typecheck` aparece com `node_modules` presente.

`run_check` serve `typecheck` e `test` (`pre-push:324-325`), e a mudança vale para os dois — o defeito é da função, não do campo. Nenhum desfecho muda de severidade: a onda troca o vocabulário e o torna greppável, e não altera quem publica hoje.

**Decisão — a deliberação é declarada, não presumida.** Um consumidor que decidiu não cobrir uma classe registra em `.forge/empty-universe-allowlist.txt`, no formato que o arquivo já impõe, com a chave `test-surface:<classe>` e `# motivo:` obrigatório. Reaproveita `forge_universe_waiver` de `lib/gate-universe.sh:31-52`, cujo contrato é exatamente "ecoa a justificativa, rc sempre 0 — quem decide é o chamador". *Alternativa descartada:* arquivo de allowlist novo. Descartada porque duplicaria o parser e a superfície de revisão da mesma disciplina — a classe de LDG-0152 outra vez.

**E o cabeçalho da allowlist é editado nesta onda, não herdado em silêncio.** A ressalva da revisão 1 procede e a medição a sustenta: `sed -n '1,32p' template/.forge/empty-universe-allowlist.txt` mostra um cabeçalho que documenta **um** contrato — *"justificativas para universo VAZIO em gates que iteram"*, *"não encontrei violação"* contra *"não examinei nada"* — e a chave `test-surface:<classe>` traz um contrato **diferente**: *classe presente, examinada, e deliberadamente não coberta pelo comando declarado*. Um arquivo com dois contratos e um cabeçalho só é exatamente o tipo de herança silenciosa que `project-strix-pentest-profile` registra. A onda acrescenta ao cabeçalho: (a) a chave `test-surface:<classe>` na lista de gate-keys das linhas 20-28, com a glosa da semântica nova; (b) um parágrafo curto dizendo que a partir daqui a allowlist cobre **dois** estados declaráveis — universo vazio e classe presente não coberta — e que os dois compartilham a mesma exigência de `# motivo:`. A asserção de que o cabeçalho foi editado vive em `[4]`, que cita o motivo declarado de volta na saída.

**Decisão — granularidade de CLASSE, nunca de projeto.** A guarda responde "o comando declarado invoca, em algum ponto, a toolchain de uma classe presente no repositório?". Não responde "cobre todos os projetos". Justificativa medida: `azim-crm` declara `dotnet test` para 5 projetos de 260 `.csproj`, e está correto; uma guarda por projeto produziria ruído em um dos quatro consumidores e seria desligada na primeira semana. Isto fica escrito no cabeçalho do gate, para que ninguém o "melhore" depois sem saber o que está trocando.

**Decisão — a enumeração usa `git ls-files`, não `find`.** Determinístico, respeita `.gitignore`, e não replica o padrão `find … | head -1` de `doctor.sh:62-65`, que é a forma que o campo já sinalizou como frágil na thread `find-sem-quit-mata-o-script-na-linha-da-recusa`. *Alternativa descartada:* reaproveitar `lib/discover-lite.mjs`. **A justificativa anterior estava errada e a revisão 1 acertou ao apontá-la; remedi e ela cai por completo.** A versão anterior dizia que o `discover-lite` "reportaria `sln=0` exatamente no consumidor que tem o defeito". Medido: `git -C ~/Documents/projects/axis-go-cloud ls-files '*.sln' | awk -F/ '{print NF-1}' | sort -n | uniq -c` devolve `2` solutions na **raiz** e `22` a dois níveis; e `sed -n '47,48p' template/.forge/scripts/lib/discover-lite.mjs` mostra que a linha 47 já casa qualquer `.sln` de `topFiles`. Ou seja, o `discover-lite` **detectaria** a stack `dotnet` no `axis-go-cloud`, pelas duas solutions da raiz. A afirmação era falsa.

A decisão de não reaproveitá-lo continua de pé, por um motivo diferente e este sim medido: `discover-lite` **não conta nada**. Lendo `lib/discover-lite.mjs:34-75`, cada classe termina em `stack.push('<nome>')` — um rótulo booleano de presença — e em `commands.test = commands.test || '<comando sugerido>'`. Não existe cardinalidade em lugar nenhum do arquivo. A mensagem que §3.4 `[1]` exige (`2 solution(s)` e `5 projeto(s)`) e o contador por classe de §3.6 pedem exatamente a cardinalidade que ele não produz, e ele ainda enxerga apenas raiz e um nível (`topDirs.some(... readdirSync ...)`, linha 48), enquanto 22 das 24 solutions do `axis-go-cloud` estão a dois níveis. Reaproveitá-lo obrigaria a reescrevê-lo por dentro, num arquivo com consumidor instalado — que é o risco que §1.4 recusa por princípio.

**Decisão — o classificador é `.mjs` puro, o contador é bash.** `check-test-surface.sh` conta arquivos por classe com `git ls-files` em bash e delega a classificação do comando declarado a `template/.forge/scripts/lib/test-surface.mjs`, módulo sem I/O e zero-dep, no mesmo molde de `lib/ai-attribution.mjs` (que se declara *"Zero-dep (só builtins). Sem I/O"*). Motivo: o classificador é a única parte com espaço de entrada, e PBT sobre módulo node é o padrão desta suíte — os três gates que hoje usam `lib/pbt.mjs` (`w121`, `w130`, `w132`) o exercitam sobre `.mjs`, e não existe precedente de PBT dirigindo bash por processo. Consequência aceita e assertada: sem `node`, `check-test-surface.sh` responde `INCONCLUSIVO` — o que é o comportamento correto sob o vocabulário da própria onda, e vira asserção do gate.

### 3.4 O vermelho, antes do verde

Gate novo, ordinal alocado pelo orquestrador (§8).

**`[1]` — vermelho principal, pelo canal real.** Fixture de §3.6 — 2 `.sln`, 5 `.csproj`, 1 `package.json`, nada mais —, `test:` que **sai 0** sem nomear toolchain nenhuma, e push de verdade contra remoto `--bare` com `core.hooksPath` absoluto. Asserções: o push termina rc **0** (o comando declarado passa — a fixture não pode confundir o vermelho com falha de teste) **e** existe **uma única linha** que contém, ao mesmo tempo, `INCONCLUSIVO test-surface`, a classe `dotnet`, a contagem `2 solution(s)` e a contagem `5 projeto(s)`.

**A asserção é sobre uma linha, nunca sobre a saída agregada, e isto é correção da revisão 3 por varredura própria — nenhuma revisão a nomeou.** §3.6 decide que a produção publica o vetor de classes **sempre**, e o vetor da fixture de `[1]` contém literalmente `dotnet=2 solution(s)/5 projeto(s)` — está medido na bancada colada em §3.5, na linha `ÍNTEGRO`, nos dois estados. Uma asserção escrita como "a saída contém `2 solution(s)`" seria satisfeita pela linha do vetor mesmo quando a linha `INCONCLUSIVO test-surface` tivesse desaparecido, que é exatamente o que a mutação 1 de §3.5 produz: o classificador passa a "cobrir" dotnet, a linha de inconclusivo some, e o vetor continua publicando `2 solution(s)` porque o contador não foi tocado. A matriz de §3.5 declara que a mutação 1 derruba `[1]`; com a asserção agregada ela não derrubaria, e a linha da matriz seria falsa. Ancorar na linha única é o que faz o contrafactual valer.

*Como falha hoje:* o push termina rc 0 e a saída contém `pre-push: test OK` e mais nada sobre superfície — medido em §3.1, na sonda que executa o bloco real do hook. Falha pela ausência da funcionalidade: `ls template/.forge/scripts/check-test-surface.sh` não existe, e nenhuma linha do `pre-push` enumera superfície. A asserção é sobre **saída de um push verde**, não sobre a existência de um arquivo — um vermelho comportamental, não um vermelho de `No such file`.

**Por que uma linha impressa e não bloqueante muda o desfecho onde a suíte vermelha não mudou — a ressalva da revisão 1, respondida.** A ressalva é justa e merece letra: o dano de #106 é *"19 dias com suíte vermelha invisível, 21 de 21 testes reprovando"*, e o canal que ficou invisível foi a saída do `pre-push`. Uma linha a mais no mesmo canal, sozinha, não é obviamente diferente. A diferença é que **a linha não é a peça que fecha #106** — ela é o sintoma legível. As três peças que fecham são, em ordem de força:

1. **A allowlist.** Uma classe presente e não coberta só para de aparecer quando alguém escreve `test-surface:<classe>  # motivo: …` num arquivo versionado, com nome no `git blame` e revisão de PR (`[4]` e `[5]`). Enquanto ninguém escrever, a linha reaparece a **cada push**, para sempre — o que a suíte vermelha, essa sim, não fazia: ela era um estado silencioso que ninguém tinha de declarar para conviver com ele.
2. **O transporte para o `verification.yaml`** (§6, contrato 2). O estado sai do terminal e entra no artefato de evidência do change, que o `/forge:archive` lê e o revisor humano abre. Foi a ausência desse transporte que deixou 19 dias passarem: nada além do scrollback carregava o fato.
3. **O gate.** `[1]`-`[9]` (com `[6]` desdobrado em `[6a]` e `[6b]`, §3.4) moram na suíte, e a suíte roda no CI: se a guarda for removida ou esvaziada, o gate morde — que é a única forma de o mecanismo não regredir para o silêncio de 2026.

O bloqueio no push foi deliberadamente **não** escolhido, e §3.3 diz por quê (a declaração pode ser deliberada, e um falso positivo numa guarda nova é a via mais curta para ela ser desligada). A onda troca "invisível" por "declarado ou repetido para sempre, e registrado no artefato" — não por "bloqueado".

**`[2]` — controle positivo pareado, com o comando alcançando as DUAS classes presentes.** A mesma fixture, mesmos `.sln`, `.csproj` e `package.json`, com `test: dotnet test app.sln && pnpm test` (as duas metades substituídas por stubs que saem 0). Asserção: o push passa e **não** há linha `INCONCLUSIVO test-surface`. Sem esse par, `[1]` não distingue "a guarda vê a lacuna" de "a guarda reclama sempre".

**O comando de `[2]` mudou na revisão 3, e o bloqueador Novo 3 procede inteiro — é contradição interna minha, da mesma forma do Novo 3 da revisão 2, só que na outra classe.** A versão anterior escrevia `test: dotnet test app.sln` e assertava ausência de **qualquer** linha `INCONCLUSIVO test-surface`. Mas §3.6 fixa a fixture com `1 package.json` e assere, em `[9]`, o vetor `node=1`: a classe `node` está **presente**, e a regra decidida em §3.3 é de classe — *falar quando uma classe inteira ficar com zero*. Um comando que só nomeia `dotnet` deixa `node` descoberta, a implementação **certa** emite `INCONCLUSIVO test-surface` sobre `node`, e `[2]` reprovaria o código correto — o controle positivo que existe para distinguir "a guarda vê a lacuna" de "a guarda reclama sempre" passaria a reprovar sempre. As duas saídas colidiam entre si: tirar o `package.json` da fixture quebra `VETOR_FIXTURE1` de `[9]` e o vetor colado em §3.5; mantê-lo obriga o comando a alcançar as duas classes. Escolhi a segunda, que preserva a fixture, o vetor de `[9]`, o pareamento com `[1]` e as três linhas da matriz de §3.5 que citam `[2]` — inclusive a leitura de que `[2]` passa nas três mutações, que continua verdadeira, porque nenhuma delas remove cobertura de uma classe que o comando de `[2]` alcança. O `pnpm test` é o mesmo precedente do `Axis.PadSimulator` na tabela de §3.2, que declara `dotnet test … && pnpm --dir frontend test` justamente para alcançar as duas classes que tem.

**`[3]` — controle negativo de classe ausente.** Repositório sem `.sln` e sem `.csproj`, com `test: pnpm test`. **A asserção foi reescrita na revisão 2, porque a anterior era impossível de ficar verde sobre a implementação certa.** A anterior dizia "nenhuma linha sobre `dotnet`", e §3.6 decide que o vetor é publicado inteiro, sempre, inclusive as classes com zero — o vetor correto naquela fixture contém `dotnet=0`, que é uma linha sobre `dotnet`. Pior do que reprovar o código certo: a terceira mutação de §3.5 declara `[3]` como a asserção que morde o vetor decorado, e uma asserção que reprova antes **e** depois da mutação não tem recontrole — é a mutação-fantasma de `feedback-mutacao-fantasma-restore` de cabeça para baixo.

Medido em bancada de `$TMPDIR`, com um contador protótipo e o mesmo contador mutado para publicar `dotnet=2 solution(s)/5 projeto(s)` literalmente, sobre uma fixture com `package.json` e sem nenhum `.sln`/`.csproj`:

```
ÍNTEGRO: test-surface: 5 classe(s) examinada(s); dotnet=0 solution(s)/0 projeto(s), node=1 package.json, jvm=0, python=0, go=0
MUTADO : test-surface: 5 classe(s) examinada(s); dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0

asserção ANTIGA ("nenhuma linha sobre dotnet"):  íntegro REPROVA · mutado REPROVA   ← sem recontrole
asserção NOVA  (as duas abaixo):                 íntegro PASSA   · mutado REPROVA   ← contrafactual medido
```

Asserções novas, as duas escritas em letra, uma positiva e uma negativa:

1. **positiva:** a saída contém, literalmente, `dotnet=0 solution(s)/0 projeto(s)` — a classe ausente é publicada como zero, e é isso que distingue "examinei e não há" de "não olhei";
2. **negativa:** a saída **não** contém nenhuma linha `INCONCLUSIVO test-surface` que mencione `dotnet` — a guarda não pode acusar cobertura faltando de uma classe que não existe no repositório.

*Como falha hoje:* `ls template/.forge/scripts/check-test-surface.sh` não existe e nenhuma linha do `pre-push` enumera superfície, então a positiva falha por ausência de funcionalidade.

**`[4]` — a deliberação declarada silencia com registro.** A fixture de `[1]` mais `.forge/empty-universe-allowlist.txt` com `test-surface:dotnet  # motivo: solutions cobertas pelo pipeline de release`. Asserção: a linha muda de `INCONCLUSIVO` para o estado de justificativa declarada, citando o motivo — nunca some. É a régua que `template/.forge/empty-universe-allowlist.txt:30-31` já aplica: *"Isentar um gate aqui não o silencia"*.

**`[5]` — entrada de allowlist sem `# motivo:` reprova.** Herda por construção o comportamento de `forge_universe_waiver`, e a asserção existe para provar que a herança de fato acontece — a lição de `project-strix-pentest-profile`: leitor novo de um arquivo com leitor canônico **herda** a regra, e a prova de que herdou é uma asserção, não uma intenção.

**`[6a]` — capacidade dura ausente por ARQUIVO, determinístico: `lib/test-surface.mjs` removido do disco.** Asserções: rc **4**, a linha contém `INCONCLUSIVO test-surface capacidade=dura`, nomeia `lib/test-surface.mjs`, e **não** contém nenhuma menção a classe descoberta — um gate que não conseguiu rodar não pode acusar cobertura faltando. Este cenário é **obrigatório** e roda em qualquer máquina: remover um arquivo é manipulação de disco, não de ambiente.

**`[6b]` — a mesma propriedade pelo predicado do binário: `PATH` sem `node`.** As mesmas asserções, com `node` no lugar do `.mjs`. Este é **ambiental** e conta em `SCEN_AMB` (§3.6). O mecanismo de `PATH` sem `node` é **um só** em toda a onda (`[6b]` aqui, `w120[11]` e `w120[16]`): o scrub de `$PATH` do `w190:205-218`, extraído para um helper compartilhado da suíte, com a medição de §2.6 que refuta a alternativa do wrapper e com o registro `SCEN_AMB` quando a máquina não permitir montá-lo. Três cópias do construto seriam três lugares onde o vermelho vira silêncio ambiental sem ninguém saber.

**Por que dois cenários e não um, decisão nova da revisão 2.** A versão anterior tinha só o de `PATH`, e com isso a única prova de que o gate responde `INCONCLUSIVO` em vez de acusar ficava refém de o helper conseguir montar o `PATH` naquela máquina — num parque onde ele não montar, a propriedade inteira deixava de ser afirmada e ninguém era avisado, porque um `SCEN_AMB` abaixo do nominal por desenho não reprova. Com `[6a]`, a propriedade tem prova obrigatória e determinística, e `[6b]` acrescenta o predicado do binário onde o ambiente permitir.

**`[7]` — as três variantes de `run_check` passam a falar.** `runtime.test` vazio, `pnpm test` sem `node_modules`, e comando que executa e passa. **A asserção foi reescrita na revisão 1, porque a anterior nascia VERDE**, e a medição que a derruba é esta: a asserção antiga era "três linhas distintas, e apenas a terceira contém `OK`", e `sed -n '206p;208p;215p' template/.forge/hooks/git/pre-push | grep -c 'OK'` devolve **1** — as três linhas de hoje já são distintas e só a terceira já contém `OK`. A asserção media a motivação, não o mecanismo, e teria passado sobre o defeito intacto.

Asserção nova, positiva, sobre o token que hoje **não existe**:

1. a execução com `runtime.test` vazio imprime uma linha que casa `INCONCLUSIVO test capacidade=ambiental` **e** nomeia a causa (`runtime.test não declarado`), e essa linha **não** contém `OK`;
2. a execução sem `node_modules` imprime uma linha que casa `INCONCLUSIVO test capacidade=ambiental` **e** nomeia a causa (`node_modules/ ausente`), e essa linha **não** contém `OK`;
3. a execução com comando que passa imprime uma linha contendo `test OK` (a forma conservada da tabela de §3.3, que é a que `w135[3]` afirma) e **nenhuma** linha que case `INCONCLUSIVO test capacidade=` — é a ausência do token novo na execução que de fato verificou que carrega o par anti-tautológico, e não a ordem das palavras na linha verde;

**A âncora da asserção (3) mudou na revisão 3, e a ressalva procede porque eu executei a prescrição.** A versão anterior pedia "nenhuma linha `INCONCLUSIVO test`", e essa substring casa também `INCONCLUSIVO test-surface`, que pode aparecer na **mesma** saída de push — `[7]` reprovaria a implementação certa toda vez que a fixture tivesse uma classe descoberta. Medido nesta rodada sobre a linha `pre-push: INCONCLUSIVO test-surface capacidade=ambiental — classe node`: `grep -q 'INCONCLUSIVO test'` **casa**; `grep -q 'INCONCLUSIVO test '` (com o espaço) **não** casa; `grep -q 'INCONCLUSIVO test capacidade='` **não** casa. A âncora escolhida é a terceira, que é a mesma forma das asserções (1) e (2) duas linhas acima — coerência interna, e não só correção.
4. as três terminam com rc 0 — a onda muda o vocabulário, não a severidade (§3.3, tabela de `run_check`).

*Como falha hoje:* `grep -c 'INCONCLUSIVO' template/.forge/hooks/git/pre-push` devolve **0**. Não existe uma única ocorrência do token no arquivo, então (1) e (2) falham por ausência de funcionalidade, e nenhuma reescrita de fixture as faria passar. A asserção (3) é o par anti-tautológico: sem ela, uma implementação que imprimisse `INCONCLUSIVO` sempre passaria em (1) e (2) e desligaria a distinção que a onda existe para criar.

A decisão que autoriza esta asserção está escrita em §3.3, na tabela de `run_check` — e é a segunda metade da correção da revisão 1: a versão anterior afirmava um comportamento novo em `[7]` sem que nenhuma decisão de §3.3 mandasse alterar `run_check`.

**`[8]` — PBT sobre o classificador.** Ver §6.

**`[9]` — contador de controle.** Ver §3.6.

### 3.5 Prova de mutação

Alvo: `template/.forge/scripts/lib/test-surface.mjs`. Mutação: a tabela de tokens da classe `dotnet` passa a casar a string vazia, o que faz **todo** comando ser classificado como cobrindo dotnet. Asserção sob mutação: `[1]` reprova por não encontrar a linha `INCONCLUSIVO test-surface`. Restauração e recontrole pelo protocolo de §2.5, com os três `sha256` e as duas comparações, incluindo a asserção de que a mutação de fato mutou.

Segunda mutação, sobre o contador e não sobre o classificador: `check-test-surface.sh` passa a contar `.sln` com um glob que não casa nada. **A asserção desta segunda mutação foi trocada na revisão 1, porque a anterior não podia falhar sob a mutação declarada.** A anterior dizia "o contador de controle de `[9]` reprova por denominador abaixo do esperado", e o denominador de §3.6, como estava escrito, era "5 classes e o total nominal de fixtures" — nenhum dos dois muda quando o glob de `.sln` para de casar: continuam 5 classes examinadas e o mesmo número de fixtures exercitadas. A mutação existia para distinguir "o classificador está certo" de "o contador olhou para alguma coisa" e, como escrita, não distinguia nada — a tautologia de LDG-0164 por outro caminho.

Asserção nova, sustentada pela mudança de §3.6 (o contador passa a publicar **por classe**) e com o efeito **medido em bancada**, não deduzido. Sobre uma fixture com 2 `.sln`, 5 `.csproj` e 1 `package.json`, trocando o glob `'*.sln'` por um que não casa nada:

```
ÍNTEGRO: test-surface: 5 classe(s) examinada(s); dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0
MUTADO : test-surface: 5 classe(s) examinada(s); dotnet=0 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0

[1] contém '2 solution(s)' :  íntegro SIM · mutado NÃO
[9] vetor bate o literal   :  íntegro SIM · mutado NÃO
```

Sob a mutação, `[1]` reprova porque a linha `INCONCLUSIVO test-surface` deixa de conter `2 solution(s)`, **e** `[9]` reprova porque o vetor publicado não bate com o literal declarado no gate. As duas falham por motivos diferentes e nenhuma é satisfeita pela outra: `[1]` mede a mensagem que o campo lê, `[9]` mede o denominador que o gate exige.

**Uma alternativa que a versão anterior desta spec oferecia é falsa, e a medição a derruba.** O texto anterior dizia que a linha `INCONCLUSIVO` poderia "sumir por a classe `dotnet` deixar de ser detectada". Medido acima, ela **não** some: com o glob de `.sln` cego, os 5 `.csproj` continuam presentes, a classe `dotnet` continua detectada e a linha continua sendo emitida, só que dizendo `dotnet=0 solution(s)/5 projeto(s)`. Deixar a alternativa escrita autorizaria um implementador a aceitar um FAIL por outra mensagem — que é o que o passo 4 do protocolo de §2.5 proíbe.

Terceira mutação, para separar contador de classificador na direção oposta: `lib/test-surface.mjs` continua íntegro e `check-test-surface.sh` passa a publicar o vetor por classe com valores **fixos** (`dotnet=2 solution(s)/5 projeto(s)` escrito literalmente, em vez de contado). Asserção: `[3]` reprova pela sua asserção **positiva** — o repositório sem `.sln` e sem `.csproj` deixa de publicar `dotnet=0 solution(s)/0 projeto(s)` e passa a publicar `dotnet=2 solution(s)/5 projeto(s)`, um número decorado sobre um repositório que não tem dotnet. Contrafactual medido em §3.4 `[3]`: íntegro PASSA, mutado REPROVA — os dois estados distinguíveis, que é o que faltava. Sem esta terceira, um contador que decorasse a fixture passaria em `[1]`, `[2]` e `[9]`.

**Matriz das três mutações, cada linha com o efeito medido na bancada e não deduzido.** As colunas dizem o que acontece com cada cenário sob a mutação; `=` significa que o cenário tem o mesmo desfecho antes e depois, ou seja, que ele **não** é o controle daquela mutação:

| Mutação | `[1]` | `[2]` | `[3]` | `[9]` |
|---|---|---|---|---|
| 1 — token vazio na classe `dotnet` do classificador | **REPROVA** (a linha `INCONCLUSIVO test-surface` some: o comando de `[1]` passa a "cobrir" dotnet) | `=` passa (o comando já cobria dotnet) | `=` passa (não há dotnet na fixture, nenhuma linha é emitida em nenhum dos dois estados) | `=` passa (o vetor não muda) |
| 2 — glob de `.sln` cego no contador | **REPROVA** (perde `2 solution(s)`) | `=` passa | `=` passa | **REPROVA** (vetor `dotnet=0 solution(s)/5 projeto(s)` ≠ literal) |
| 3 — vetor por classe decorado no contador | `=` passa (a fixture de `[1]` tem mesmo 2/5) | `=` passa | **REPROVA** (publica `dotnet=2 solution(s)/5 projeto(s)` num repositório sem dotnet) | `=` passa (a fixture de `[9]` tem mesmo 2/5) |

Medição da mutação 1, na mesma bancada, com o classificador protótipo e o mutante (`sha256` diferente conferido antes de medir):

```
ÍNTEGRO  cmd=[sh -c exit 0]        -> []              cobre_dotnet=NAO
         cmd=[dotnet test app.sln] -> [dotnet]        cobre_dotnet=SIM
MUTADO   cmd=[sh -c exit 0]        -> [dotnet]        cobre_dotnet=SIM
         cmd=[dotnet test app.sln] -> [dotnet]        cobre_dotnet=SIM
```

A leitura que importa é a coluna `[2]`: ela passa nas **três** mutações. `[2]` é controle positivo de que a guarda não reclama sempre, e não detecta nenhuma delas — escrever isso evita que um implementador conclua que `[2]` cobre o que só `[1]`, `[3]` e `[9]` cobrem.

### 3.6 Contador de controle com denominador fixo — e por classe, não agregado

A versão anterior desta seção definia o denominador como "5 classes e o total nominal de fixtures", e a revisão 1 mediu a consequência: com um denominador agregado, uma mutação no contador de `.sln` não move nenhum dos dois números, e a segunda prova de mutação de §3.5 não podia falhar. O agregado responde "olhei para alguma coisa"; ele não responde "olhei para a coisa certa".

**Decisão fechada:** o contador é um **vetor por classe**, e tanto o gate quanto a produção publicam o vetor inteiro **sempre que o gate conseguiu examinar** — inclusive as classes com zero, que são o sinal mais informativo. A ressalva ao lado do "sempre" é o inverso exato dele e precisa ficar escrita aqui, porque duas outras decisões desta seção dependem dela: quando o gate **não** conseguiu examinar, ele publica `INCONCLUSIVO` e **nenhuma** classe. É o que `[6a]` de §3.4 assere em letra (`lib/test-surface.mjs` removido: a saída não contém menção a classe descoberta) e é o que a decisão do `git ls-files` fora de repositório manda fazer, adiante nesta mesma seção. Um gate que não pôde rodar publicando `dotnet=0, node=0, …` seria a onda inteira derrotada por uma linha de simetria decorativa: zeros que dizem "examinei e não há" onde o fato é "não examinei".

`check-test-surface.sh` publica, em produção, uma linha desta forma:

```
test-surface: 5 classe(s) examinada(s); dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0
```

O gate `[9]` afirma **os números exatos da fixture**, não a forma da linha: sobre a fixture de `[1]` (2 `.sln`, 5 `.csproj`, 1 `package.json`, nada mais), a asserção é a igualdade do vetor publicado com a constante declarada. Denominadores fixos escritos no arquivo do gate, nenhum derivado do que rodou:

```sh
CLASSES_NOMINAL=5                         # dotnet jvm node python go
VETOR_FIXTURE1="dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0"
SCEN_MIN=9                                # obrigatórios: [1] [2] [3] [4] [5] [6a] [7] [8] [9]
SCEN_AMB_NOMINAL=1                        # dependem do ambiente: [6b], e só ele
```

**A constante passou a ser escrita na forma exata da linha, e a ressalva da revisão 3 procede porque eu executei a comparação.** A versão anterior declarava `VETOR_FIXTURE1="dotnet=2/5 node=1 jvm=0 python=0 go=0"` e, três linhas abaixo, pedia "a igualdade literal do vetor" contra a linha que a produção publica — `test-surface: 5 classe(s) examinada(s); dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0`. Medido nesta rodada, `grep -q 'dotnet=2/5 node=1 jvm=0 python=0 go=0'` sobre a linha de produção **não casa**: as duas formas não são literalmente iguais, e a prescrição não era executável como escrita. Duas saídas existiam — normalizar a linha antes de comparar, ou escrever a constante na forma exata — e escolhi a segunda, porque normalização é código a mais entre o observado e o esperado, e código entre os dois é onde um gate aprende a concordar consigo mesmo. A **propriedade** que o implementador precisa provar é que a constante é comparada contra o **sufixo do vetor** da linha publicada, e que a comparação discrimina: sob a mutação 2 de §3.5 o vetor vira `dotnet=0 solution(s)/5 projeto(s), …` e `[9]` reprova; sem mutação, passa. O primitivo — igualdade de string sobre o trecho após o `; `, ou `grep -F` da constante inteira — é de quem executa.

**O `FIXTURES_NOMINAL` da versão anterior foi REMOVIDO, e a revisão 2 está certa em derrubá-lo — ele era um placeholder por escrever dentro de uma seção que se apresenta como decisão fechada, num documento que reprova os outros exatamente por isso.** E não era só falta de preencher: o número não é derivável sem ambiguidade, porque "fixture" e "cenário" não coincidem nesta seção — `[1]`, `[2]`, `[4]`, `[5]` e `[6b]` operam sobre a mesma árvore de 2 `.sln`/5 `.csproj` variando só o `FORGE.md` ou a allowlist, `[8]` não monta repositório nenhum (é PBT sobre o classificador) e `[9]` é o próprio contador. Duas pessoas honestas escreveriam dois números.

**O denominador certo é o de cenários, que é a única exceção legítima de literal numa asserção: ele é fixo por construção do próprio gate, e a divergência é o achado.** É a mesma régua de §2.6 e de §5.2, com a mesma separação em duas constantes pelo mesmo motivo medido: `[6b]` depende de montar um `PATH` sem `node`, e um denominador único transformaria o gate em vermelho fabricado no parque de máquinas onde o helper não montar. O incremento de `[9]` acontece **antes** da aferição, e `SCEN_MIN` o inclui — dito em letra para não deixar um off-by-one à interpretação de quem implementa.

`CLASSES_NOMINAL` é denominador fixo legítimo, e a distinção importa depois da varredura da invariante 14: ele **não** conta arquivos da árvore, conta o vocabulário de classes que o próprio gate e o próprio `check-test-surface.sh` declaram — as cinco de §3.2. Uma classe nova (rust, ruby) chega por edição do classificador e da constante no mesmo PR, que é a conversa que se quer ter; o que envelheceria sozinho seria contar `.csproj` da árvore, e é por isso que o vetor da fixture é asserido sobre a **fixture que o gate monta**, nunca sobre o repositório em que ele roda.

Reprova quando: o número de classes examinadas difere de `CLASSES_NOMINAL`; o vetor publicado difere do literal declarado para a fixture; ou `SCEN` difere de `SCEN_MIN`. Quando `SCEN_AMB` é menor que `SCEN_AMB_NOMINAL`, o gate imprime `INCONCLUSIVO <gate>/[6b] capacidade=ambiental — não foi possível montar um PATH sem 'node' nesta máquina; [6a] prova a mesma propriedade por remoção de arquivo` e **não** reprova. A mensagem de reprovação manda remedir e atualizar a constante — nunca ajustar o observado ao esperado.

**A enumeração usa `git ls-files` com exclusão explícita de `.forge/`, e o motivo é o vetor literal.** Medido: `git ls-files '*package.json' ':!:.forge/**'` filtra a maquinaria do harness, e o pathspec de exclusão funciona junto com vários globs positivos (`git ls-files '*build.gradle' '*build.gradle.kts' '*pom.xml' ':!:.forge/**'` devolve só os de fora do `.forge/`). Sem a exclusão, o vetor da fixture passaria a depender do conteúdo de `template/.forge/`, que a fixture copia para dentro do repositório — hoje isso é inofensivo, medido (`git ls-files 'template/.forge/*package.json'`, `'*.sln'`, `'*.csproj'`, `'*build.gradle'`, `'*pom.xml'`, `'*pyproject.toml'`, `'*setup.py'`, `'*go.mod'` devolvem **0** cada um), mas é inofensivo por acidente: o dia em que um capability pack trouxer um `package.json` para dentro de `.forge/`, `VETOR_FIXTURE1` vira vermelho fabricado num gate que não tem nada a ver com aquele arquivo. A exclusão também é a decisão certa em **produção**, e não só no teste: um `package.json` dentro de `.forge/` é maquinaria do harness, não superfície de teste do projeto.

**A exclusão cobre `.forge/**` E `template/.forge/**`, e isto é a ressalva da revisão 3 aceita com a medição que a torna barata.** `':!:.forge/**'` protege a fixture, onde o template é copiado para o `.forge/` da raiz, mas não excluiria `template/.forge/**` nesta árvore — o repositório do harness, que é o único lugar do mundo onde a maquinaria vive sob esse prefixo. Hoje é inofensivo e eu remedi nesta rodada: com a exclusão simples, os globs de classe devolvem `dotnet=0/0, jvm=0, python=0, go=0` e `node=2` nesta árvore, e a exclusão dupla (`':!:.forge/**' ':!:template/.forge/**'`) devolve **os mesmos** `node=2`, porque `git ls-files 'template/.forge/*package.json' 'template/.forge/*.sln' 'template/.forge/*.csproj' 'template/.forge/*go.mod' 'template/.forge/*pom.xml'` devolve **0**. **Decisão:** a exclusão é dupla desde o primeiro commit, porque ela custa um pathspec e remove a dependência de um acidente — o dia em que um capability pack trouxer um `package.json` para dentro de `template/.forge/`, `check-test-surface.sh` rodando sobre esta árvore contaria maquinaria como superfície de teste do projeto, e o achado apareceria como vermelho num gate que não tem nada a ver com aquele arquivo.

**O desfecho que a enumeração NÃO cobria, achado pela varredura de exaustividade da revisão 2, e o que passa a acontecer nele.** `git ls-files` fora de um repositório git sai **128**, e o idioma natural do contador engole esse rc no pipe. Medido:

```
$ cd <diretório sem .git>
$ n=$(git ls-files '*.sln' 2>/dev/null | wc -l); echo "n=$n rc=$?"
n=0 rc=0            ← o rc é o do `wc`, não o do `git`; 128 desapareceu
$ if out=$(git ls-files '*.sln' 2>/dev/null); then echo rc=0; else echo "rc=$?"; fi
rc=128              ← detectável quando a captura é da substituição, não do pipe
```

Sem tratamento, `check-test-surface.sh` invocado fora de um repositório git publicaria `5 classe(s) examinada(s)` com todas as classes em zero e sairia 0 — o falso-verde exato que esta onda existe para fechar, dentro do gate que ela cria. **Decisão fechada:** o contador captura o rc de cada `git ls-files` por substituição de comando (nunca por pipe para `wc`), e um rc diferente de zero produz `INCONCLUSIVO test-surface capacidade=dura — não é um repositório git (rode o gate a partir da raiz de um clone)`, com rc 4, e **nenhuma** classe publicada. O caso vizinho foi medido e é diferente: num repositório git **sem commit**, `git ls-files` sai 0 e enumera corretamente o que estiver no índice, então esse estado é legítimo e não produz `INCONCLUSIVO`. Os dois entram como asserção do gate.

Publicar o vetor em produção não é simetria decorativa: é ele que faz a segunda mutação de §3.5 ter onde falhar, e é ele que dá ao campo a resposta para "de onde saiu esse `INCONCLUSIVO`" sem reexecutar nada.

---

## 4. Item 3 — LDG-0157: `check-ai-attribution.sh` acusa quando não conseguiu olhar

### 4.1 O defeito, reproduzido

Comando, com um arquivo de mensagem limpo (`fix(x): mensagem limpa sem qualquer assinatura de IA`):

```
$ PATH=/usr/bin:/bin:/usr/sbin:/sbin FORGE_ROOT=<repo> bash template/.forge/scripts/check-ai-attribution.sh msg-file msg.txt
check-ai-attribution.sh: line 40: node: command not found

FAIL: assinatura de IA detectada (rule rules/conventions/no-ai-attribution.md).
      O commit é de quem decidiu e assume a mudança; a ferramenta usada não é coautora.
      …
rc=1
```

Controle, o mesmo arquivo com `node` no `PATH`: `OK ai-attribution — mensagem limpa`, rc 0.

### 4.2 A segunda reprodução, que refuta a correção candidata do próprio item

LDG-0157 propõe *"separar rc 127 / erro de execução de rc 1 / violação encontrada"*. **O rc não separa.** Com `node` **presente** e `lib/ai-attribution.mjs` **ausente**:

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find module '…/lib/ai-attribution.mjs'
…
FAIL: assinatura de IA detectada (rule rules/conventions/no-ai-attribution.md).
rc=1
```

O import dinâmico rejeitado devolve **rc 1** — indistinguível, no canal de rc, de "encontrei uma violação", que é o que `_scan_file` emite por `process.exit(violations.length ? 1 : 0)` (linha 49). Nenhum pré-voo de `command -v node` corrige isso, porque `node` está lá.

**Conclusão de desenho, medida:** o veredito precisa sair do código de saída e ir para o **stdout estruturado**. É a correção, e ela não estava no item.

### 4.3 A terceira reprodução: universo vazio nos modos `msg-file` e `text`

```
$ : > vazio.txt
$ bash template/.forge/scripts/check-ai-attribution.sh text vazio.txt
OK ai-attribution — texto limpo
rc=0
```

O modo `range` tem contador de controle (`forge_universe_check`, linhas 93-98); `msg-file` e `text` não têm. Corpo de PR vazio, ou lido de um path errado que por acaso existe e está vazio, aprova.

### 4.4 Decisões de desenho fechadas

**Decisão 1 — o veredito muda de canal, e a mudança é do `_scan_file`, NÃO do rc do script.** `_scan_file` — o bloco node embutido — passa a imprimir registros tabulados em stdout (`HIT\t<label>\t<linha>\t<motivo>\t<texto>` e `SCANNED\t<n>`) e **sair 0** mesmo com violações; o chamador conta os `HIT` e decide. Para o `_scan_file`, e só para ele, rc diferente de zero passa a significar "a varredura abortou".

**O rc do script `check-ai-attribution.sh` continua com o contrato de hoje, e a distinção precisa estar escrita porque três cenários rastreados dependem dela.** O script continua saindo **1** quando há violação — é o que `w120[14]` (§4.5) e `tests/w120-ai-attribution-gate.sh:118` afirmam — e continua saindo diferente de zero quando o universo é vazio, com a linha `universo-vazio`, que é o que `tests/w144-gate-control-counter-gate.sh:127-141` `[5]` afirma; a isenção declarada na allowlist com a chave `ai-attribution` continua devolvendo rc 0 com `justificativa declarada`, que é o que `w144[6]` afirma nas suas duas metades. O que nasce é o **4** para capacidade ausente, e é só ele. A Decisão 4 abaixo, ao levar o contador aos modos `msg-file` e `text`, reaproveita a **mesma chave** `ai-attribution` da allowlist, exatamente para não invalidar a fixture de `w144[6]`. Uma leitura literal da frase anterior desta decisão — "rc diferente de zero passa a significar, e só significar, a varredura abortou" — aplicada ao script, teria mandado o implementador devolver 0 em violação e quebrado os três. É literalmente o padrão que três gates irmãos já usam — `check-shell-pipeline.sh:66-70`, `check-secrets.sh:191-196` e `check-heredoc-hash.sh:66-71`, os únicos três do template cuja mensagem contém `abortou` (`grep -rln 'a varredura abortou' template/.forge/scripts/`). **Este item é convergência para um padrão existente, não invenção.**

*Alternativa descartada:* manter `process.exit(violations.length ? 1 : 0)` e acrescentar o pré-voo de `node`. Descartada pela reprodução de §4.2.

**Decisão 2 — pré-voo de capacidade pelo lib.** `check-ai-attribution.sh` ganha `forge_verdict_require ai-attribution dura node "instale Node >= 20"` e `forge_verdict_require ai-attribution dura "$LIBDIR/ai-attribution.mjs" "npx forge-harness update"`.

**Os números desta decisão estavam errados e a revisão 1 os confirmou como certos — os dois erramos, e a medição refuta a nós dois.** A versão anterior dizia "**8 de 12** gates que invocam `node` já têm pré-voo e **4 não têm** — `check-ai-attribution.sh`, `check-heavy-mutex.sh`, `check-liaison-acks.sh`, `check-liaison-log-integrity.sh`", e o veredito da revisão reproduziu esse mesmo "12 … exatamente os 4 nomeados sem". Remedi, com o comando literal:

```sh
for f in template/.forge/scripts/check-*.sh; do
  inv=$(grep -vE '^[[:space:]]*#' "$f" | grep -w node | grep -v node_modules | grep -v 'command -v node' | wc -l)
  pv=$(grep -c 'command -v node' "$f")
  [ "$inv" -gt 0 ] && printf 'invoca=%s pre-voo=%s %s\n' "$inv" "$pv" "${f##*/}"
done
```

São **11** gates `check-*.sh` que invocam `node`, não 12; **8** têm pré-voo e **3** não têm: `check-ai-attribution.sh`, `check-liaison-acks.sh`, `check-liaison-log-integrity.sh`. **`check-heavy-mutex.sh` não pertence à lista**: `grep -n 'node' template/.forge/scripts/check-heavy-mutex.sh` devolve **uma única linha**, a 29, e nela `node` aparece apenas dentro de `-not -path '*/node_modules/*'` num `find`. Ele não invoca `node`, não tem o que pré-voar, e a versão anterior desta spec o incluiu por um grep que não distinguia `node` de `node_modules`. Os **três** entram nesta onda, pelo lib, para que a correção feche a classe e não um sítio; o quarto não entra porque não existe.

**Decisão 3 — o pré-voo emite `INCONCLUSIVO` e rc 4, não `FAIL` e rc 1.** Os 8 gates que já têm pré-voo hoje dizem `FAIL (node >= 20 required)` e saem 1 ou 2 — ou seja, colapsam "não verifiquei" em "está sujo", a direção de LDG-0157, só que com mensagem honesta. Os 8 migram para o lib. É mudança de mensagem e de rc, não de bloqueio: o `pre-push` continua recusando o push (§1.2, dependência dura), e ninguém que hoje consegue publicar deixa de conseguir.

**Decisão 4 — contador de controle nos modos `msg-file` e `text`.** O `SCANNED` do lado node vira o denominador, e zero linha examinada reprova, com a mesma allowlist e as mesmas chaves do modo `range`.

*Distinção de vocabulário, escrita a pedido da revisão 1 e ela tem razão em pedi-la.* Este `SCANNED` é um **denominador derivado**: o número de linhas de uma mensagem de commit varia por natureza, e a régua legítima aqui é a do `forge_universe_check` — `> 0`, com isenção declarada na allowlist (`lib/gate-universe.sh:62-65`). Ele **não** é o "denominador fixo" que a invariante 3 do plano exige e que §2.6, §3.6 e §5.2 usam. Os dois nomes coexistem nesta spec e significam coisas diferentes:

| Nome | Onde | Régua | Por quê |
|---|---|---|---|
| **denominador fixo** | §2.6 (`SCEN_MIN`), §3.6 (`CLASSES_NOMINAL`, vetor por classe), §4.7 (`SCEN` do `w120`), §5.2 (`SITIOS_NOMINAL`, 22 sítios, e `CENARIOS_NOMINAL`) | igualdade com uma constante literal escrita no arquivo | o universo é declarado **dentro do próprio gate** — array de sítios, cenários numerados, vocabulário de classes — e é enumerável na hora de escrever; qualquer desvio é defeito |
| **piso sobre universo derivado** | §5.2 (`GATES_NODE_MIN`, `LINHAS_CAPACIDADE_MIN`) | o universo é enumerado na execução e o gate reprova abaixo do piso; o piso só sobe por edição explícita, e o universo tem de ser **invariante à onda** — se a própria onda o esvazia, o piso é vermelho fabricado (a lição do Novo 1 da revisão 4, escrita em `[9]`) | o universo é a **árvore**, que cresce sem pedir licença; igualdade aqui envelhece na primeira onda que acrescentar um arquivo, e uma lista fixa deixaria o arquivo novo fora da guarda em silêncio (invariante 14) |
| **contador de controle derivado** | esta decisão (`SCANNED` de `msg-file`/`text`), `[9]` do modo `range` de hoje | `> 0`, com isenção declarada | o universo é o insumo do usuário e varia legitimamente; só o zero é patológico |

Um revisor adversarial que tratar um pelo outro reprova o certo ou aprova o errado, e é para não ter de adivinhar que a tabela está aqui.

### 4.5 O vermelho, antes do verde

Casa em `tests/w120-ai-attribution-gate.sh`, que já tem canal real (`[6]` faz `git commit` de verdade, `[7]` faz `git push`) e hoje **não tem contador de cenários** (medido: `grep -c 'SCEN' tests/w120-ai-attribution-gate.sh` → 0).

**`w120[11]` — sem `node`, o gate não acusa.** `PATH` sem `node`, mensagem limpa. Asserções: rc **4**; a saída **não** contém `assinatura de IA detectada`; a saída contém `INCONCLUSIVO` nomeando `node`. *Como falha hoje:* rc 1 e a saída contém exatamente `FAIL: assinatura de IA detectada (rule rules/conventions/no-ai-attribution.md).` — a string medida em §4.1. A asserção falha porque não existe, no arquivo, nenhum caminho que classifique falha de execução; `grep -n 'INCONCLUSIVO\|inconclusive' template/.forge/scripts/check-ai-attribution.sh` devolve **zero**.

**`w120[12]` — `node` presente, `lib/ai-attribution.mjs` ausente.** As mesmas três asserções de `[11]`. *Como falha hoje:* rc 1 e o mesmo banner, com o `ERR_MODULE_NOT_FOUND` acima — medido em §4.2. Este cenário é o que impede a correção preguiçosa de `[11]` (só um `command -v node`).

**`w120[13]` — controle: `node` e lib presentes, mensagem limpa.** rc 0 e `OK ai-attribution`.

**`w120[14]` — anti-tautologia, obrigatório: `node` e lib presentes, mensagem SUJA.** rc **1** e o banner `assinatura de IA detectada`. Sem `[14]`, uma implementação que devolvesse `INCONCLUSIVO` sempre passaria em `[11]`, `[12]` e `[13]` e desligaria o gate inteiro.

**`w120[15]` — universo vazio em `text` e `msg-file`.** Arquivo vazio: rc diferente de zero, com a linha de universo vazio. *Como falha hoje:* `OK ai-attribution — texto limpo`, rc 0 — medido em §4.3.

**`w120[16]` — pelo canal real, o `commit-msg` recusa e a recusa nomeia a capacidade.** `git commit` num repositório com os hooks instalados por `core.hooksPath` absoluto e `PATH` sem `node`. Asserções: o commit falha, a saída contém `INCONCLUSIVO` e **não** contém `assinatura de IA detectada`. É a exigência de `gate-delivery-channel.md`: a prova acontece pelo canal pelo qual o gate roda em produção, e o sinal é positivo — a presença de um token que só o caminho certo emite —, nunca a mera ausência de erro.

**Correção em letra de uma expectativa de LDG-0157.** O item registra, como consequência de segunda ordem, que este defeito *"torna w190[6b] incapaz de isolar a guarda de leitor da issue #82"*. **Isso continua verdadeiro depois da correção, e a onda não finge o contrário.** Com `node` fora do `PATH`, o `check-ai-attribution.sh` roda antes do bloco de gates (`pre-push:71-76` — `grep -n 'check-ai-attribution' template/.forge/hooks/git/pre-push` devolve 71 e 73; a citação anterior desta spec dizia 70-75 — muito acima da linha 400) e continuará recusando o push — agora com `INCONCLUSIVO` em vez de uma acusação falsa. O `[6b]` deixa de ser `SKIP` e passa a afirmar um invariante mais fraco e verdadeiro: *sem `node`, o push é recusado e a recusa nomeia a capacidade ausente, em vez de imputar uma violação inexistente*. O isolamento da guarda do leitor permanece com `[6a]`, que é onde ele sempre esteve. Reordenar o hook para que o teste isolasse melhor seria subordinar a ordem de produção à conveniência do teste, e isso não se faz.

### 4.6 Prova de mutação

Alvo: `template/.forge/scripts/check-ai-attribution.sh`. Mutação: restaurar `process.exit(violations.length ? 1 : 0)` na linha do heredoc e remover o pré-voo. Asserção sob mutação: `w120[11]` **e** `w120[12]` reprovam, cada uma com a sua mensagem. Restauração e recontrole pelo protocolo de §2.5 — três `sha256`, duas comparações, mais a asserção de que o sha mutado difere do original.

Segunda mutação, sobre o pré-voo isolado: manter o veredito em stdout e remover **só** o `forge_verdict_require` de `node`. Asserção: `[11]` reprova e `[12]` **passa**. Este par prova que as duas asserções medem coisas diferentes; sem ele, uma correção que atendesse apenas metade do defeito passaria por completa.

### 4.7 Contador de controle

`w120` ganha `SCEN` — hoje não tem, medido: `grep -c 'SCEN' tests/w120-ai-attribution-gate.sh` → **0** —, com denominador fixo escrito, nunca derivado, e reprova quando o observado difere.

E ele herda de §2.6 a **separação em duas constantes**, pelo mesmo motivo medido lá: `[11]` e `[16]` dependem de montar um `PATH` sem `node`, que é o único construto ambiental de toda a onda.

**Os dois números ficam escritos, e a revisão 2 está certa em cobrá-los — a versão anterior enumerava em prosa, errava a conta e deixava um cenário fora de qualquer constante.** Medido: `grep -nE 'echo "OK \[' tests/w120-ai-attribution-gate.sh` devolve **10** cenários hoje, `[1]` a `[10]`. A frase anterior dizia "`SCEN_MIN` conta `[13]`, `[14]`, `[15]` e os cenários que o `w120` já tem", o que fecha em 13, e declarava `[12]` fora do ambiental sem o pôr em constante nenhuma. O obrigatório correto é **14**, com `[12]` dentro:

```sh
SCEN_MIN=14           # obrigatórios: os 10 de hoje ([1]-[10]) + [12] [13] [14] [15]
SCEN_AMB_NOMINAL=2    # dependem do ambiente: [11] e [16], e só eles
```

O modo de falha que a omissão abria é o da invariante 3 do plano, e é exatamente o defeito que esta onda combate: um implementador fechando a conta em 13 faria `[12]` não incrementar `SCEN`, e o gate voltaria a aprovar sem ter olhado para o cenário que impede a correção preguiçosa de `[11]`. `[12]` **não** entra no ambiental porque ele remove `lib/ai-attribution.mjs` do disco, que é manipulação de arquivo e roda em qualquer lugar; ele entra no obrigatório porque roda sempre.

Quando o helper compartilhado não conseguir montar o `PATH` nesta máquina, o gate imprime `INCONCLUSIVO w120/[11] capacidade=ambiental` (e o mesmo para `[16]`) e não reprova. Os números literais das duas constantes saem da contagem de cenários do próprio gate, que é o único denominador literal legítimo desta spec (§4.4, Decisão 4), e a segunda mutação de §5.2 é o precedente do que acontece se alguém os derivar do array.

---

## 5. O censo da classe no harness

Pedido no mandato da onda. Comandos e resultados, medidos em 2026-09-07.

**Universo bruto.** `grep -rn '|| true' template/.forge/ | wc -l` → **165**. `grep -rn '2>/dev/null ||' template/.forge/ | wc -l` → **105**. Concentração de `|| true`: `liaison-ops.sh` 30, `doctor.sh` 19, `pentest-ops.sh` 7, `spec-verify.sh` 6, `pre-push` 6, `ledger-ops.sh` 5.

**Universo relevante — invocação de `node` em shell.** A versão anterior desta seção dizia **122** linhas, medidas por um script node cujo comando a spec não citava — violação da regra que o próprio preâmbulo impõe, e o número não sobreviveu à remedição. Comando literal, reprodutível:

```sh
RE='(^|[;&|(]|\$\()[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*node[[:space:]]'
{ find template/.forge -name '*.sh' -type f; find template/.forge/hooks -type f ! -name '*.sh' ! -name '*.md'; } \
  | sort -u | while read -r f; do
      grep -nE "$RE" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v 'command -v node' | sed "s|^|$f:|"
    done
```

Sobre os **88** arquivos de shell de `template/.forge/` (`*.sh` mais os hooks sem extensão), ele devolve **102** linhas de invocação do binário `node`.

**Limitação conhecida deste censo, declarada.** O regex casa `node` no início de comando — após `^`, `;`, `&`, `|`, `(`, `$(`, com prefixos de atribuição de ambiente. Ele **não** casa a forma de braço de `case`, e o exemplo medido é `check-red-first.sh:20-22` (`check)  node "$SCRIPT_DIR/lib/check-red-first.mjs" …`). Portanto **102 é piso, não teto**. Isso não afeta nenhuma decisão desta onda: as duas listas que sustentam decisão — os 10 sítios de rc engolido e os 11 gates `check-*.sh` que invocam `node` — foram medidas por caminhos independentes deste regex e são exaustivas nos seus universos (§5.1 e §4.4, Decisão 2).

Das 102:

| Forma | Sítios | Alimenta veredito |
|---|---|---|
| rc engolido por `\|\| true` / `\|\| echo` / `\|\| :` | 10 | **5** |
| rc tratado como booleano (`if ! node …`, `\|\| { … }`) | 3 | 3 |

Os **5** que alimentam veredito, cada um com o efeito medido pela leitura do sítio:

| Sítio | Colapso |
|---|---|
| `lib/forge-runtime.sh:87` | leitor de gates falha ⇒ "nenhum gate declarado" — é #119 |
| `doctor.sh:247` | `orphan-changes.mjs` falha ⇒ "nenhum change órfão" |
| `doctor.sh:296` | `check-red-first.mjs` falha ⇒ `st=""`, e o `case` trata `""` no mesmo ramo vazio de `OK*` |
| `spec-transition.sh:124` | `impact-freshness.mjs` falha ⇒ `not-applicable`, que é o veredito **não bloqueante**, e a transição para `implementing` prossegue |
| `archive-spec.sh:35` | idem, no pré-flight de archive |

Os outros 5 são de exibição ou de escrita com fallback (`spec-verify.sh:100`, `c4.sh:11`, `red-evidence.sh:70` e `:72`, `wave-ops.sh:130`); `red-evidence.sh:72` já faz a coisa certa, caindo em `'?'` explícito.

Os 10 são exatamente estes, e a lista é exaustiva no universo do comando acima — reproduzível por `… | grep -E '\|\|[[:space:]]*(true|echo|:)'`, que devolve `archive-spec.sh:35`, `c4.sh:11`, `doctor.sh:247`, `doctor.sh:296`, `lib/forge-runtime.sh:87`, `red-evidence.sh:70`, `red-evidence.sh:72`, `spec-transition.sh:124`, `spec-verify.sh:100`, `wave-ops.sh:130`.

**Sítios onde a ausência de `node` faz a verificação sumir em silêncio.** `grep -rn 'if command -v node\|&& command -v node' template/.forge/ --include='*.sh'` → **7**: `spec-verify.sh:99`, `doctor.sh:245`, `doctor.sh:288`, `spec-transition.sh:70`, `spec-transition.sh:123`, `lib/forge-runtime.sh:86`, `archive-spec.sh:32`.

**Gates.** Dos **11** `check-*.sh` que invocam `node` (medição corrigida em §4.4, Decisão 2 — eram "12" nesta spec e o veredito da revisão 1 reproduziu o engano), **8** têm pré-voo `command -v node` e **3** não têm. Dos 8 que têm, **todos** reportam `FAIL` — nenhum reporta um terceiro estado. Apenas **3** (`check-shell-pipeline.sh:68`, `check-secrets.sh:193`, `check-heredoc-hash.sh:68`) separam "a varredura abortou" de "encontrei violação", e apenas **1** (`check-ai-attribution.sh:49`) usa `process.exit(<condição de violação>)` como canal de veredito.

**Consumidores do leitor de `runtime.gates`:** 4 (`pre-push:431`, `run-gates.sh:58`, `spec-verify.sh:92`, `doctor.sh:427`), mais o próprio leitor em `lib/forge-runtime.sh:87`; **0** conferem que a função existe depois do `source` (`grep -rn 'command -v forge_runtime\|type forge_runtime\|declare -f forge_runtime' template/ bin/` → vazio).

### 5.1 O que a onda toca do censo, e o que ela registra

**A soma anterior — "24 sítios" — estava errada por sobreposição e por um gate inexistente, e a revisão 1 acertou em medir a aritmética.** Ela apontou que os 3 lints que "já separam mas usam rc 2" são subconjunto próprio dos 8 com pré-voo, e chegou a **21**; remedindo os gates sem pré-voo (3, não 4 — §4.4, Decisão 2), o número chegou a **20 sítios distintos**, e a revisão 3 acrescentou **dois**, um por bloqueador procedente: o `mktemp` de `check-suite-wiring.sh` (Novo 1, §1.3) e a própria `forge_runtime_gates_phase` (Novo 2, §2.3, Decisão 3). São **22**. A lista literal, sem interseção, é esta — e é ela que o gate da classe (§5.2) carrega como denominador fixo:

| # | Sítio | Grupo | O que a onda faz |
|---|---|---|---|
| 1 | `lib/forge-runtime.sh:87` | rc engolido que alimenta veredito | rc próprio (4), `2>/dev/null \|\| true` sai (§2.3, Decisão 1) |
| 2 | `doctor.sh:247` | idem | captura explícita; `orphan-changes.mjs` que falha vira `INCONCLUSIVO`, não "nenhum órfão" |
| 3 | `doctor.sh:296` | idem | captura explícita; `st=""` deixa de cair no ramo de `OK*` |
| 4 | `spec-transition.sh:124` | idem | captura explícita; `impact-freshness.mjs` que falha deixa de virar `not-applicable` |
| 5 | `archive-spec.sh:35` | idem | idem, no pré-flight de archive |
| 6 | `check-ai-attribution.sh` | gate sem pré-voo | `forge_verdict_require` (§4.4, Decisão 2) |
| 7 | `check-liaison-acks.sh` | gate sem pré-voo | idem |
| 8 | `check-liaison-log-integrity.sh` | gate sem pré-voo | idem |
| 9 | `check-authz.sh` | pré-voo que colapsa em `FAIL` | migra para o lib: `INCONCLUSIVO … capacidade=dura`, rc 4 |
| 10 | `check-data-governance.sh` | idem | idem |
| 11 | `check-heredoc-hash.sh` | idem (linhas 32 e 45) | rc 4 na 32, rc 5 na 45 (§1.3) |
| 12 | `check-observability.sh` | idem | rc 4 |
| 13 | `check-red-first.sh:12` | idem | rc 4 |
| 14 | `check-secrets.sh` | idem (linhas 48 e 98) | rc 4 na 48, rc 5 na 98 |
| 15 | `check-shell-pipeline.sh` | idem (linhas 29 e 42) | rc 4 na 29, rc 5 na 42 |
| 16 | `check-worktree-prereqs.sh` | idem | rc 4 |
| 17 | `pre-push:431` | consumidor do leitor | captura explícita e bloqueio (§2.3, Decisão 4) |
| 18 | `run-gates.sh:58` | consumidor do leitor | variável intermediária; reprova com rc 1 |
| 19 | `spec-verify.sh:92` | consumidor do leitor | variável intermediária; `status: inconclusive` no `verification.yaml` |
| 20 | `doctor.sh:427` | consumidor do leitor | `info` nomeando a causa, sem bloquear; o `awk` perde o `\|\| true` e o rc do leitor deixa de morrer no pipe (§2.3, Decisão 3) |
| 21 | `check-suite-wiring.sh:39` | `mktemp` que colapsa em rc 2, em gate que **não** invoca `node` | `INCONCLUSIVO suite-wiring capacidade=ambiental`, rc 5 (§1.3) |
| 22 | `lib/forge-runtime.sh`, `forge_runtime_gates_phase` | propagador de rc entre o leitor e dois chamadores | propaga o rc do leitor **explicitamente**, sem depender do `pipefail` de quem chama (§2.3, Decisão 3) |

Aritmética, sem sobreposição: 5 (rc engolido) + 3 (gates sem pré-voo) + 8 (gates com pré-voo `FAIL`) + 4 (consumidores do leitor, excluído `lib/forge-runtime.sh:87`, que já é o item 1) + 1 (`mktemp` em gate sem `node`) + 1 (o propagador) = **22**. Os "3 que já separam mas usam rc 2" são os itens 11, 14 e 15 — subconjunto dos 8, e não uma quarta parcela; contá-los de novo era o erro. Os dois últimos são parcelas próprias: o item 21 não entra em nenhuma das quatro primeiras porque `grep -n 'node' template/.forge/scripts/check-suite-wiring.sh` devolve **zero** — executado nesta rodada —, e o item 22 é uma função distinta do leitor do item 1, nas linhas 93-96 do mesmo arquivo. Dentro dos 22 sítios, **7 linhas** de `exit 2` migram, nomeadas na tabela de §1.3.

**Todos os 22 têm asserção nesta onda**, e a asserção mora em §5.2 — o gate da classe, que a versão anterior desta spec pedia por ordinal sem nunca especificar. Os itens 1-5, 6-8, 9-16, 20 e 21 são cobertos pelos censos estáticos `[7]` a `[11]` de §5.2; os itens 17, 18, 19 e 22 têm, além disso, vermelho comportamental pelo canal real em `w190[12]`, `[14]`, `[14b]`, `[15]` e `[15b]`.

**Registra e não toca:** os demais 141 `|| true` de `template/.forge/` e os sítios de exibição. Motivo: converter em massa um idioma que em 141 lugares é legítimo produz um diff impossível de revisar e uma taxa de falso achado alta. Vira item de ledger novo, com o comando de medição no corpo, priorizado P3.

### 5.2 O gate da classe — cenários, vermelho, denominador e mutação

Esta seção não existia na versão anterior desta spec, e a revisão 1 reprovou por isso, com razão: §1.4, §5.1, §8 e o passo 1 de §10 pediam um gate — o **pré-requisito dos outros três** — especificado só pelo nome. Um passo de implementação sem vermelho descrito é o inverso da invariante 1 do plano, e o inverso do que esta onda inteira cobra dos outros.

O gate da classe é o **único** dos quatro que assere sobre a **superfície do template**, e não sobre um push. É deliberado: os 22 sítios de §5.1 estão em **19** arquivos diferentes — contados na própria tabela de §5.1, onde `lib/forge-runtime.sh` aparece duas vezes (itens 1 e 22) e `doctor.sh` três (itens 2, 3 e 20); a versão anterior desta frase dizia "14 arquivos" e o número não vinha de contagem nenhuma —, e montar canal real para cada um seria uma suíte que ninguém roda. O gate compensa a estática com **seis** cenários comportamentais sobre o lib de verdade — `[2]`, `[3]`, `[3b]`, `[4]`, `[5]` e `[6]` — e com um cenário anti-tautológico que exercita um gate real de ponta a ponta (`[12]`).

Ordinal alocado pelo orquestrador (§8). Chamo-o de `wNNN` abaixo.

**`[1]` — o lib existe e expõe as cinco funções.** `source template/.forge/scripts/lib/gate-verdict.sh` e, para cada nome de §1.4, `declare -f <nome> >/dev/null`. *Como falha hoje:* `ls template/.forge/scripts/lib/gate-verdict.sh` → `No such file or directory`, e `grep -rn 'forge_verdict' template/ | wc -l` → **0**.

**`[2]` — capacidade presente: silêncio e rc 0.** `forge_verdict_require t dura node "instale Node"` com `node` no `PATH`: rc 0 e **stdout vazio**. O silêncio é asserção: um lib que imprimisse sempre transformaria todo log em ruído e a linha `INCONCLUSIVO` em fundo.

**`[3]` — capacidade dura ausente: rc 4 e a linha completa.** `forge_verdict_require t dura forge-cap-inexistente-xyz "instale Node"` — uma capacidade que **não existe em máquina nenhuma**, e não o scrub de `PATH`: rc **4**; a saída casa `INCONCLUSIVO t capacidade=dura`; a saída nomeia a capacidade; a saída contém a saída oferecida. *Como falha hoje:* o arquivo não existe.

**`[4]` — capacidade ambiental ausente: rc 5 e `capacidade=ambiental`.** Mesmo construto, segundo argumento `ambiental`: rc **5**, a linha casa `capacidade=ambiental`. *Como falha hoje:* além de o arquivo não existir, `grep -rn 'exit 5\|-eq 5 \]' template/.forge/` devolve **zero** — o rc 5 não tem sentido nenhum no harness de hoje.

**`[3b]` — a capacidade na forma de CAMINHO: rc 4 e o caminho nomeado.** `forge_verdict_require t dura /nao/existe/test-surface.mjs "instale X"` — o argumento contém `/`, então o predicado é `[ -e ]` e não `command -v`: rc **4**, a linha casa `INCONCLUSIVO t capacidade=dura` e **nomeia o caminho**. É a forma de que `check-ai-attribution.sh` precisa para `lib/ai-attribution.mjs` (§4.4, Decisão 2) e de que os itens 6-8 de §5.1 precisam para os seus `.mjs`; sem ela, a metade positiva de `[9]` estaria satisfeita por três sítios cujo predicado nunca foi asserido. *Como falha hoje:* o arquivo não existe.

**`[3b]` é cenário numerado e conta, e a ressalva de redação da revisão 4 procede — a convenção desta spec é que sufixo de letra CONTA.** `SCEN_MIN=20` do `w190` inclui `[12c]`, `[14b]` e `[15b]`; `SCEN_MIN=9` de §3.6 inclui `[6a]`. `[3b]` não é evidência de bancada coberta por `[3]`: ele exercita **outro predicado** — `[ -e ]` sobre caminho, contra `command -v` sobre nome —, e a versão anterior o deixava só dentro do bloco de bancada, o que fazia um implementador que seguisse a convenção fechar 14 contra `CENARIOS_NOMINAL=13`. `CENARIOS_NOMINAL` vai a **14**.

**`[3]` e `[4]` deixaram de depender do scrub de `PATH` na revisão 2, e o motivo é a invariante do contador.** A versão anterior os escrevia sobre o helper de `PATH` sem `node`, o que fazia **dois** cenários deste gate serem ambientais sem que nenhuma constante os separasse — o mesmo defeito que §2.6 corrige no `w190` e que §4.7 corrige no `w120`, reintroduzido aqui. Não há necessidade: o lib testa a **presença de uma capacidade nomeada**, e um nome que ninguém tem serve ao predicado sem tocar no ambiente. Medido em bancada, com o lib protótipo:

```
[2] presente (capacidade `sh`)          : rc=0  out=[]
[3] dura, capacidade inexistente        : rc=4  out=[INCONCLUSIVO t capacidade=dura — forge-cap-xyz ausente (instale X)]
[4] ambiental, capacidade inexistente   : rc=5  out=[INCONCLUSIVO t capacidade=ambiental — forge-cap-xyz ausente (instale X)]
[3b] dura, caminho de lib inexistente   : rc=4  out=[INCONCLUSIVO t capacidade=dura — /nao/existe/test-surface.mjs ausente (instale X)]
```

`command -v` de um nome inexistente devolve rc 1 sem imprimir nada, em qualquer máquina — medido —, e a forma de caminho (`*/*`) usa `[ -e ]`, que é o predicado que `check-ai-attribution.sh` precisa para `lib/ai-attribution.mjs` (§4.4, Decisão 2). Este gate fica com **zero** cenários ambientais, e `CENARIOS_NOMINAL` volta a ser um denominador único e íntegro.

**`[5]` — `forge_verdict_rc` é exaustivo sobre os quatro vereditos.** Domínio de 4 valores, enumeração completa (§6 explica por que aqui não cabe PBT): `pass`→0, `fail`→1, `inconclusive:dura`→4, `inconclusive:ambiental`→5, e um quinto caso — veredito desconhecido — que **reprova** com rc 2, nunca 0.

**`[6]` — `forge_verdict_is_inconclusive` e `forge_verdict_kind` respondem ao chamador.** `is_inconclusive` devolve 0 para rc 4 e 5, e diferente de zero para 0, 1, 2 e 3; `kind` ecoa `dura` para 4, `ambiental` para 5, e vazio para os demais. O rc 3 entra explicitamente porque `pentest-ops.sh` o consome como `refused` (§1.3) e um lib que o tratasse como inconclusivo contaminaria o perfil `strix`.

**Os desfechos que a enumeração de `0..5` não cobria, e o que acontece neles.** O domínio real de um rc de shell é `0..255`, e os valores fora de `0..5` chegam: `127` quando o comando ou a função não existe (medido em §2.3, Decisão 2), `126` quando o alvo existe e não é executável, e `128+N` quando o processo morre por sinal — `137` é o `SIGKILL` que um watchdog ou o OOM killer entrega. Existe ainda o argumento **não numérico** e o argumento **ausente**, que uma comparação aritmética descuidada faria abortar com `integer expression expected`. **Decisão:** para todos eles, `is_inconclusive` devolve diferente de zero e `kind` ecoa vazio — inconclusivo é só 4 e 5, e nada mais é promovido a inconclusivo por acidente; nenhum deles faz o lib abortar. `[6]` assere esses três casos junto com os seis primeiros: `127`, uma string não numérica, e a chamada sem argumento.

**`[7]` — censo estático A: nenhum dos 5 sítios de veredito engole o rc.** Para cada um dos itens 1-5 de §5.1, o gate ancora por **conteúdo** — o caminho do arquivo mais o padrão que identifica a invocação naquele arquivo (o nome do `.mjs` invocado) — e afirma, **para cada linha casada** — a âncora por conteúdo casa mais de uma em três dos cinco sítios, medido na revisão 4 e reconfirmado aqui —, que ela **não** contém `\|\|[[:space:]]*(true|echo|:)` nem `2>/dev/null[[:space:]]*\|\|`. *Como falha hoje:* casam **5 de 5** — `archive-spec.sh:35`, `doctor.sh:247`, `doctor.sh:296`, `lib/forge-runtime.sh:87`, `spec-transition.sh:124`, medidos pelo comando de §5.

**Nenhum número de linha entra no arquivo do gate, e isto é correção da revisão 2 por lição transversal, não por bloqueador nomeado.** A versão anterior mandava escrever "caminho e linha literais" no gate. Um número de linha é o literal mais perecível que existe: ele envelhece a cada edição acima dele, e esta onda edita **todos** os cinco arquivos — `lib/forge-runtime.sh:87` deixa de estar na 87 no instante em que a Decisão 1 de §2.3 tira o `2>/dev/null || true` e põe o rc próprio. O gate nasceria vermelho por conta da própria correção que ele existe para proteger. As linhas continuam citadas **nesta spec**, onde são medição datada de 2026-09-07 e servem ao implementador; elas não entram na asserção. O mesmo vale para o array de `SITIOS_NOMINAL`: cada entrada carrega arquivo mais padrão de ancoragem, nunca `arquivo:linha`.

**`[8]` — censo estático B: todo `check-*.sh` que invoca `node` pré-voa pelo lib.** O universo é **derivado no momento da execução**, nunca uma lista de 11 nomes: o gate enumera `template/.forge/scripts/check-*.sh`, filtra pelo mesmo comando literal de §4.4 (Decisão 2) os que de fato invocam o binário `node` — o filtro que exclui `node_modules` e o pré-voo, e que é o único capaz de manter `check-heavy-mutex.sh` fora — e afirma, para **cada** arquivo que sobrar, que ele contém `forge_verdict_require` e **não** contém `command -v node` seguido de `FAIL` na mesma linha. O denominador entra como **piso**: `GATES_NODE_MIN=11`, o valor medido hoje, e o gate reprova se o filtro devolver menos que isso.

**Por que propriedade mais piso, e não o literal 11.** Um literal aqui conta arquivos da árvore, e ele envelhece na primeira onda que acrescentar um `check-*.sh` novo que invoque `node` — provavelmente a onda K, que cria o executor de fase. Pior do que envelhecer: uma lista fixa de 11 nomes deixaria o gate número 12 **fora** da guarda em silêncio, que é a forma exata de "aprovar sem ter olhado" que esta onda existe para fechar. Com universo derivado, o gate novo entra na guarda por construção, no dia em que nasce. O piso protege a direção oposta, que é o filtro degenerar para zero e o cenário passar por vacuidade — a régua de `lib/gate-universe.sh` aplicada ao próprio censo. E o piso só se move para cima com edição explícita, que é a conversa que se quer ter num PR.

*Como falha hoje:* `grep -rn 'forge_verdict_require' template/.forge/scripts/check-*.sh` → **0**, com o filtro devolvendo 11 arquivos; `grep -c 'command -v node' …` → 8 arquivos com o pré-voo cru, todos com `FAIL` na mesma linha.

**`[9]` — censo estático C: capacidade ausente deixa de ser dita por `exit`.** O universo é **derivado no momento da execução**, no molde de `[8]`, e o bloqueador Novo 1 da revisão 4 derrubou com razão o universo anterior: ele era descrito de uma forma ("as linhas que contêm `command -v node` ou `mktemp`") e medido de outra (o mesmo predicado filtrado por `exit 2`), e nas duas leituras o gate reprovava a implementação certa desta onda. O universo passa a ser o conjunto que a onda de fato governa — **as linhas que declaram uma capacidade com tratamento de erro**: o gate enumera `template/.forge/scripts/check-*.sh` e seleciona a linha que nomeia um primitivo de capacidade (`command -v <binário>`, `mktemp`) ou invoca o lib de §1.4 (`forge_verdict_*`), **não** é comentário, e **abre ramo de erro** (`||`) ou já é a própria chamada do lib. O predicado abaixo é a medição que eu rodei, não o primitivo imposto ao implementador; o que a spec fixa é o universo e o contrafactual, e a obrigação de provar que a seleção escolhida discrimina os dois estados:

```
$ sel() { grep -nE '(command -v |mktemp|forge_verdict_)' "$@" \
      | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -E '(\|\||forge_verdict_)'; }

HOJE   (árvore de produção, template/.forge/scripts/check-*.sh)
  linhas=12 arquivos=9  exit2=7 exit1=5 pelo_lib=0
DEPOIS (bancada em $TMPDIR, com a migração dos passos 1 e 6 de §10 aplicada)
  linhas=15 arquivos=12 exit2=0 exit1=0 pelo_lib=15
```

Duas propriedades, e o piso deixou de ser uma delas:

- **P1 — a que a onda fecha.** Nenhuma linha do universo termina o ramo de erro em `exit 2` nem em `exit 1`: capacidade ausente deixa de ser dita pelo vocabulário de "uso incorreto do gate" (rc 2) e pelo de "violação encontrada" (rc 1), que é o que §1.3 decide. *Contrafactual, medido nos dois estados e colado acima:* hoje **12 de 12** violam — 7 em `exit 2`, que são as sete da tabela de §1.3, e 5 em `exit 1`, que são os pré-voos dos itens 9, 10, 12, 13 e 16 de §5.1 —; depois da onda, **0 de 12**. A direção é a certa, e é essa a correção: o conjunto que a onda esvazia é o dos `exit`, **não** o universo, e o gate reprova quando qualquer linha de capacidade voltar a terminar assim — inclusive num `check-*.sh` que ainda não existe.
- **P2 — a metade positiva, sem prescrever a forma.** Cada linha do universo diz o veredito pelo lib de §1.4 — a linha invoca uma das cinco funções, ou o ramo de erro que ela abre invoca — e a natureza segue o primitivo, que é exatamente a coluna "Passa a ser" da tabela de §1.3: `command -v <binário>` é `dura` e `mktemp` é `ambiental`. *Contrafactual:* hoje **0 de 12** dizem natureza nenhuma (`grep -rn 'forge_verdict' template/` → **0**, o mesmo zero de `[1]`); depois, **15 de 15**. O rc que cada natureza produz — 4 e 5 — é asserido **comportamentalmente** por `[3]`, `[3b]` e `[4]`, sobre o lib de verdade; o censo estático afirma a classificação e nunca o número, porque um número de rc lido por `grep` numa linha que delega ao lib seria censo de aparência.

**O piso continua, e agora ele mede um universo que a onda NÃO esvazia — era essa a confusão que o Novo 1 nomeou.** `LINHAS_CAPACIDADE_MIN=12` é o valor medido hoje na árvore de produção, contra as **15** linhas que a bancada devolve com a migração aplicada: o universo **cresce** com a onda, porque os três gates sem pré-voo (itens 6-8 de §5.1) ganham a declaração de capacidade que hoje não têm. O piso anterior, 7, media o subconjunto `exit 2` — o conjunto que a onda existe para zerar —, e por isso nascia vermelho permanente sobre a implementação certa; o novo mede a **declaração de capacidade**, que é invariante à migração porque a migração troca o primitivo e conserva a declaração. Ele protege a única direção que P1 não protege sozinha: a seleção degenerar para zero (glob errado, diretório renomeado) e P1 passar por vacuidade sobre conjunto vazio. E ele só sobe por edição explícita, que é a conversa que se quer ter num PR.

**O que fica deliberadamente FORA do universo, e por quê — a revisão 4 nomeou os três sítios e ela está certa em nomeá-los.** `check-ai-attribution.sh:54` (`_tmpfile() { mktemp "${TMPDIR:-/tmp}/forge-aiattr.XXXXXX"; }`) e `check-push-ahead.sh:228` (`OUT="$(mktemp "${TMPDIR:-/tmp}/forge-pushahead-XXXXXX")"`) não abrem ramo de erro: elas não **declaram** capacidade nenhuma, elas simplesmente não tratam a falha — que é outro defeito, de outra onda, e fica no item de ledger de §5.1 junto com os 141 `|| true`. `check-push-ahead.sh:201` é comentário, e o filtro de comentário o remove. Nenhuma das três está na tabela de §1.3 nem entre os 22 sítios de §5.1, e arrastá-las para o universo faria **P2 reprovar a implementação certa em três sítios que a onda não governa** — que é exatamente a leitura B que a revisão 4 mediu.

**Por que universo derivado, e não a lista das doze linhas ancorada por conteúdo.** A revisão 4 oferece as duas saídas e as duas são legítimas. A lista ancorada resolveria hoje e deixaria de fora, em silêncio, o `check-*.sh` que nascer amanhã escrevendo `mktemp … || exit 2` — que é a forma exata de "aprovar sem ter olhado" que esta onda existe para fechar, e é a invariante 14. Com universo derivado, o gate novo entra na guarda no dia em que nasce. A âncora por conteúdo continua sendo a régua dos **sítios** (`[7]`, e o array de `SITIOS_NOMINAL`), onde o universo é declarado dentro do próprio gate; aqui o universo é a árvore, e árvore pede piso mais propriedade.

*Como falha hoje:* o predicado devolve 12 linhas em 9 arquivos, e **12 de 12** violam P1 e P2. As sete de `exit 2` são `check-heredoc-hash.sh:32`, `check-heredoc-hash.sh:45`, `check-secrets.sh:48`, `check-secrets.sh:98`, `check-shell-pipeline.sh:29`, `check-shell-pipeline.sh:42` e `check-suite-wiring.sh:39` — as sete da tabela de §1.3. As cinco de `exit 1` são `check-authz.sh:11`, `check-data-governance.sh:12`, `check-observability.sh:13`, `check-red-first.sh:12` e `check-worktree-prereqs.sh:9` — os cinco pré-voos que colapsam em `FAIL`. E `grep -rn 'forge_verdict' template/` devolve **0**.

**As outras sete linhas de `exit 2` desses quatro arquivos ficam fora do universo, e isso é medição, não intenção.** §1.3 mede **14** linhas de `exit 2` nos quatro arquivos e declara que sete migram e sete ficam — as que ficam são uso incorreto do gate (`--path exige um argumento`, `modo desconhecido`, `<rev-range> obrigatório`, `--root exige um argumento`). Nenhuma delas nomeia `command -v` nem `mktemp` nem invoca o lib, então nenhuma entra na seleção: o predicado devolve 12 linhas, das quais exatamente 7 têm `exit 2`, que são as sete da tabela de §1.3. P1 não as toca, e isso é deliberado: rc 2 para uso incorreto de verdade é o significado certo, e assertar que elas **sobrevivem** seria escrever no gate um literal que conta a árvore — a decisão de preservá-las vive em §1.3, onde é decisão, e não numa asserção que envelheceria no primeiro `--flag` novo.

**A migração não derruba a contagem de `exit 1` de §1.3, e eu medi antes de escrever P1.** A tabela de §1.3 afirma que os **14** `check-*.sh` usam `exit 1` para violação, e P1 tira o `exit 1` de cinco linhas de capacidade. Executado nesta rodada, cada um dos nove arquivos do universo tem pelo menos um `exit 1` que **não** é de capacidade (`check-authz.sh` 1, `check-data-governance.sh` 1, `check-observability.sh` 1, `check-red-first.sh` 2, `check-worktree-prereqs.sh` 1, `check-heredoc-hash.sh` 3, `check-secrets.sh` 8, `check-shell-pipeline.sh` 4, `check-suite-wiring.sh` 4), e na bancada com a migração aplicada `grep -l 'exit 1' ./check-*.sh | wc -l` devolve **14** contra **14** arquivos. A linha "14 de 14" de §1.3 sobrevive à onda.

**`[10]` — censo estático D: o rc do leitor é sempre observável, e o censo sozinho NÃO prova isso.** Duas asserções estáticas: `grep -rn '< <(forge_runtime_gates_phase' template/.forge/` devolve vazio, e cada um dos 4 chamadores (itens 17-20 de §5.1) contém a captura `|| <var>=$?`. *Como falha hoje:* executado nesta rodada, o grep devolve **2** linhas — `spec-verify.sh:92` e `run-gates.sh:58`.

**O que este cenário NÃO cobre, dito em voz alta, porque o bloqueador Novo 2 da revisão 3 o mediu como buraco.** A presença da captura é condição necessária e não suficiente: um chamador pode ter a captura e mesmo assim observar 0, se o rc morrer num pipe antes de chegar nela. O caso real é o item 22 de §5.1 — `forge_runtime_gates_phase` é um pipe, e o rc dela só sobrevive porque `run-gates.sh` e `spec-verify.sh` declaram `pipefail` (§2.3, Decisão 3, com as duas bancadas coladas), enquanto `doctor.sh` declara só `set -u`. **Decisão:** `[10]` fica como censo estático, sem inchar, e a propriedade que ele não alcança é afirmada **comportamentalmente** por `w190[14b]` e `[15b]` (§2.4), que exercitam o leitor presente e quebrado contra os dois chamadores pelo caminho real. Um censo que tentasse ler opções de shell de dentro de um `grep` seria a quarta reimplementação de uma leitura que só o interpretador faz certo — a classe de LDG-0152, e a razão pela qual o cenário estático **para** aqui em vez de crescer.

**`[11]` — censo estático E: um vocabulário só.** `grep -rn 'NÃO VERIFICADO' template/.forge/hooks/ template/.forge/scripts/` devolve **zero**, e `grep -rln 'INCONCLUSIVO' template/.forge/hooks/git/pre-push` devolve o arquivo. *Como falha hoje:* o primeiro devolve **2** (`pre-push:143` e `:181`, §1.1) e o segundo devolve vazio. Este cenário é o que torna alcançável a linha de DoD sobre vocabulário concorrente, e é a asserção que amarra a decisão de migração de §1.1.

**`[12]` — anti-tautologia, obrigatório e comportamental.** Um gate real, com `node` **presente** e a lib presente, sobre um alvo que **viola**: `check-secrets.sh path <arquivo com segredo plantado>`, num repositório cujo `.forge/forge.yaml` declara `secrets:` com `enforce: block`, devolve rc **1** e o banner `FAIL secrets — <n> ocorrência(s) de segredo em arquivo versionado`. Sem `[12]`, uma migração que devolvesse `INCONCLUSIVO` incondicionalmente passaria em `[8]`, `[9]` e `[10]` e desligaria os 11 gates de uma vez — que é exatamente o desfecho que a onda existe para tornar impossível, e que ela produziria por conta própria se ninguém o assertasse.

**A cláusula do `enforce: block` entrou na revisão 3, e ela vem de eu ter executado a prescrição em vez de a escrever de memória — é o terceiro dos três comandos errados que a varredura de método achou.** A versão anterior mandava, em letra, esperar rc 1 do `check-secrets.sh path` sobre um segredo plantado. Executado numa bancada em `$TMPDIR` — repositório git com um commit e uma linha `const k = "AKIAIOSFODNN7EXAMPLE";` —, o resultado é o oposto:

```
$ FORGE_ROOT="$PWD" bash .../check-secrets.sh path leak.js ; echo rc=$?
OK secrets/scan-set — 1 arquivo(s) versionado(s) varrido(s) em path leak.js
WARN secrets/provider-token — 1 ocorrência(s):
      leak.js:1: AWS Access Key ID literal (valor mascarado, 20 car.)
WARN secrets — 1 ocorrência(s) (enforce: warn, não bloqueia; rule rules/conventions/no-hardcoded-secrets.md)
rc=0
```

O motivo está no próprio arquivo, e ele é deliberado: `check-secrets.sh:87` inicializa `enforce="warn"` e o comentário de `:84-86` diz que *"o default brando vale só para quem HERDA o gate"*. Com `.forge/forge.yaml` declarando `enforce: block`, a mesma invocação sobre o mesmo arquivo devolve o que `[12]` precisa:

```
FAIL secrets — 1 ocorrência(s) de segredo em arquivo versionado (enforce: block, rule rules/conventions/no-hardcoded-secrets.md)
rc=1
```

Sem a cláusula, `[12]` seria um **vermelho fabricado permanente** — reprovaria antes e depois da implementação, por um motivo que nada tem a ver com a onda —, e ele é justamente o cenário anti-tautológico que impede a onda de desligar onze gates. Uma asserção anti-tautológica que nunca fica verde não protege nada; ela só ensina o implementador a afrouxá-la.

**A alternativa foi considerada e descartada.** Poderia-se assertar o rc **0 com `WARN`** no modo de fábrica, sem tocar no `forge.yaml`. Descartada porque `WARN` com rc 0 é *quase* o falso-verde que a onda combate — a distinção "achou e não bloqueia" existe e é legítima (§4.4, Decisão 1, sobre o passivo de brownfield), mas fazer dela o controle anti-tautológico de uma onda sobre falso-verde seria escolher o sinal mais fraco disponível para provar o mais forte. A fixture declara `block`, que é o estado que o próprio arquivo chama de "estado final esperado de todo mundo".

**`[13]` — contador de controle.** Ver o denominador abaixo.

**Denominador fixo, escrito no arquivo do gate:**

```sh
SITIOS_NOMINAL=22        # a lista literal de §5.1, um array no próprio gate
CENARIOS_NOMINAL=14      # [1]..[13] mais [3b]; sufixo de letra conta, como em [6a] e [14b]
LINHAS_CAPACIDADE_MIN=12 # piso do universo derivado de [9]; propriedade, não igualdade
GATES_NODE_MIN=11        # piso do universo derivado de [8]; propriedade, não igualdade
```

O gate reprova quando o número de sítios efetivamente examinados difere de `SITIOS_NOMINAL`, ou quando o número de cenários executados difere de `CENARIOS_NOMINAL`. Nenhum dos dois é derivado do que rodou. Um sítio que sair do template (arquivo renomeado, gate removido) **reprova** e obriga a atualizar a constante no mesmo PR — que é o ponto: a lista é o contrato, e ela não pode encolher em silêncio.

**Cada entrada do array carrega três campos, e o do item 22 fica escrito aqui porque a ressalva da revisão 4 procede — ele era o único sem padrão de ancoragem declarado.** Os campos são `arquivo`, `padrão de ancoragem` (conteúdo, nunca `arquivo:linha`) e `cenário dono da asserção substantiva`. Para os itens 1-5 o dono é `[7]`, para os 6-16 é `[8]`, para as linhas de capacidade dentro dos 9-16 e do 21 é `[9]`, para os 17-20 é `[10]` e para o 21 é `[9]` mais `[11]`. A entrada do item **22** é `lib/forge-runtime.sh` com o padrão de ancoragem `forge_runtime_gates_phase`, e o que o laço afirma sobre ela é **exatamente uma coisa: que a âncora resolve** — a função ainda existe naquele arquivo, com aquele nome. A asserção substantiva dele — *o rc que o chamador observa é o do leitor, sob qualquer combinação de `set -e`, `set -u` e `pipefail`* — é de `w190[14b]` e `[15b]`, pelo canal real, e o parágrafo de `[10]` já diz por que ela não pode ser estática. Isto é deliberado e está escrito para o implementador não inventar a asserção nem fechar 21 contra 22: **examinado**, no vocabulário de `[13]`, é *a âncora resolveu e o cenário dono rodou*, e para o item 22 o cenário dono mora noutro gate — o laço registra o sítio como examinado quando a âncora resolve, e `[13]` conta 22.

**As quatro constantes não são do mesmo tipo, e a distinção é normativa (invariante 14).** `SITIOS_NOMINAL` e `CENARIOS_NOMINAL` contam coisas declaradas **dentro do próprio gate** — o array de sítios e os cenários numerados —, então são igualdades legítimas: a divergência é o achado. `LINHAS_CAPACIDADE_MIN` e `GATES_NODE_MIN` contam a **árvore**, que cresce sem pedir licença, então são pisos sobre universo derivado na execução: a igualdade envelheceria na primeira onda que acrescentasse um `check-*.sh`. E um piso só é legítimo sobre um universo que a **própria onda não esvazia** — foi por ignorar isso que a versão anterior de `[9]` pôs o piso sobre o subconjunto `exit 2`, que é exatamente o conjunto que a onda zera; a régua ficou escrita em `[9]`, com os dois estados medidos. Escrever as quatro juntas no mesmo bloco, com o comentário dizendo qual é qual, é o que impede o próximo implementador de "uniformizar" as duas famílias na direção errada.

**Prova de mutação — duas, pelo protocolo dos seis passos de §2.5** (três `sha256`, a asserção de que o sha mutado difere do original, restauração por `cp` e recontrole verde):

1. **Alvo `lib/gate-verdict.sh`:** `forge_verdict_require` passa a devolver 0 sempre, sem imprimir. Asserção sob mutação: `[3]`, `[3b]` **e** `[4]` reprovam, cada uma com a sua mensagem — `[3]` e `[3b]` por rc 0 onde exigiam 4, `[4]` por rc 0 onde exigia 5. Um FAIL por outra mensagem não conta.
2. **Alvo o próprio gate `wNNN`:** um dos 22 sítios é removido do array, sem tocar em `SITIOS_NOMINAL`. Asserção: `[13]` reprova por 21 examinados contra 22 declarados. Esta segunda mutação existe porque a primeira não prova que o denominador é **fixo** — ela prova que o lib funciona. Sem ela, um implementador poderia derivar `SITIOS_NOMINAL` do tamanho do array, e o contador aprovaria por não ter olhado para nada, que é a régua que LDG-0164 registra.

---

## 6. Onde entram PBT, contrato, integração e E2E

**PBT — aplica-se a um lugar, e só a um.** `lib/test-surface.mjs` é um classificador de string sobre espaço de entrada aberto, e a rule `testing/property-based-testing.md` o enquadra nas famílias "idempotência" e "monotonicidade". Três propriedades, com `lib/pbt.mjs`, seed fixa, shrinking exigido:

1. **Idempotência:** `classify(classify_input(c)) == classify(c)` para todo comando gerado.
2. **Monotonicidade sob concatenação:** se `classify(c)` contém a classe `K`, então `classify(c + " " + ruído)` contém `K`, para todo `ruído` gerado sem token de toolchain. Acrescentar texto nunca remove cobertura.
3. **Invariância a espaçamento e ordem:** `classify` é invariante a colapso de espaços e à permutação dos segmentos separados por `&&`.

O gerador produz comandos a partir de um alfabeto fixo de tokens de toolchain mais palavras de ruído, e **a asserção sobre o gerador é parte do teste** — item 5 da rule: um gerador de ruído que por acidente emitisse `dotnet` faria a propriedade 2 passar trivialmente, então o gate afirma que o ruído gerado não contém token de toolchain.

**Onde PBT NÃO se aplica, com a medição.** O mapeamento de veredito de §1.3 tem domínio de **4** valores (`pass`, `fail`, `inconclusive:dura`, `inconclusive:ambiental`) e contradomínio de **4** códigos (0, 1, 4, 5), mais o caso do veredito desconhecido: enumerar é exaustivo — é `[5]` de §5.2, com os cinco casos escritos — e gerar seria decorativo — a rule diz em letra *"Se a unidade não tem propriedade … não force"*. A guarda do leitor de `runtime.gates` tem espaço de entrada de **3 formas declaráveis × 3 estados do leitor = 9** combinações, todas enumeráveis e já parcialmente cobertas por `w190[1]`-`[6]`; os cenários novos completam a matriz por enumeração.

**Teste de contrato — três, todos com adotante instalado. O terceiro nasceu da varredura de strings da revisão 2 e é o que impede a onda de reintroduzir o próprio defeito no artefato que ela cria.**

1. `template/.forge/schemas/run-manifest.schema.json:26` declara `"status": { "enum": ["running","passed","failed","skipped"] }`. `INCONCLUSIVO` precisa de representação no manifesto, senão o estado morre na saída do terminal. **Decisão:** o enum ganha `inconclusive` de forma **aditiva** — manifestos antigos continuam válidos, leitores novos passam a aceitar o valor. A asserção de contrato reprova nos dois sentidos: quando o schema perde o valor, e quando um escritor emite valor que o schema rejeita. Casa em `tests/w199-schema-reader-parity-gate.sh`, que já é o gate de paridade schema × leitor.
2. `template/.forge/scripts/spec-verify.sh:52-66` produz `CHECKS_YAML` com `status: passed|failed`, que vai para o `verification.yaml` de todo change verificado. O terceiro estado precisa chegar lá pelo mesmo caminho, e a asserção afirma que um check inconclusivo aparece no `verification.yaml` como `inconclusive`, nunca ausente. Hoje um comando vazio é omitido em silêncio pelo `[ -n "$cmd" ] && run_check "$check" "$cmd"` da **linha 65** — medido por `grep -n '\[ -n "\$cmd" \] && run_check' template/.forge/scripts/spec-verify.sh` (a citação anterior desta spec dizia 63, que é o `for check in test typecheck lint; do`). O segundo caminho pelo qual o artefato mente é o de `spec-verify.sh:92`, com asserção própria em `w190[15]` (§2.4).
3. `template/.forge/scripts/lib/validate-archive.mjs` é o leitor do `verification.yaml` no pré-flight do `/forge:archive`, e **hoje ele só bloqueia em `failed`**: medido, a linha 107 é `for (const c of checks) if (c.status === 'failed') errors.push(...)`. Um check gravado como `inconclusive` não é `failed`, então, sem esta decisão, a onda produziria um `verification.yaml` honesto que o `/forge:archive` **aprovaria** — o estado sairia do terminal, entraria no artefato e voltaria a ser verde no único portão que lê o artefato. É o falso-verde da onda reintroduzido pela própria onda, um nível acima. **Decisão fechada:** `inconclusive` bloqueia o pré-flight de archive com mensagem própria, nomeando o check e dizendo que a verificação não aconteceu — nunca a mensagem de `failed`, que diria uma falsidade na direção oposta. A asserção reprova nos dois sentidos: um `verification.yaml` com `inconclusive` não passa, e um com todos os checks em `passed` continua passando. Retrocompatibilidade: o valor `inconclusive` não existia antes desta onda, então nenhum `verification.yaml` já gravado muda de desfecho — é aditivo puro. A linha 109 (`require_tests_before_archive`) já exige `status === 'passed'` para o check `test` e trata `inconclusive` corretamente por construção; ela não é tocada, e `tests/w192-declared-switch-has-reader-gate.sh` `[4a]`-`[4d]` continua afirmando o que afirma hoje.

**Teste de integração.** É o eixo desta onda inteira e não um complemento: os três defeitos são de **fiação**, não de função. Uma função `forge_verdict_require` testada isoladamente nasce verde e não diz nada sobre `pre-push` chamá-la. Por isso toda asserção de §2.4, §3.4 e §4.5 exercita o **caminho real** — `git push` e `git commit` contra fixture com `core.hooksPath` absoluto e remoto `--bare` —, e não a invocação direta do script. É a exigência literal de `testing/gate-delivery-channel.md`.

**E2E.** O caminho `/forge:wave close` → `run-gates.sh` → gate → veredito é o fluxo de ponta a ponta que a onda toca, e ele entra em `w190[14]` como chamada real a `run-gates.sh` sobre a fixture com lib antiga. Não há E2E contra consumidor externo nesta onda: seria dependência de repositório de terceiro dentro da suíte, que é justamente o que faz a onda G resistir a fechar.

**Prova de canal para o canal.** `gate-delivery-channel.md` exige também mutação do canal: além de "quebro o alvo e o gate acusa", vale "quebro o canal e a prova acusa". `w190[7]` já faz isso apontando `core.hooksPath` para diretório sem o hook; os cenários novos herdam a mesma fixture e, portanto, a mesma prova de canal — e a asserção `[12c]` existe para tornar essa herança observável.

---

## 7. Retrocompatibilidade — o que já está instalado e o que quebra

O harness está publicado no npm até a **0.14.0** e o defeito de #119 está no pacote: `git show v0.14.0:template/.forge/hooks/git/pre-push | sed -n '415,435p'` mostra a guarda condicionada à forma e o `|| true` intactos. A linha 431 entrou em `d7d4ad4` e a primeira tag que a contém é a **v0.12.0**. A função `forge_runtime_gate_entries` entrou em `15ce493` e a primeira tag que a contém é a **v0.11.0**.

**A quebra, nomeada antes de acontecer.** Uma árvore com `pre-push` novo e `lib/forge-runtime.sh` anterior à 0.11.0 passa de **push verde** para **push bloqueado**. A versão anterior desta seção descrevia esse estado como *"o estado exato que a issue mede no `axis-device-platform`, com 8 gates declarados e 33 worktrees"*, como se fosse medição minha — **e não é**. `ls -d ~/Documents/projects/axis-device-platform` devolve `No such file or directory`: o repositório não existe nesta máquina e o número não pôde ser medido hoje. Ele vem do corpo da issue #119, e a atribuição correta é essa. É a única violação do preâmbulo desta spec (*"nenhum foi herdado de relatório de terceiro"*) e ela fica corrigida aqui, com o número mantido e a fonte nomeada — o dado de terceiro continua útil como ilustração, e não como prova. A decisão de retrocompatibilidade **não depende dele**: o que a sustenta é a medição da bancada de §2.1, feita em `$TMPDIR` nesta máquina, onde uma árvore com a lib de `15ce493^` produz `_n_all=0` e `EXIT=0` com 8 gates declarados e 8 scripts em disco. Isso é o objetivo e não um efeito colateral: o push verde ali afirmava uma falsidade. Mas precisa ser dito em voz alta, e o texto do bloqueio precisa carregar a saída, que é uma linha: `npx forge-harness update`.

Como esse estado surge na prática: `.forge/scripts/` é substituído inteiro pelo update (`scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` — issue #101), enquanto os hooks podem vir de `core.hooksPath` absoluto compartilhado entre worktrees (issue #73, citada no próprio `pre-push:300-305`). É por aí que a versão do hook e a da lib divergem. O CHANGELOG da release precisa dizer isso com essas palavras.

**O que NÃO quebra, medido:**

- rc `2` → `4` ou `5` nos três lints **e** no `check-suite-wiring.sh`: nenhum chamador de produção distingue (§1.3, com o grep vazio que o prova, reexecutado nesta rodada). E a varredura da invariante 15 sobre a string que o quarto arquivo passa a imprimir devolve zero, executado nesta rodada: `grep -rn 'FAIL suite-wiring' tests/` e `grep -rn 'mktemp falhou' tests/` não devolvem nada, e o único gate que exercita `check-suite-wiring.sh` — `tests/w146-suite-invocation-gate.sh` — afirma `rc -eq 0` (linha 52) e `rc -ne 0` (linha 72), nunca um rc nominal, e nunca chega à linha 39 porque o `mktemp` da fixture dele não falha.
- `forge_universe_check` e o formato de `.forge/empty-universe-allowlist.txt`: intocados. As chaves novas (`test-surface:<classe>`) são aditivas e o arquivo do template ganha as linhas de documentação correspondentes, no bloco que já lista as chaves usadas pelo harness.
- `run-manifest.schema.json`: mudança aditiva de enum; manifesto antigo continua válido.
- `forge_runtime_gates()` (a função histórica, sem `_entries`): intocada, como o comentário das linhas 59-61 promete em letra — *"retrocompat literal, não só de intenção"*.
- Projeto que não declara `runtime.test`: continua publicando. Muda a linha impressa, não o desfecho (§3.3).
- Projeto sem `.forge/scripts/`: continua no-op, pelas guardas de diretório que o `pre-push` já tem nas linhas 371-397.

**O que quebra DENTRO da suíte, e é editado no mesmo PR — seção nova da revisão 2.** A retrocompatibilidade acima é sobre consumidores instalados; ela não cobria a suíte do próprio repositório, e a revisão 2 mediu o buraco: mudar uma string que a produção imprime quebra todo gate rastreado que a afirma, e a versão anterior desta spec não listava nenhum. A varredura foi refeita por `grep` em `tests/` para **cada** string que a onda altera, e o resultado é este — a lista é a definição de pronto do passo 6 de §10, e nenhum destes gates pode ser "consertado" afrouxando a asserção:

| Gate | Cenário | O que ele afirma hoje | O que passa a afirmar | Por causa de |
|---|---|---|---|---|
| `tests/w160-prepush-preflight-gate.sh` | `[4]`, linha 134 | `"NÃO VERIFICADO"` com `check-worktree-prereqs.sh` na mesma saída | `INCONCLUSIVO worktree-prereqs`, com o nome do script preservado | §1.1 |
| `tests/w168-liaison-log-merge-union-gate.sh` | `[5]`, linha 128 | `grep -qi "NÃO VERIFICADO"` | `grep -q "INCONCLUSIVO liaison-log-integrity"` | §1.1 |
| `tests/w97-hook-portability-gate.sh` | `[3]`, linhas 44 **e** 50 | `typecheck PULADO` (positiva na 44, negativa na 50) | `INCONCLUSIVO typecheck` nas duas, para que a negativa não passe por vacuidade | §3.3 |
| `tests/w190-pre-push-gate-reader-gate.sh` | `[6b]`, linhas 238-247 | bloqueio pela guarda do leitor, senão `SKIP` | recusa que nomeia a capacidade ausente, com `BLOQUEADO` preservado | §2.6, §4.5 |

E estes **não** mudam, medido, o que é tão parte da definição de pronto quanto os que mudam: `tests/w135-push-refs-export-gate.sh:149-150` (`typecheck OK`, `test OK`) fica intacto porque §3.3 conserva a ordem `<label> OK`; `tests/w171-gate-phase-contract-gate.sh` `[0a]`-`[0c]` fica intacto porque a Decisão 3 de §2.3 só imprime quando o rc do leitor é diferente de zero, e os três goldens são comparados por `cmp` byte a byte; `tests/w170-spec-verify-runtime-lib-gate.sh:57` e `tests/w90-run-manifest-gate.sh:86` (`status: passed`) ficam intactos porque as fixtures deles rodam com o leitor disponível; `tests/w144-gate-control-counter-gate.sh` `[5]` e `[6]` ficam intactos pela distinção escrita em §4.4 (Decisão 1) entre o rc do `_scan_file` e o rc do script; `tests/w192-declared-switch-has-reader-gate.sh` `[4a]`-`[4d]` fica intacto porque §6, contrato 3, não toca a linha 109 do `validate-archive.mjs`. Estas seis linhas são asserções da onda, não observações: se qualquer uma delas ficar vermelha, a implementação divergiu da decisão, e a saída é corrigir a implementação.

**Propagação.** `template/.forge/**` é a fonte; o `.forge/` da raiz deste repositório não é consumidor completo (registrado no próprio `.forge/FORGE.md` e alvo da Fase 1 do plano), então a onda **não** precisa duplicar nada na raiz. Nenhum arquivo tocado tem gêmeo em `plugin/forge/` — `grep -rln 'forge_runtime_gate_entries' plugin/` devolve vazio, e `plugin/forge/` só contém `commands/`. Regeneração de plugin não é necessária nesta onda.

---

## 8. Alocação de ordinal

Medido hoje: o máximo é **207** em `tests/` local, em `origin/develop` e em `origin/main` (`ls tests/ | grep -oE '^w[0-9]+' | sed 's/w//' | sort -n | tail -1` e `git ls-tree --name-only origin/{develop,main} tests/` com a mesma extração). Branches remotas em voo: `origin/wip/deepspec-run-manifest-ldg-0165` e `origin/wip/upgrade-safety-ldg-0131`, mais as branches locais desta rodada.

A onda precisa de **dois** ordinais novos — o gate da classe (lib de veredito, especificado por inteiro em **§5.2**: 14 cenários, vermelho de cada um, denominador fixo de 22 sítios e duas provas de mutação) e o gate de superfície de teste (§3.4-§3.6) — e **não aloca nenhum**. Invariante 10 do plano: o ordinal é alocado pelo orquestrador, uma vez, no momento de escrever o arquivo, conferido contra `origin/*` **e** contra as branches em voo desta rodada. LDG-0173 e LDG-0167 registram o pedágio de fazer diferente, cobrado duas vezes na mesma noite.

As demais asserções vão para gates existentes — `w190` (#119), `w120` (LDG-0157), `w199` (contrato de schema) — e não consomem ordinal.

---

## 9. O que esta onda explicitamente NÃO faz

**Não implementa LDG-0160.** O executor das fases `pre-deploy`/`post-deploy` é da onda K, e o plano diz em letra que *"o conserto dele **é** o executor que esta onda cria"* e que um gate escrito como "o doctor passa a nomear as fases" nasceria verde sobre o defeito. A onda D empresta o vocabulário que a K vai consumir e para aí.

**Não converte os 141 `|| true` restantes.** §5.1, com o motivo e o item de ledger.

**Não mede cobertura de teste por projeto.** §3.3, com a medição do `azim-crm` que justifica.

**Não altera `lib/gate-universe.sh` nem o formato da allowlist.** §1.4 e §7. O **cabeçalho** do `template/.forge/empty-universe-allowlist.txt` é editado (§3.3), e isso não é o formato: o parser de `forge_universe_waiver` ignora toda linha iniciada por `#` (`lib/gate-universe.sh:36`), então as linhas novas de documentação são invisíveis para ele. Uma allowlist de adotante escrita para a 0.14.0 continua sendo lida byte a byte da mesma forma.

**Não reordena o `pre-push`.** §4.5, correção em letra da expectativa de LDG-0157.

**Não toca `run-gates.sh --phase` além de tornar o rc do leitor observável.** A guarda de vacuidade da fase explícita (linhas 66-72) fica como está: ela é de LDG-0159, já fechado, e mexer nela dentro desta onda misturaria dois assuntos num diff.

**Não promove `INCONCLUSIVO` a bloqueio nas fases `pre-deploy`/`post-deploy`.** `gate-delivery-channel.md` proíbe, e a onda respeita a proibição em vez de renegociá-la.

---

## 10. Ordem de implementação e definição de pronto

A ordem importa porque o lib é pré-requisito dos três, e porque os dois gates novos precisam do ordinal antes de existirem como arquivo.

1. `lib/gate-verdict.sh` — vermelho no gate da classe (§5.2, cenários `[1]`-`[6]`, `[3b]` incluído, e `[13]`), verde, refactor.
2. LDG-0157 — o consumidor mais simples do lib, e o que destrava a leitura honesta de `w190[6b]`.
3. #119 — leitor, **seis** sítios (`pre-push:431`, `run-gates.sh:58`, `spec-verify.sh:92`, `doctor.sh:427`, o leitor em `lib/forge-runtime.sh:87` e o propagador `forge_runtime_gates_phase`, itens 17-20, 1 e 22 de §5.1), `w190[12]`-`[15b]`.
4. #106 — `lib/test-surface.mjs`, `check-test-surface.sh`, fiação no `pre-push` (tabela de rc de §3.3), `run_check` com os três desfechos, gate novo com PBT.
5. Contratos — `w199` e `verification.yaml`.
6. Os 8 gates com pré-voo `FAIL` e os 3 sem pré-voo migram para o lib; as 7 linhas de `exit 2` da tabela de §1.3 trocam para rc 4 ou 5, `check-suite-wiring.sh:39` incluída; `pre-push:143` e `:181` migram `NÃO VERIFICADO` para `INCONCLUSIVO` (§1.1). Fecha os censos estáticos `[7]`-`[11]` de §5.2.
7. **Os quatro gates rastreados da tabela de §7 são editados no mesmo PR** — `w160[4]`, `w168[5]`, `w97[3]` (as duas asserções) e `w190[6b]`. Este passo não é opcional e não é "ajuste de teste": as strings que eles afirmam são as que os passos 4 e 6 trocam, e um implementador que chegue aqui com dois vermelhos na mão tem à mão dois caminhos errados — reverter a migração, devolvendo o vocabulário concorrente, ou afrouxar `[11]` de §5.2. A tabela de §7 diz, gate a gate, qual asserção substitui qual.

**Definição de pronto da onda, cada linha provada por comando:**

- Os três defeitos reproduzidos em §2.1, §3.1 e §4.1 **não** reproduzem mais, pelos mesmos comandos, com as mesmas bancadas.
- Suíte inteira verde, executada em série pelo orquestrador, nunca concorrente.
- Cada gate novo ou alterado publica seu contador de controle, com denominador fixo escrito no arquivo, e reprova com denominador zero ou **diferente** do declarado — igualdade, não piso, exceto onde §4.4 (Decisão 4) declara em letra um contador derivado.
- `w190` publica `SCEN` contra `SCEN_MIN=20` e registra `SCEN_AMB` separado, com `INCONCLUSIVO` quando o cenário ambiental não puder rodar (§2.6).
- Cada prova de mutação percorre os seis passos de §2.5, incluindo a asserção de que o sha mutado difere do original e o recontrole verde depois da restauração. São **oito** provas: uma em §2.5, três em §3.5, duas em §4.6 e duas em §5.2 — e nenhuma delas passa sem que a asserção nomeada falhe pela mensagem declarada, nunca por outra.
- `grep -rn 'INCONCLUSIVO' template/.forge/scripts/ template/.forge/hooks/` devolve os sítios previstos, e `grep -rn 'NÃO VERIFICADO' template/.forge/hooks/ template/.forge/scripts/` devolve **zero** — a migração dos dois sítios de `pre-push` (§1.1) é o que torna esta linha alcançável, e ela é assertada por `[11]` de §5.2.
- `grep -rn 'NÃO VERIFICADO\|typecheck PULADO' tests/` devolve **zero**, e os quatro gates da tabela de §7 afirmam os tokens novos — é a contraparte, dentro da suíte, da linha acima. Sem ela, "suíte inteira verde" seria alcançável revertendo a migração.
- `grep -q 'test OK'` e `grep -q 'typecheck OK'` continuam casando a saída de um push verde, medido: `w135[3]` roda sem edição, e a conservação da ordem `<label> OK` (§3.3) é o que a torna verdadeira.
- Os três goldens de `tests/fixtures/w171/` continuam byte-idênticos, sem regravação: um golden regravado nesta onda seria a prova de que a Decisão 3 de §2.3 vazou diagnóstico para o caminho feliz.
- Um `verification.yaml` com um check `inconclusive` **reprova** o pré-flight do `/forge:archive` (§6, contrato 3), e um com todos em `passed` continua aprovando — o par que impede a onda de reintroduzir o próprio defeito um nível acima.
- Os denominadores de cenário estão escritos como número, nenhum como placeholder: `SCEN_MIN=20`/`SCEN_AMB_NOMINAL=1` no `w190` (§2.6), `SCEN_MIN=9`/`SCEN_AMB_NOMINAL=1` no gate de superfície (§3.6), `SCEN_MIN=14`/`SCEN_AMB_NOMINAL=2` no `w120` (§4.7), `CENARIOS_NOMINAL=14` sem cenário ambiental no gate da classe (§5.2).
- Os denominadores que contam a **árvore** estão escritos como piso sobre universo derivado na execução, nunca como igualdade: `GATES_NODE_MIN=11` em `[8]` e `LINHAS_CAPACIDADE_MIN=12` em `[9]` (§5.2), cada um sobre um universo que a onda **não** esvazia — o de `[9]` foi remedido nos dois estados e vai de 12 para 15 com a migração aplicada. Um deles escrito como igualdade, ou posto sobre um universo que a onda zera, é por si só a prova de que a invariante 14 foi lida como sugestão.
- Nenhum arquivo de gate contém `arquivo:linha` numa asserção, e os censos `[8]` e `[9]` de §5.2 derivam o universo na execução, com pisos `GATES_NODE_MIN=11` e `LINHAS_CAPACIDADE_MIN=12` — as duas formas em que um literal desta onda envelheceria dentro da própria onda.
- Os **22** sítios de §5.1 estão no array do gate da classe, `SITIOS_NOMINAL` bate, e a segunda mutação de §5.2 prova que o denominador é fixo.
- Nenhum comando prescrito por esta spec ao implementador ou a um gate ficou sem uma de duas coisas: ou a saída da execução colada ao lado (17 dos 24, §13 e §14 — o predicado de `[9]` foi reexecutado na revisão 4 nos **dois** estados, produção e bancada migrada), ou a conversão em propriedade mais contrafactual com a obrigação explícita de o implementador provar a discriminação (5 dos 24). O predicado de `[9]` está nas duas colunas desde a revisão 4, e a cláusula é "uma de duas", não "exatamente uma". É a invariante 19, e ela é verificável lendo o documento.
- #119, #106 fechadas por `gh issue close` com o comentário que cita o gate que morde se o defeito voltar; LDG-0157 movido para `resolved` com a mesma prova.
- CHANGELOG registra a quebra nomeada em §7 com a linha de correção para o consumidor.

---

## 11. Respostas ao veredito da revisão 1

Um item por bloqueador, na ordem do veredito. Onde o revisor mediu, remedi antes de aceitar; onde ele errou, a medição que o refuta está aqui e a posição anterior foi mantida.

### Bloqueador 1 — `[7]` de §3.4 nascia verde, e nenhuma decisão autorizava mexer em `run_check`

**Procede, nas duas metades. Mudei a decisão, não a redação.**

Remedi o que ele mediu: `sed -n '206p;208p;215p' template/.forge/hooks/git/pre-push | grep -c 'OK'` devolve **1**. As três linhas de hoje já são distintas e só a terceira já contém `OK` — a asserção antiga passaria sobre o defeito intacto, medindo a motivação em vez do mecanismo.

(a) §3.3 ganhou uma **decisão fechada** com a tabela dos quatro desfechos de `run_check`, dizendo o que cada um passa a imprimir e com que rc, e registrando que a mudança vale também para `typecheck` (`pre-push:324-325`) porque o defeito é da função, não do campo. (b) `[7]` de §3.4 foi reescrito em quatro asserções, e a discriminante é positiva: as duas primeiras execuções contêm `INCONCLUSIVO test capacidade=ambiental` nomeando a causa. Vermelho de hoje, medido: `grep -c 'INCONCLUSIVO' template/.forge/hooks/git/pre-push` → **0**. Acrescentei a asserção (3) como par anti-tautológico, que o veredito não pediu e sem a qual uma implementação que imprimisse `INCONCLUSIVO` sempre passaria.

### Bloqueador 2 — a tabela de §1.1 omitia `NÃO VERIFICADO`, e a alternativa descartada estava invertida

**Procede inteiro.** Remedi: `grep -rn 'NÃO VERIFICADO' template/` → **2**, ambas em `hooks/git/pre-push` (143 e 181), com a semântica exata do terceiro estado. A tabela ganhou a linha, mais uma linha de `INCONCLUSIVO` (5 ocorrências, 3 arquivos) que também faltava, e a coluna "Onde" de `inconclusive` foi corrigida — era `pentest-ops.sh (12)`, é `pentest-ops.sh (10)`, `lib/api-surface.mjs (3)`, `analyzer.md (1)`, `gate-delivery-channel.md (1)`; comando citado na spec.

A justificativa da alternativa descartada foi reescrita sobre a medição verdadeira: os dois nomes já coexistem, e `INCONCLUSIVO` ganha porque tem rc publicado, forma de linha estável e rule normativa — não porque seria "o segundo nome". E o destino dos dois sítios está decidido em letra: **migram nesta onda**, sem mudança de severidade (os dois continuam não bloqueando, pelo motivo da issue #73 que `pre-push:300-305` registra), com asserção em `[11]` de §5.2. Sem isso a linha de DoD sobre vocabulário concorrente era inalcançável, como o veredito apontou.

### Bloqueador 3 — o gate da classe não tinha especificação alguma

**Procede, e era o buraco mais grave.** Escrevi **§5.2** inteira, no molde de §3.4-§3.6: 13 cenários numerados à época — hoje **14**, com `[3b]` promovido na revisão 4 —, o que cada um afirma, como cada um falha hoje com o comando que mostra, denominador fixo escrito (`SITIOS_NOMINAL=20` à época — hoje **22**, pelos dois sítios que a revisão 3 acrescentou, §13; `CENARIOS_NOMINAL=13`) e duas provas de mutação com controle e recontrole — a segunda existindo especificamente para provar que o denominador é fixo e não derivado.

Também refiz a aritmética de §5.1, que o veredito atacou por outro flanco (ver "medições" abaixo): eram **20 sítios distintos** à época, com a lista literal numa tabela, a soma sem sobreposição escrita (5 + 3 + 8 + 4) e o mapeamento de cada sítio para a asserção que o cobre; hoje são **22**, pelas duas parcelas que a revisão 3 acrescentou (§13). A afirmação "todos com asserção nesta onda" passou a ser verdadeira em vez de ser reduzida.

### Bloqueador 4 — `spec-verify.sh:92` sem decisão nem asserção

**Procede inteiro, e concordo com a hierarquia de gravidade que ele propõe.** Remedi: `grep -n 'forge_runtime_gates_phase' template/.forge/scripts/spec-verify.sh` → linha **92**, `done < <(forge_runtime_gates_phase source "$ROOT")`; `grep -rn '< <(forge_runtime_gates_phase' template/.forge/` devolve exatamente duas linhas, ela e `run-gates.sh:58`.

Mudanças: a tabela de §2.2 passou a listar os **cinco** sítios reais, com uma coluna nova separando "o leitor" dos "chamadores" — o erro anterior era listar `lib/forge-runtime.sh:87` no lugar de `spec-verify.sh:92`; a Decisão 4 de §2.3 virou uma tabela dos cinco, e `spec-verify.sh` reprova **e** grava `status: inconclusive`; nasceu o cenário **`w190[15]`** com as quatro asserções que o veredito pediu, incluindo a negativa sobre `(no checks declared in FORGE.md runtime: — skipping check phase)`; §10 passo 3 fala em cinco sítios. Acrescentei em §2.2 o parágrafo que diz por que este é o pior dos cinco: `run-gates.sh` produz wave fechada em falso, `spec-verify.sh` produz **evidência arquivada** em falso, e evidência arquivada sobrevive à sessão.

### Bloqueador 5 — denominador fixo contra o incremento ambiental do `w190`

**Procede na substância. A correção que ele sugeriu, não — e a refuto com medição.**

Remedi a substância e ela é pior do que o veredito descreve, no bom sentido: `grep -n 'SCEN=\$((SCEN + 1))' tests/w190-pre-push-gate-reader-gate.sh` devolve **13** sítios, dos quais 11 incondicionais, **1 dentro de um `for form in csv seq`** (linha 189, que incrementa sempre 2 e não é ambiental) e **1 ambiental** (linha 240). Total nominal de hoje: 13 obrigatórios + 1 ambiental. §2.6 foi reescrita com **duas constantes** — `SCEN_MIN=18` à época, hoje **20** pelos dois cenários que a revisão 3 acrescentou (§13), e `SCEN_AMB_NOMINAL=1` —, asserção de igualdade sobre a primeira e `INCONCLUSIVO w190/[6b] capacidade=ambiental` sobre a segunda, que é o vocabulário da própria onda aplicado ao seu próprio gate.

**Refutação da alternativa sugerida.** O veredito propôs "um wrapper `node` que sai 127, em vez de remover o binário do `PATH`". Medido:

```
$ mkdir -p "$T/shim"; printf '#!/bin/sh\nexit 127\n' > "$T/shim/node"; chmod +x "$T/shim/node"
$ PATH="$T/shim:$NB" bash -c 'command -v node'   → /…/shim/node   rc=0
$ PATH="$T/shim:$NB" bash -c 'node --version'    → rc=127
```

Com o wrapper, `command -v node` **encontra** `node`. O `[6b]` deixaria de testar "`node` ausente" e passaria a testar "`node` presente e quebrado" — que é outro predicado, já coberto por `[13]` e por `w120[12]`. A troca calaria a asserção em vez de estabilizá-la. O scrub do `PATH` fica, e ele monta nesta máquina: reconstruí o `$NB` do `w190:205-218` (2185 links) e repeti o predicado da linha 219 **três vezes**, com `PATH sem node MONTADO` nas três.

### Bloqueador 6 — a segunda mutação de §3.5 não podia falhar

**Procede, e é a mesma classe de LDG-0164 que a onda diz combater.** O denominador de §3.6, como estava escrito ("5 classes e o total nominal de fixtures"), não se move quando o glob de `.sln` para de casar: continuam 5 classes examinadas e as mesmas fixtures exercitadas.

Adotei a primeira das duas saídas que o veredito oferece, que é a mais forte: §3.6 passou a definir o contador como **vetor por classe**, publicado tanto pelo gate quanto pela produção (`test-surface: 5 classe(s) examinada(s); dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0`), com `[9]` afirmando a **igualdade literal** do vetor da fixture. A segunda mutação de §3.5 ganhou asserção nova e agora falha por dois caminhos independentes: `[1]` deixa de encontrar `2 solution(s)` na linha, e `[9]` reprova pelo vetor. Acrescentei uma **terceira** mutação, na direção oposta — o contador publica o vetor com valores fixos em vez de contados —, que reprova em `[3]` e sem a qual um contador que decorasse a fixture passaria em `[1]`, `[2]` e `[9]`.

### Bloqueador 7 — "o discriminante é a fase" não resolve o gate novo da onda

**Procede, e derruba uma decisão que eu tinha dado por fechada.** O contraexemplo é interno: `check-test-surface.sh` é fase `source` e produz o terceiro estado por capacidade dura (sem `node`) e por capacidade ambiental (superfície descoberta), com severidades opostas. A fase não separa os dois, e a spec não dizia como o `pre-push` decidia — decisão em aberto disfarçada de fechada.

§1.2 foi reescrita: a natureza da capacidade é **argumento declarado** na chamada (`dura` / `ambiental`), transportada por **dois rc** (4 e 5) e por um campo literal na linha (`capacidade=`); a fase vira insumo da regra de escolha, não o discriminante. `5` está livre, medido: `grep -rn 'exit 5\|-eq 5 \]\|rc.*== 5' template/.forge/` → **zero**, e todo chamador que ainda não o conhece o trata como bloqueio, que é a direção segura. §1.3 ganhou a linha do rc 5; §1.4 ganhou `forge_verdict_kind` e a assinatura nova de `forge_verdict_require`; §3.3 ganhou a **tabela completa de rc → ação** para os rc 0, 1, 2, 4, 5 e o ramo `*`, fail-closed.

Corrigi também a ambiguidade agravante que o veredito mediu: a spec dizia invocar o gate novo "o padrão que `SHELL_LINTS` já usa", e `sed -n '314,318p'` mostra que esse padrão **bloqueia em qualquer rc diferente de zero**. §3.3 passou a dizer que da `SHELL_LINTS` a onda herda **apenas** a guarda de delegação em alvo ausente (306-313), nunca o tratamento de rc (314-318). As linhas também derivaram: 306-320, não 300-321.

---

### As medições do veredito que NÃO procedem

**A que refuto por completo: o número de gates que invocam `node`.** O veredito confirmou o meu "12 gates que invocam `node`, 8 com pré-voo e exatamente os 4 nomeados sem" e, com ele, a inclusão de `check-heavy-mutex.sh` na lista de sítios do bloqueador 3. **Erramos os dois.** Medido, com o comando escrito em §4.4 (Decisão 2): são **11** gates `check-*.sh` que invocam `node`, **8** com pré-voo e **3** sem — `check-ai-attribution.sh`, `check-liaison-acks.sh`, `check-liaison-log-integrity.sh`. `grep -n 'node' template/.forge/scripts/check-heavy-mutex.sh` devolve **uma** linha, a 29, e nela `node` aparece só dentro de `-not -path '*/node_modules/*'` num `find`: ele não invoca `node`, não tem o que pré-voar, e não é sítio desta onda. A minha lista anterior veio de um `grep` que não distinguia `node` de `node_modules`, e o veredito reproduziu o engano em vez de o pegar. Corrigido em §4.4, §5 e §5.1; a aritmética de §5.1 fecha em **20**, não nos **21** que o veredito calculou com o gate a mais.

**A que refuto no glob, aceitando o número: a coluna `gradle` de §3.2.** O veredito está certo em dizer que a coluna não reproduzia e que nenhum comando era citado — isso era defeito meu e foi corrigido com os seis globs escritos na spec. Mas os globs que ele usou para medir não servem à guarda, e a medição mostra por quê: `git -C ~/Documents/projects/axis-go-cloud ls-files '*.gradle*'` devolve **18** arquivos que são, todos, cache de um Gradle 8.2 dentro de um `.gradle/` versionado por engano sob `docs/` — nenhum é script de build, e o repositório não tem projeto JVM; e `git -C ~/Documents/projects/axis-fare-validator ls-files '*.gradle'` devolve **5**, dos quais um é `settings.gradle`, que é agregação e não módulo. O glob correto para "classe JVM presente" é `'*build.gradle' '*build.gradle.kts' '*pom.xml'`, que devolve **4** no `axis-fare-validator` e **0** no `axis-go-cloud` — e é ele que `check-test-surface.sh` implementa. Contar `*.gradle*` faria a guarda anunciar uma classe inexistente no consumidor que ela precisa acusar por outro motivo, e falso positivo em guarda nova é a via mais curta para ela ser desligada.

### As demais medições do veredito, todas aceitas e corrigidas

- **§5.1, "24 sítios"**: sobreposição real. Os três lints de rc 2 são subconjunto dos 8 com pré-voo. Corrigido para **20** (não 21, pelo gate a menos acima), com a lista literal e a soma escrita em §5.1.
- **§7, `axis-device-platform`**: `ls -d ~/Documents/projects/axis-device-platform` → ausente. O número vem do corpo da issue #119 e a atribuição foi corrigida em §7 e no preâmbulo, com a nota de que a decisão de retrocompatibilidade se apoia na bancada de §2.1, medida nesta máquina.
- **Deriva de número de linha**: todas confirmadas e corrigidas — `pre-push` 411-415 → **413-417**; `spec-verify.sh:63` → **65** (63 é o `for`); `SHELL_LINTS` 300-321 → **306-320**; `pre-push:214-220` → **214-219** (220 é o `fi`); `check-ai-attribution` em `pre-push:70` → **71-76**. Também corrigi, por conta própria, `lib/gate-universe.sh:31-51` → **31-52** e as três citações de `abortou`, que agora apontam a linha exata (`check-shell-pipeline.sh:68`, `check-secrets.sh:193`, `check-heredoc-hash.sh:68`).
- **§3.3, `discover-lite.mjs`**: o veredito diz "parcialmente incorreto"; remedindo, é **totalmente** incorreto e a afirmação cai. `git -C ~/Documents/projects/axis-go-cloud ls-files '*.sln' | awk -F/ '{print NF-1}' | sort -n | uniq -c` → **2 na raiz**, 22 a dois níveis. A linha 47 do `discover-lite` casa qualquer `.sln` de `topFiles`, então ele **detectaria** a stack `dotnet` ali. A decisão de não reaproveitá-lo continua, pelo motivo verdadeiro: `discover-lite` não conta nada — cada classe termina em `stack.push('<nome>')`, um booleano de presença, e a cardinalidade que `[1]` e §3.6 exigem não existe em lugar nenhum do arquivo.
- **§5, "122 linhas invocam `node`"**: o número vinha de um script cujo comando a spec não citava, o que viola o próprio preâmbulo. Remedido com regex citado: **102** linhas, e com a limitação declarada (o regex não casa braço de `case` — exemplo medido: `check-red-first.sh:20-22`), o que faz de 102 um piso. Nenhuma decisão se apoia nele: as duas listas que sustentam decisão foram medidas por caminhos independentes e são exaustivas nos seus universos.

### As ressalvas, respondidas

- **`[1]` de §3.4 termina rc 0, e #106 nasceu de um canal invisível.** Escrevi em letra, em §3.4, por que a linha impressa muda o desfecho onde a suíte vermelha não mudou — e a resposta honesta é que a linha **não** é a peça que fecha #106. As peças são a allowlist (a classe só para de aparecer quando alguém declara o motivo num arquivo versionado, com `git blame` e revisão de PR; enquanto ninguém declarar, a linha volta a cada push), o transporte para o `verification.yaml` (o estado sai do scrollback e entra no artefato que o archive lê) e o gate na suíte (se a guarda for esvaziada, ele morde). O bloqueio no push foi deliberadamente recusado, e §3.3 diz por quê.
- **`SCANNED` de §4.4 é denominador derivado, não fixo.** Aceito e escrito: §4.4 (Decisão 4) ganhou uma tabela que distingue os dois nomes, onde cada um vale e por quê — universo conhecido e enumerável na escrita do gate (igualdade com constante) contra universo que é insumo do usuário e varia (`> 0`, com isenção declarada). Era ambiguidade minha e o próximo revisor não vai ter de adivinhar.
- **A allowlist ganharia dois contratos e nenhum aviso.** Aceito. §3.3 passou a mandar editar o cabeçalho: a chave `test-surface:<classe>` entra na lista de gate-keys das linhas 20-28 com a glosa da semântica nova, e um parágrafo curto declara que o arquivo passa a cobrir dois estados — universo vazio e classe presente não coberta —, com a mesma exigência de `# motivo:` para os dois. §9 registra que isso não é mudança de formato: `lib/gate-universe.sh:36` ignora toda linha `#`.
- **A justificativa da Decisão 2 de §2.3 estava errada.** Aceito e reescrito. Medido: `bash -c 'set -u; rc=0; v="$(fn_inexistente)" || rc=$?; echo $rc'` → **127**, ou seja, a Decisão 3 já cobre a função ausente nas duas formas declaráveis. O backstop deixa de ser "o que resta" e passa a ser redundância deliberada contra um modo de falha diferente: um leitor que exista, rode, saia 0 e devolva lista vazia sobre um `FORGE.md` com gates em CSV.
- **O `commit-msg` não lê `runtime.gates`.** Aceito, medido (`grep -n 'forge_runtime' template/.forge/hooks/git/commit-msg` → vazio) e escrito em §2.3: ele entra nesta onda pelo item 3, como chamador de um gate que passa a falar `INCONCLUSIVO`, e não como consumidor do leitor.
- **Três gates novos dependendo do mesmo construto de `PATH`.** Aceito. §3.4 `[6b]` passou a mandar **um** mecanismo só para os três (`[6b]`, `w120[11]`, `w120[16]`): o scrub de `$PATH` do `w190:205-218`, extraído para um helper compartilhado da suíte, com o registro `SCEN_AMB` de §2.6 quando a máquina não permitir montá-lo. O wrapper que o veredito sugeriu está refutado acima.

---

## 12. Respostas ao veredito da revisão 2

Um item por bloqueador, na ordem do veredito. Os quatro procedem — nenhum foi refutado, e três deles são defeitos que a **correção da revisão 1** trouxe junto, que é a classe que esta seção existe para registrar. Antes de aceitar, remedi cada afirmação do revisor com comando próprio; onde a medição mostrou que o defeito era **maior** do que ele descreveu, a correção cobre o maior, e isso está dito em cada item. Além dos quatro, a varredura que o mandato pede encontrou mais seis defeitos meus que nenhuma das duas revisões nomeou, listados ao fim.

### Novo 1 — a migração de `NÃO VERIFICADO` quebra `w160[4]` e `w168[5]`

**Procede inteiro, e o mecanismo é o que ele descreve.** Remedi antes de aceitar: `grep -rn 'NÃO VERIFICADO' tests/` devolve exatamente duas linhas, `w160:134` e `w168:128`; `grep -n 'cp -R "$WS/template' tests/w160-…` devolve as linhas 39 e 142 e `tests/w168-…` a 104, ou seja, os dois rodam sobre o `pre-push` de produção, e afirmam as linhas 143 e 181 que §1.1 manda migrar e que `[11]` de §5.2 manda desaparecer.

§1.1 ganhou a tabela nominal dos dois gates, com a asserção de hoje e a de depois, e a nota de que o que aqueles cenários realmente protegem — rc 0, `pre-push OK`, o nome do alvo ausente na saída — continua assertado sem uma linha de mudança. §7 ganhou a tabela dos gates rastreados que a onda edita, §10 ganhou o **passo 7**, que faz a edição conjunta ser um passo de implementação e não um conserto de última hora, e a DoD ganhou a linha `grep -rn 'NÃO VERIFICADO\|typecheck PULADO' tests/` → zero, que fecha a porta que o revisor identificou: sem ela, "suíte inteira verde" seria alcançável revertendo a migração.

Acrescentei uma coisa que o veredito não pediu e que faltava: **por que `capacidade=ambiental` e não `dura`** nesses dois sítios, já que o alvo ausente é um script do próprio `.forge/scripts/`. O motivo está medido no comentário de `w168:122-125` — `core.hooksPath` é compartilhado entre worktrees e `.forge/scripts/` é conteúdo próprio de cada uma (issues #41, #73, #81) —, e sem ele a classificação pareceria contradizer a alínea de §1.2 sobre dependência dura.

### Novo 2 — a decisão nova de `run_check` quebra `w135[3]` e `w97[3]`

**Procede, e a observação central dele é a mais valiosa das quatro: a inversão `test OK` → `OK test` não era exigida por nada.** Remedi: `tests/w135-push-refs-export-gate.sh:149-150` exige `grep -q 'typecheck OK'` e `grep -q 'test OK'`; `tests/w97-hook-portability-gate.sh:44` exige `grep -q 'typecheck PULADO'`; os dois usam o hook de produção. Medi as três formas de linha contra as duas asserções e a conservada é a única que sobrevive:

```
pre-push: test OK — comando declarado executado        → 'test OK' SIM
pre-push: typecheck OK — comando declarado executado   → 'typecheck OK' SIM
pre-push: OK test — comando declarado executado        → 'test OK' NÃO · 'typecheck OK' NÃO
```

§3.3 conserva a ordem `<label> OK` e acrescenta um segundo argumento que o veredito não tinha: `pre-push:320` já imprime `pre-push: shell-lints OK — $_sh_n arquivo(s) .sh varrido(s)`, então `<label> OK — <detalhe>` é o precedente do próprio arquivo, e a invertida seria a única linha do `pre-push` com o token antes do rótulo. `[7]` de §3.4, asserção (3), foi reescrita sobre a ausência de `INCONCLUSIVO test` na execução que passa, como ele sugere, sem enfraquecer o par anti-tautológico.

**Onde fui além do veredito, e a medição que obriga.** Ele nomeia `w97:44`. Medindo o gate inteiro, `w97:50` é a asserção **negativa** do mesmo cenário (`grep -q 'typecheck PULADO' <<<"$out2" && FAIL`, com `node_modules` presente). Migrar só a positiva deixaria a negativa satisfeita por **vacuidade** — a string `PULADO` deixaria de existir no arquivo e o `grep` nunca casaria, em estado nenhum. Uma asserção negativa que ninguém pode falhar é o falso-verde desta onda dentro do gate que a onda edita. As duas migram, e a tabela de §7 diz isso em letra.

### Novo 3 — §3.6 e §3.4 `[3]` contraditórias, apagando o controle da terceira mutação

**Procede inteiro, e não aceitei por leitura: montei a bancada e medi os dois estados.** Um contador protótipo e o mesmo contador mutado para publicar o vetor decorado, sobre uma fixture com `package.json` e sem `.sln`/`.csproj`:

```
ÍNTEGRO: … dotnet=0 solution(s)/0 projeto(s), node=1 package.json, jvm=0, python=0, go=0
MUTADO : … dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0

asserção ANTIGA ("nenhuma linha sobre dotnet"):  íntegro REPROVA · mutado REPROVA
asserção NOVA:                                   íntegro PASSA   · mutado REPROVA
```

Confirmado: a antiga reprova nos dois estados, o que é a mutação-fantasma de `feedback-mutacao-fantasma-restore` invertida — sem controle e sem recontrole. `[3]` foi reescrito com as duas asserções que o veredito propõe, positiva e negativa, e a terceira mutação de §3.5 passou a citar a positiva pelo nome. Aproveitei para escrever a **matriz das três mutações**, com o efeito de cada uma sobre `[1]`, `[2]`, `[3]` e `[9]` medido na bancada, e ela revelou dois enganos meus que o veredito não pegou: a mutação 2 **não** faz a classe `dotnet` "deixar de ser detectada" (os 5 `.csproj` a mantêm; a linha continua sendo emitida, dizendo `dotnet=0 solution(s)/5 projeto(s)`), e `[2]` passa nas **três** mutações, ou seja, não é controle de nenhuma delas.

### Novo 4 — dois denominadores por escrever

**Procede nos dois, e a conta dele confere.** Remedi: `grep -nE 'echo "OK \[' tests/w120-ai-attribution-gate.sh` devolve **10** cenários hoje, `[1]`-`[10]`. A frase de §4.7 enumerava 13 e deixava `[12]` fora de qualquer constante; o obrigatório correto é **14**, com `[12]` dentro. §4.7 passou a trazer os dois números escritos (`SCEN_MIN=14`, `SCEN_AMB_NOMINAL=2`) e o modo de falha que a omissão abria — um implementador fechando a conta em 13 faria `[12]` não incrementar `SCEN`, e o cenário que impede a correção preguiçosa de `[11]` rodaria fora do denominador.

Em §3.6 **não** preenchi o `FIXTURES_NOMINAL`: removi-o. Ele não é derivável sem ambiguidade — `[1]`, `[2]`, `[4]`, `[5]` e `[6b]` compartilham árvore variando `FORGE.md` ou allowlist, `[8]` não monta repositório e `[9]` é o próprio contador —, e a saída certa é o denominador de **cenários**, que é fixo por construção do gate e cuja divergência é o achado. Entraram `SCEN_MIN=9` e `SCEN_AMB_NOMINAL=1`, pela mesma separação de §2.6 e §4.7, com o incremento de `[9]` acontecendo antes da aferição dito em letra para não deixar um off-by-one à interpretação.

---

### O que as quatro varreduras do mandato encontraram além do veredito

Seis defeitos meus, nenhum nomeado pelas duas revisões. Cada um com a medição que o sustenta.

**1. Um quinto gate rastreado quebrava, e ele estava a uma linha de distância.** `tests/w190-pre-push-gate-reader-gate.sh:238` exige `grep -q "BLOQUEADO"` sobre um push sem `node`. Se a linha de bloqueio por capacidade dura trocasse `BLOQUEADO` por `INCONCLUSIVO`, `w190[6b]` ficaria vermelho. §2.3 fechou a **composição** da linha (`pre-push BLOQUEADO: INCONCLUSIVO <chave> capacidade=dura — …`), coerente com as linhas 99, 118 e 139 do próprio `pre-push`, e o gate entrou na tabela de §7.

**2. `[6b]` do `w190` ficaria em `SKIP` para sempre, e o `SCEN_AMB` viraria ruído.** Medido em `w190:239-247`: o cenário só conta quando o bloqueio é o da guarda do leitor, e §4.5 desta spec já declara que, sem `node`, quem bloqueia primeiro continua sendo o `check-ai-attribution.sh`. `SCEN_AMB` seria 0 em toda execução, e o gate imprimiria a linha de ambiental numa máquina onde o `PATH` montou perfeitamente. §2.6 passou a mandar reescrever `[6b]` sobre o invariante que §4.5 já declara como o verdadeiro — a prosa de §4.5 e a contagem de §2.6 estavam desalinhadas desde a revisão 1.

**3. O `/forge:archive` aprovaria um change com verificação inconclusiva.** Medido: `template/.forge/scripts/lib/validate-archive.mjs:107` só bloqueia em `failed`. A onda produziria um `verification.yaml` honesto que o único portão que lê o artefato deixaria passar — o falso-verde da onda reintroduzido pela própria onda, um nível acima. §6 ganhou o **contrato 3**, com retrocompatibilidade medida (o valor não existia antes, nenhum artefato gravado muda de desfecho).

**4. `git ls-files` fora de repositório git sai 128, e o idioma natural do contador engole esse rc.** Medido: `n=$(git ls-files '*.sln' 2>/dev/null | wc -l)` devolve `n=0` com rc 0, porque o rc do pipeline é o do `wc`; a captura por substituição devolve 128 e é detectável. Sem tratamento, `check-test-surface.sh` publicaria "5 classes examinadas", tudo zero, e sairia 0. §3.6 fechou a decisão (captura por substituição, `INCONCLUSIVO … capacidade=dura`, rc 4, nenhuma classe publicada) e mediu o caso vizinho, que é diferente: num repositório **sem commit** o `ls-files` sai 0 e enumera o índice corretamente, então esse estado é legítimo.

**5. O vetor literal da fixture dependia do conteúdo de `template/.forge/`.** A fixture copia o template para dentro do repositório, e `git ls-files` conta o que estiver no índice. Hoje é inofensivo, medido (os oito globs de classe devolvem 0 dentro de `template/.forge/`), mas por acidente: um capability pack com `package.json` viraria vermelho fabricado num gate sem relação com ele. §3.6 passou a exigir `':!:.forge/**'`, medido com vários globs positivos, e a exclusão é a decisão certa em produção também — maquinaria do harness não é superfície de teste do projeto.

**6. Dois literais meus contavam a árvore, e um deles envelhecia dentro da própria onda.** `[7]` de §5.2 mandava escrever `arquivo:linha` no gate, e esta onda edita os cinco arquivos citados — `lib/forge-runtime.sh:87` deixa de estar na 87 no instante em que a Decisão 1 de §2.3 tira o `|| true`; o gate nasceria vermelho por causa da correção que ele protege. `[8]` fixava "os 11 gates medidos", o que deixaria o gate número 12 **fora** da guarda em silêncio. Corrigi os dois pela régua que o mandato prescreve: `[7]` ancora por conteúdo, `[8]` deriva o universo na execução com piso `GATES_NODE_MIN=11`, e `SITIOS_NOMINAL` — 20 à época, **22** hoje (§13) — continua legítimo porque conta o array declarado no próprio gate, não a árvore. A revisão 3 aplicou a mesma régua a `[9]`, que ainda embutia o número de casamentos e por isso nascia vermelho sobre a implementação certa.

**E um sétimo, de exaustividade.** `[3]` e `[4]` de §5.2 dependiam do scrub de `PATH`, o que fazia dois cenários do gate da classe serem ambientais sem constante que os separasse — o defeito que §2.6 e §4.7 corrigem nos outros dois gates, reintroduzido aqui. Não havia necessidade: o lib testa a presença de uma **capacidade nomeada**, e um nome que ninguém tem serve ao predicado sem tocar no ambiente. Medido com o lib protótipo — `rc=4` e `rc=5` com a linha completa, `rc=0` e stdout vazio no controle —, e o gate da classe fica com **zero** cenários ambientais. Na mesma varredura escrevi os desfechos que as enumerações não cobriam: os rc `126`, `127` e `128+N` em §1.3 e em `[6]` de §5.2, o argumento não numérico e o ausente, e o quarto estado do leitor em §2.3 (rc 0 com lista vazia na forma mapeada), que é fronteira **decidida** — a onda não o fecha, e diz por quê.

**Uma ambiguidade minha que a varredura de strings pegou e que teria quebrado três cenários.** A Decisão 1 de §4.4 dizia que "rc diferente de zero passa a significar, e só significar, a varredura abortou". Lida sobre o **script** em vez do `_scan_file`, ela mandaria devolver 0 em violação e quebraria `w120[14]`, `w144[5]` e `w144[6]`. §4.4 passou a separar em letra o rc do bloco node do rc do script, e a registrar que a Decisão 4 reaproveita a chave `ai-attribution` da allowlist exatamente para não invalidar a fixture de `w144[6]`.

**Uma restrição de implementação que nenhuma revisão viu.** `tests/w171-gate-phase-contract-gate.sh` compara a saída de `run-gates.sh` com três goldens versionados por `cmp` byte a byte. A fixture roda com o leitor **disponível**, então o `NO-GATES` dela é legítimo e precisa sair idêntico depois da mudança de `run-gates.sh:58`: qualquer diagnóstico impresso quando o rc do leitor é zero derruba `[0a]`, `[0b]` e `[0c]` de uma vez. §2.3 escreveu a restrição, §7 registrou que os três **não** mudam, e a DoD ganhou a linha de que um golden regravado nesta onda é, ele próprio, a prova de que a decisão vazou.

**Nenhuma medição do veredito da revisão 2 foi refutada.** Reproduzi as quatro — as duas linhas de `NÃO VERIFICADO` em `tests/`, as duas de `w135:149-150` e a de `w97:44`, a contradição entre §3.6 e `[3]` (medida em bancada, não lida), e os 10 cenários de hoje do `w120` que fazem o obrigatório ser 14 — e as quatro procedem como escritas. A única correção que faço ao veredito é de escopo, não de fato: o Novo 2 nomeia `w97:44` e são **duas** as asserções a migrar naquele cenário, porque a de `w97:50` passaria a valer por vacuidade.

---

## 13. Respostas ao veredito da revisão 3

Três bloqueadores novos. **Dois procedem e estão fechados; um eu refuto com medição, e mesmo assim mudei a decisão que ele ataca — pelo motivo verdadeiro, que é outro.** Antes de aceitar qualquer um, remedi a afirmação do revisor com comando meu; onde a medição dele não reproduz, a minha está colada abaixo e a posição anterior foi mantida na parte em que ela estava certa. As cinco ressalvas de redação foram todas tratadas, porque todas eram baratas e três delas se revelaram, na medição, prescrições **erradas** e não questões de estilo.

### A varredura de comandos prescritos — a mudança de método desta rodada

A invariante 19 do plano-mestre passou a valer, e ela é a causa da maioria dos defeitos que a revisão 3 encontrou nesta e nas outras specs da rodada. Apliquei-a ao documento inteiro, e não só aos bloqueadores.

**Critério de contagem.** Conto como *prescrição* um comando que a spec manda o implementador ou um gate executar. Não conto como prescrição uma *medição minha já citada com a saída* — essas são evidência datada, e a §11 e a §12 estão cheias delas. Pelo critério, esta spec prescrevia **24** comandos.

| Disposição | Quantos | Quais |
|---|---|---|
| **Executados nesta rodada, com a saída colada ao lado da prescrição** | **17** | `shasum -a 256 … \| awk` (§2.5); o laço de filtro de gates que invocam `node` (§4.4, Decisão 2, e `[8]` de §5.2); o predicado de `[9]`; `grep -rn '< <(forge_runtime_gates_phase'` (`[10]`); os dois greps de `[11]`; `check-secrets.sh path` (`[12]`); `declare -f <nome>` em bash 3.2 (`[1]`); `command -v <capacidade inexistente>` (`[3]`); os seis globs de classe (§3.2, §3.6); o pathspec `':!:.forge/**'` e a variante dupla (§3.6); a captura de rc de `git ls-files` por substituição contra o pipe, mais o caso do repositório sem commit (§3.6); `git show '15ce493^:…'` (§2.4, `[12]`); `grep -q 'test OK'` e `'typecheck OK'` contra as duas formas de linha (§3.3); `grep -q 'INCONCLUSIVO test…'` nas três âncoras (§3.4, `[7]`); a comparação de `VETOR_FIXTURE1` contra a linha de produção (§3.6); `grep -l 'exit 1' check-*.sh` e a contagem de `exit 2` por arquivo (§1.3); o regex de censo de invocação de `node` (§5) |
| **Convertidos em propriedade mais contrafactual**, com o primitivo devolvido a quem executa e a obrigação de provar a discriminação | **5** | a aplicação e a restauração da mutação (§2.5, passo 2 — a propriedade é *substituição integral do arquivo*, e o passo 3 prova que ela ocorreu); a propagação do rc do leitor em `forge_runtime_gates_phase` e no `awk` de `doctor.sh:427` (§2.3, Decisão 3 — a propriedade é *o rc observado é o do leitor sob qualquer combinação de opções de shell*); a comparação do vetor em `[9]` (§3.6 — a propriedade é *a comparação discrimina o vetor íntegro do mutado*, o primitivo pode ser igualdade de sufixo ou `grep -F`); o predicado do lib na forma de caminho, `[ -e ]` (§5.2, `[3b]`); a remoção de `lib/test-surface.mjs` em `[6a]` (§3.4) |
| **Mantidos com medição datada de revisão anterior**, marcados como tal no ponto de uso | **2** | o scrub de `$PATH` do `w190:205-218`, medido três vezes na revisão 1 com a saída colada em §2.6; a bancada do lib protótipo de `[2]`-`[4]`, medida na revisão 2 com as quatro linhas de saída coladas em §5.2 — reconfirmei nesta rodada apenas o predicado que a sustenta (`command -v` de nome inexistente devolve rc 1 com stdout vazio) |

**O que a varredura encontrou, e que nenhuma das três revisões nomeou: três prescrições que estavam simplesmente erradas.** Cada uma teria produzido, na mão do implementador, exatamente o defeito que esta onda combate.

1. **`[12]` de §5.2 prescrevia rc 1 e o gate devolve rc 0.** `check-secrets.sh path <arquivo com segredo plantado>` sai **0** com `WARN`, porque `check-secrets.sh:87` inicializa `enforce="warn"` e o comentário de `:84-86` declara que o default brando é deliberado para quem herda o gate. A saída literal das duas execuções está colada em §5.2. O cenário anti-tautológico da onda — o que impede a migração de desligar onze gates — teria nascido **vermelho permanente**, e um vermelho que nunca fica verde ensina o implementador a afrouxar a asserção. Corrigido: a fixture declara `enforce: block` no `.forge/forge.yaml`, e a alternativa de assertar `WARN` com rc 0 está descartada em letra, com o motivo.
2. **A asserção (3) de `[7]` em §3.4 reprovava a implementação certa.** `grep -q 'INCONCLUSIVO test'` casa `INCONCLUSIVO test-surface`, e as duas linhas podem sair no mesmo push. Medido nesta rodada nas três âncoras candidatas; a escolhida é `INCONCLUSIVO test capacidade=`, que é a mesma forma das asserções (1) e (2).
3. **`VETOR_FIXTURE1` não era comparável à linha que a spec manda a produção publicar.** `dotnet=2/5 node=1 jvm=0 python=0 go=0` contra `dotnet=2 solution(s)/5 projeto(s), node=1 package.json, jvm=0, python=0, go=0`: `grep -q` da constante sobre a linha **não casa**, executado. A constante passou a ser escrita na forma exata da linha, e a propriedade da comparação ficou declarada.

**E uma quarta, que a varredura achou por leitura cruzada em vez de por execução, e que eu registro com a mesma severidade.** `[1]` de §3.4 assertava "a saída contém `2 solution(s)`", enquanto §3.6 manda a produção publicar o vetor **sempre** — e o vetor da fixture de `[1]` contém `dotnet=2 solution(s)/5 projeto(s)`, medido e colado em §3.5. Sob a mutação 1 de §3.5, a linha `INCONCLUSIVO test-surface` some e o vetor permanece: a asserção agregada continuaria satisfeita, e a linha da matriz de mutação que declara "mutação 1 derruba `[1]`" seria **falsa**. É o padrão da invariante 16 chegando por um caminho que a invariante 16 não cobre — a matriz foi medida, mas a asserção que ela cita mudou de forma depois. Corrigido: `[1]` assere sobre **uma única linha** que contém os quatro tokens ao mesmo tempo.

### Novo 1 — `[9]` de §5.2 nasce vermelho sobre a implementação certa, por um sétimo sítio

**Procede inteiro, e eu remedi antes de aceitar.** Executado nesta rodada, `grep -nE 'command -v node|mktemp' template/.forge/scripts/check-*.sh | grep -E 'exit 2'` devolve **sete** linhas, não seis: as seis da tabela de §1.3 mais `check-suite-wiring.sh:39` — `TMP="$(mktemp -d /tmp/forge-wiring.XXXXXX)" || { echo "FAIL suite-wiring — mktemp falhou" >&2; exit 2; }`, o mesmo idioma com a mesma justificativa. Confirmei também por que ele não chegava pelos outros caminhos: `grep -n 'node' template/.forge/scripts/check-suite-wiring.sh` devolve **zero**, então o arquivo não está entre os 11 gates que invocam `node` e não entra por `[8]`.

O revisor oferece duas saídas e as duas eram legítimas; escolhi a primeira, e depois fui além dela. **Escolha:** §1.3 ganha a sétima linha com o rc 5 e a glosa da migração, §5.1 ganha o sítio **21** com parcela própria na aritmética (`+ 1 (mktemp em gate sem node)`), e `SITIOS_NOMINAL` vai a 22 — os 21 mais o sítio do Novo 2. **O que fiz além:** `[9]` deixou de embutir o número de casamentos e passou a **derivar o universo na execução**, com piso `LINHAS_CAPACIDADE_MIN=7`, no molde exato de `[8]`. **A revisão 4 derrubou esse piso, e com razão — §14:** o universo que eu escolhi ali era o subconjunto `exit 2`, que é justamente o que a onda zera, e o piso nascia vermelho permanente sobre a implementação certa. Hoje o universo de `[9]` é a **declaração de capacidade**, invariante à migração, e o piso é **12**. Trocar o 6 pelo 7 resolveria hoje e reabriria na próxima onda que acrescentar um `check-*.sh` — é a invariante 14, e o Novo 1 é precisamente uma instância dela que eu não tinha visto porque escrevi o predicado sem o rodar. Com universo derivado, um gate futuro que escreva `mktemp … || exit 2` entra na guarda no dia em que nasce.

Varri a invariante 15 sobre a string que o sétimo sítio passa a imprimir, executado: `grep -rn 'FAIL suite-wiring' tests/` e `grep -rn 'mktemp falhou' tests/` devolvem **zero**, e o único gate que exercita o arquivo, `tests/w146-suite-invocation-gate.sh`, afirma `rc -eq 0` e `rc -ne 0`, nunca um rc nominal. Nenhum gate rastreado entra na tabela de §7 por causa desta linha.

### Novo 2 — o rc do leitor em `run-gates.sh:58` e `spec-verify.sh:92`

**REFUTO a medição, com bancada própria, e mesmo assim mudo a decisão — porque a substância dele procede por um motivo diferente do que ele escreveu.**

O bloqueador afirma que "o rc 4 do leitor morre no pipe e o chamador captura 0", deixando o falso-verde vivo em três dos cinco sítios. O corpo da função é mesmo um pipe — `sed -n '93,96p' template/.forge/scripts/lib/forge-runtime.sh`, executado, devolve `forge_runtime_gate_entries "$root" | awk -F'\t' -v p="$phase" '$2==p{print $1}'`. Mas opções de shell em bash são **dinâmicas**: a função é carregada por `source` no shell do chamador e o pipe dela roda sob as opções daquele shell. Executado nesta rodada, `grep -n '^set ' <arquivo>` devolve `set -euo pipefail` na linha 29 de `run-gates.sh`, `set -euo pipefail` na linha 12 de `spec-verify.sh`, `set -u` na linha 19 de `doctor.sh` e `set -u` na linha 5 do `pre-push`.

Bancada em `$TMPDIR`, com o corpo **real** da função extraído por `sed` do arquivo de produção e um leitor que devolve 4, os dois chamadores reproduzidos pelas suas opções reais:

```
CHAMADOR-COM-pipefail (run-gates.sh/spec-verify.sh): rc=4 out=[]
CHAMADOR-SO-set-u (doctor.sh/pre-push):              rc=0 out=[]
```

Nos dois sítios que o bloqueador nomeia, a variável intermediária da Decisão 3 **observa** o rc 4. A bancada dele mediu um shell no default, que não é o de nenhum dos dois. No sítio que ele cita de passagem — `doctor.sh:427`, com `set -u` e pipe próprio com `|| true` — ele está certo, e aquele sítio já tinha decisão (item 20 de §5.1).

**Por que mudo a decisão assim mesmo, e por que a mudança é maior do que a que ele pediu.** Uma propriedade que vale só porque o chamador por acaso declarou `pipefail` é acoplamento invisível — o desfecho certo por um motivo que não está escrito em lugar nenhum, que é a forma que esta onda inteira combate. Um `set +o pipefail` local no dia em que alguém precisar de um, ou um chamador novo com `set -u` (e `doctor.sh` é exatamente esse), apaga a guarda sem tocar nela e sem nada acusar. §2.3, Decisão 3, passou a declarar a **propriedade** — *o rc que o chamador observa é o do leitor, sob qualquer combinação de `set -e`, `set -u` e `pipefail`* — e a **não prescrever o primitivo**: variável intermediária dentro da função, `PIPESTATUS`, `pipefail` local com restauração ou eliminação do pipe, a escolha é de quem executa, e a obrigação é provar a discriminação com o par de bancadas acima, o `set -u` puro incluído. `forge_runtime_gates_phase` entrou como sítio **22** de §5.1 e no passo 3 de §10.

E aceito a segunda metade do bloqueador sem reservas: **faltava cenário comportamental** para o modo *leitor presente e quebrado* contra `run-gates.sh` e `spec-verify.sh`. `[14]` e `[15]` usam a lib de `15ce493^`, e confirmei nesta rodada que ela cobre só o modo *função ausente* — 50 linhas, **0** ocorrências de `forge_runtime_gate_entries`, **0** de `forge_runtime_gates_phase`, **4** de `forge_get_runtime`. Nasceram `w190[14b]` e `[15b]` (§2.4), com `gate-phase.mjs` substituído por um arquivo que sai diferente de zero sobre a lib de hoje, e `SCEN_MIN` do `w190` foi de 18 para **20**. `[10]` de §5.2 ganhou, em letra, o parágrafo que diz o que ele **não** cobre e para onde a propriedade foi — porque um censo estático que tentasse ler opções de shell por `grep` seria a quarta reimplementação de uma leitura que só o interpretador faz certo.

### Novo 3 — `[2]` de §3.4 reprova a implementação certa, por contradição com §3.6

**Procede inteiro.** A fixture de `[1]` é fixada em §3.6 como 2 `.sln`, 5 `.csproj`, 1 `package.json`, e o vetor que `[9]` assere contém `node=1` — a classe `node` está presente, e isso é asserção, não prosa. A regra decidida em §3.3 é de **classe**, e um `test: dotnet test app.sln` deixa `node` sem cobertura: a implementação certa emite `INCONCLUSIVO test-surface` sobre `node`, e `[2]`, que assere ausência de qualquer linha dessas, reprovaria o código correto. É a forma do Novo 3 da revisão 2 na outra classe, e o revisor está certo em dizer que as duas saídas óbvias colidem — tirar o `package.json` quebra `VETOR_FIXTURE1` e as duas bancadas coladas em §3.5.

Adotei o caminho que ele propõe, que é o único que preserva tudo: `[2]` passa a declarar `test: dotnet test app.sln && pnpm test`, com as duas metades stubadas para sair 0. A fixture, o vetor de `[9]`, o pareamento com `[1]` e as três linhas da matriz de §3.5 que citam `[2]` ficam intactos — inclusive a leitura de que `[2]` passa nas três mutações, que continua verdadeira, porque nenhuma delas remove cobertura de uma classe que o comando de `[2]` alcança. O precedente está na própria tabela de §3.2: o `Axis.PadSimulator` declara `dotnet test … && pnpm --dir frontend test` exatamente por ter as duas classes.

### As ressalvas de redação, todas tratadas

- **§1.3 dizia "13 de 14" na tabela e "os 14 gates" três parágrafos abaixo.** Procede, e remedi: `ls template/.forge/scripts/check-*.sh | wc -l` devolve **14** e `grep -l 'exit 1' … | wc -l` devolve **14**, sem nenhum arquivo de fora. A tabela diz 14 de 14.
- **A asserção (3) de `[7]` casava `INCONCLUSIVO test-surface`.** Procede, e virou prescrição errada na medição, não ressalva de estilo — tratada acima e em §3.4.
- **`VETOR_FIXTURE1` não era literalmente igual à linha de produção.** Procede, e também virou prescrição errada — tratada acima e em §3.6.
- **O "sempre" de §3.6 é o inverso exato de `[6a]`.** Procede, e a ressalva ficou escrita ao lado do "sempre": o vetor é publicado sempre **que o gate conseguiu examinar**; quando não conseguiu, publica `INCONCLUSIVO` e nenhuma classe, que é o que `[6a]` assere e o que a decisão do `git ls-files` fora de repositório manda fazer.
- **§1.1 não escrevia as duas linhas novas por extenso.** Procede, e a tabela de §1.1 agora traz as duas na íntegra, com a de hoje ao lado, lidas do arquivo nesta rodada. O nome do script ausente fica dentro do corpo da linha — que é o que `w160[4]` exige e o que `forge_verdict_require` produz por construção.
- **A exclusão `':!:.forge/**'` não cobriria `template/.forge/**` nesta árvore.** Procede, e a decisão ficou dupla desde o primeiro commit. Medido: com exclusão simples o vetor desta árvore é `node=2` e o resto zero; com a dupla, o mesmo `node=2`, porque os globs de classe dentro de `template/.forge/` devolvem 0. Custa um pathspec e remove a dependência de um acidente.

### O que continua sem prova, dito em voz alta

Nenhum gate da suíte foi executado na produção desta revisão — a proibição da rodada vale e a razão dela é `feedback-suite-sem-concorrencia`. Tudo que afirmo sobre gates é leitura do fonte mais bancada extraída em `$TMPDIR`, com uma exceção que registro porque ela **é** execução de produção: rodei `template/.forge/scripts/check-secrets.sh` no modo `path` contra uma fixture minha em `$TMPDIR`, duas vezes, para medir a prescrição de `[12]` — é um script do template, não um `tests/*-gate.sh`, e a bancada é descartável. Também não exercitei código que ainda não existe (`lib/gate-verdict.sh`, `check-test-surface.sh`, `lib/test-surface.mjs`, os dois gates novos): sobre eles, o que esta spec entrega é propriedade, contrafactual e a obrigação de o implementador provar a discriminação — que é exatamente a divisão de trabalho que a invariante 19 prescreve.

---

## 14. Respostas ao veredito da revisão 4

Um bloqueador novo, e ele **procede inteiro**. Remedi as duas leituras que o revisor mediu antes de aceitar, e as duas reproduzem: `grep -nE 'command -v node|mktemp' template/.forge/scripts/check-*.sh` devolve **15** linhas em **11** arquivos, e o mesmo predicado com `| grep -E 'exit 2'` devolve as **7** que §1.3 tabela. As três linhas que a leitura B arrastaria são as que ele nomeia, verificadas uma a uma: `check-ai-attribution.sh:54`, `check-push-ahead.sh:228` e `check-push-ahead.sh:201`, esta última um comentário. Não refuto nada nesta rodada — refuto apenas **metade da saída prescrita**, e digo abaixo por que, com medição.

### Novo 1 — `[9]` reprovava a implementação certa nas duas leituras, e o piso 7 não correspondia a nenhuma

**Procede inteiro.** O parágrafo definia a seleção sem o filtro de `exit 2` e o "Como falha hoje" a definia com ele: dois universos, e o piso copiado de `[8]`, onde o universo sobrevive à onda, para `[9]`, onde o universo **é o idioma que a onda apaga**. Na leitura A a seleção vai a zero depois da onda e o gate fica vermelho permanente; na leitura B o piso não é o valor medido (15, não 7) e a metade positiva reprova três sítios que a onda não governa. É o mesmo padrão que derrubou as rodadas 2, 3 e agora a 4: eu consertei o número e não varri o resto do parágrafo atrás do efeito colateral.

**O que fiz.** Adotei a segunda das duas saídas que o veredito oferece — *o predicado de idioma restrito às formas com tratamento de erro* — e recusei a primeira (*a lista das linhas de §1.3, ancorada por conteúdo*) pelo motivo escrito em `[9]`: uma lista ancorada deixa fora, em silêncio, o `check-*.sh` que nascer amanhã escrevendo `mktemp … || exit 2`, que é a forma exata de "aprovar sem ter olhado" que esta onda existe para fechar.

O universo de `[9]` passa a ser **a linha que declara uma capacidade com tratamento de erro**: nomeia um primitivo de capacidade (`command -v <binário>`, `mktemp`) ou invoca o lib de §1.4, não é comentário, e abre ramo de erro. Medido nos dois estados — árvore de produção e bancada em `$TMPDIR` com a migração dos passos 1 e 6 de §10 aplicada aos nove arquivos:

```
HOJE   : linhas=12 arquivos=9  exit2=7 exit1=5 pelo_lib=0
DEPOIS : linhas=15 arquivos=12 exit2=0 exit1=0 pelo_lib=15
```

Os três sítios que a leitura B arrastaria ficam **fora** por construção, e a exclusão está escrita com o motivo: `_tmpfile()` e o `OUT="$(mktemp …)"` não abrem ramo de erro — não declaram capacidade, apenas não tratam a falha, que é outro defeito e de outra onda —, e o comentário cai no filtro de comentário.

**Onde eu refuto meio bloqueador: o piso fica, medido sobre outro universo.** O veredito manda "trocar o piso por essa propriedade". Troquei o **universo** e mantive o piso, e a medição é a razão: o universo novo é invariante à onda — ele **cresce** de 12 para 15, porque os três gates sem pré-voo (itens 6-8 de §5.1) ganham a declaração que hoje não têm —, então o piso 12 não é vermelho fabricado, e ele protege a única direção que a propriedade não protege sozinha: a seleção degenerar para zero por glob errado e P1 passar por vacuidade sobre conjunto vazio. Um `[9]` só com a propriedade de vacuidade seria, contra uma seleção quebrada, verde por não ter olhado — que é o nome desta onda. A régua "piso só sobre universo que a própria onda não esvazia" ficou escrita nas duas seções que a governam: no parágrafo das quatro constantes de §5.2 e na tabela de vocabulário de §4.4.

**O contrafactual está na direção certa agora.** P1 diz que nenhuma linha do universo termina em `exit 2` nem em `exit 1`; hoje **12 de 12** violam e depois da onda **0 de 12**. O gate reprova quando **qualquer** linha de capacidade voltar a terminar assim, inclusive num `check-*.sh` que ainda não existe. P2 diz que cada linha do universo declara o veredito pelo lib e nomeia a natureza pelo primitivo; hoje **0 de 12**, depois **15 de 15**. O rc 4 e o rc 5 continuam sendo asseridos **comportamentalmente** por `[3]`, `[3b]` e `[4]`, nunca por `grep`.

### As três ressalvas de redação, respondidas

- **`[3b]` é cenário numerado e conta.** Ele exercita outro predicado — `[ -e ]` sobre caminho, contra `command -v` sobre nome —, e é o predicado de que `check-ai-attribution.sh` e os itens 6-8 de §5.1 precisam; deixá-lo só dentro do bloco de bancada era, na convenção desta spec (`[6a]`, `[12c]`, `[14b]`, `[15b]` todos contam), um implementador fechando 14 contra 13. Virou parágrafo próprio depois de `[4]`, `CENARIOS_NOMINAL` foi a **14**, e a mutação 1 de §5.2 passou a nomeá-lo junto de `[3]` e `[4]`, porque a mutação declarada (`forge_verdict_require` devolve 0 sempre, sem imprimir) derruba os três.
- **O sítio 22 ganhou entrada de array e asserção escritas.** Cada entrada carrega `arquivo`, `padrão de ancoragem` e `cenário dono da asserção substantiva`; a do item 22 é `lib/forge-runtime.sh` com âncora `forge_runtime_gates_phase`, e o laço afirma **exatamente uma coisa sobre ela: que a âncora resolve**. A asserção substantiva é de `w190[14b]`/`[15b]`, pelo canal real, pelo motivo que `[10]` já escreve. "Examinado", no vocabulário de `[13]`, ficou definido em letra — a âncora resolveu e o cenário dono rodou —, que é o que impede fechar 21 contra 22 ou inventar a asserção.
- **`[7]` fala em "para cada linha casada".** Corrigido, com a medição do revisor citada: a âncora por conteúdo casa mais de uma linha em três dos cinco sítios.
- **A cauda das duas linhas de §1.1 é do `pre-push`, não de um quinto argumento.** Os dois sítios chamam `forge_verdict_say <chave> inconclusive:ambiental "<mensagem>"`, e a mensagem carrega tudo o que vem depois do travessão, cauda inclusive. `forge_verdict_require` continua com quatro argumentos e a sua linha continua terminando no `(<como-obter>)`. §1.4 ganhou o formato de saída de `forge_verdict_say` no bloco de assinaturas, porque ele estava implícito e implícito não é decisão fechada.

### A conferência final das cinco linhas, com o resultado de cada uma

1. **Toda seção que menciona a peça mudada foi atualizada.** Grepei `LINHAS_CAPACIDADE`, `[9]`, `[3b]`, `CENARIOS_NOMINAL` e `forge_verdict_` e li cada ocorrência. Mudaram: `[9]` de §5.2 (reescrito), a tabela de vocabulário de §4.4, o bloco das quatro constantes e o parágrafo que as tipifica, três linhas da DoD de §10, o passo 1 de §10, a contagem de ordinais de §8, o parágrafo histórico de §11 e o do Novo 1 em §13, que ganhou o ponteiro para cá com o piso antigo marcado como derrubado. O `[9]` de §3.4/§3.6 é de **outro** gate (o de superfície de teste) e não foi tocado — conferido linha a linha.
2. **Todo contador recomputado.** `SITIOS_NOMINAL=22` (aritmética de §5.1 intacta: 5+3+8+4+1+1). `CENARIOS_NOMINAL` **13 → 14** e propagado aos cinco lugares que o citam. `LINHAS_CAPACIDADE_MIN` **7 → 12**, com os dois estados medidos. `GATES_NODE_MIN=11` intacto. `SCEN_MIN` de 20, 9 e 14 intactos — nenhuma mudança desta rodada toca `w190`, o gate de superfície ou o `w120`. As oito provas de mutação continuam oito. A conta de prescrições de §13 continua 17+5+2=24, e o predicado de `[9]` está agora nas duas primeiras colunas, o que a cláusula "uma de duas" da DoD admite e que ficou dito em letra.
3. **As enumerações exaustivas continuam exaustivas.** O bloco de funções de §1.4 dizia "quatro funções e nada mais" e listava **cinco** — contradição com `[1]`, que sempre disse cinco; corrigido para cinco. A enumeração de desfechos de `[6]` (0..5, 127, não numérico, argumento ausente) não foi tocada. A enumeração nova de `[9]` — o que fica de fora do universo — é exaustiva por construção: 15 menos 12 são exatamente os três sítios que o revisor nomeou, e os três estão escritos com o motivo.
4. **A matriz de mutação aponta para cenário que existe, com o efeito medido.** Mutação 1 de §5.2 passou a nomear `[3]`, `[3b]` e `[4]`; conferi que a mutação declarada derruba os três, porque os três chamam `forge_verdict_require` e o mutante devolve 0 em silêncio. Mutação 2 continua sobre `[13]` e o array de 22. As três linhas da matriz de §3.5 citam `[1]`, `[2]`, `[3]` e o `[9]` do gate de superfície — nenhuma delas foi tocada.
5. **Todo literal que conta a árvore é piso mais propriedade.** São dois, e só dois: `GATES_NODE_MIN=11` e `LINHAS_CAPACIDADE_MIN=12`, ambos sobre universo derivado na execução e ambos sobre universo que a onda **não** esvazia — foi essa segunda metade da régua que faltava e que o Novo 1 mediu. `SITIOS_NOMINAL` e `CENARIOS_NOMINAL` contam o que o próprio gate declara e seguem igualdades. Os números novos do texto de `[9]` (12, 9, 15, 12) são medição datada de 2026-09-07 com o comando ao lado, não asserção de gate.

**E uma sexta conferência, que eu fiz porque P1 é mais larga do que a que o veredito pediu.** P1 proíbe `exit 1` além de `exit 2` nas linhas de capacidade, e §1.3 afirma que os **14** `check-*.sh` usam `exit 1` para violação. Medi antes de escrever: cada um dos nove arquivos do universo tem pelo menos um `exit 1` que não é de capacidade, e na bancada migrada `grep -l 'exit 1' ./check-*.sh | wc -l` devolve **14** contra 14 arquivos. A linha "14 de 14" de §1.3 sobrevive à onda — que é exatamente o tipo de efeito colateral que derrubou as rodadas anteriores, e desta vez ele foi medido antes e não depois.

