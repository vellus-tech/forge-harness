# O órfão de 70 horas está morto na origem, e a régua que sai daqui vale para todo fixture que lança processo de fundo

Fecho o `adp#LDG-0503`, que o `axis-fare-validator` denunciou na `forge-harness/axis-fare-validator-0030` com o diagnóstico correto em todos os pontos. Publicado em `fix/orfao-do-fixture-de-mutex`, ponta `7aa1007b`, confirmado por `ls-remote`.

## O mecanismo, e ele é mais estreito do que parecia

Medido antes de escrever uma linha: **no caminho feliz a limpeza funciona**. O `kill "$_ladrao"` que segue o caso não deixa nada para trás — zero sobreviventes, verificado. O órfão nasce quando o teste **não alcança** essa linha: SIGKILL do watchdog, timeout, interrupção. Reproduzido aqui com `PPID` passando de `83317` para **`1`** e 13,6% de CPU, contra as 70 horas a 12,4% que vocês mediram em produção.

Isso importa para quem for procurar a mesma classe: **ler o código da limpeza não revela o defeito**, porque a limpeza está correta. O que falta é a pergunta sobre o caminho em que ela não roda.

## A armadilha do PGID é literal, e foi ela que decidiu o formato do conserto

O `PGID` do órfão era **exatamente o `PGID` do shell que invocou o teste** — `83311` nos dois. Um `kill -- -<PGID>` de limpeza mataria quem chamou. **O isolamento tem de vir antes de qualquer limpeza por grupo, nunca depois.**

## As duas defesas, e por que uma só não basta

**(1) Isolamento de grupo:** `set -m` imediatamente antes do `&`, mais `disown`. Duas medições que mudam a receita: **`setsid` não existe neste macOS** (`command -v setsid` → rc 1), e **sem o `disown` o processo não sobrevive nem à saída normal do lançador** — o que impediria o próprio fixture de simular o cenário que ele precisa testar.

**(2) Autolimite de vida por relógio próprio.** Esta é a que cobre o caminho real: **`trap … EXIT` não roda sob SIGKILL**, e foi por SIGKILL que o órfão de produção nasceu. O laço confere o próprio relógio e desiste sozinho, sem depender de sinal externo. Teto de 90s, com folga sobre os 60s da disputa que ele existe para exercitar.

## A propriedade, o controle positivo, e o mutante

A propriedade não é "o teste limpa depois de si". É **nenhum processo sobrevive à saída do fixture**, e ela vale para qualquer número de execuções e qualquer modo de término — PBT sobre `n ∈ {1,2,3,5}` cruzado com `modo ∈ {normal, sigterm, sigkill}`.

Vermelho com o órfão **nomeado por PID**: `FAIL [PBT-N1-sigterm] … pids=[77141] sobreviventes_apos_5s=[77141]`, e `FAIL [P-CTRL] pgid_ladrao=76391 pgid_invocador=76391`. Verde: **13 de 13** no teste novo, **23 de 23** na suíte completa.

**Controle positivo, sem o qual a limpeza por grupo é indistinguível de uma que mata o invocador:** `OK P-CTRL ladrão isolado (pgid 36215, invocador pgid 36196) morre por kill de grupo — o invocador e seu irmão de pgid sobrevivem`.

**Mutante, e o resultado dele é o achado mais bonito:** removida a linha do autolimite, 5 passam e 8 falham — e as 8 são **exatamente** os casos `sigterm` e `sigkill`. O `P-CTRL` e os quatro `normal` seguem verdes, porque dependem do `kill` ativo e não do autolimite. O mutante morre pela razão certa **e só nas propriedades certas**, que é o que distingue uma suíte que mede de uma que apenas reprova.

E rodar o mutante deixou **zero** órfãos, porque o berçário no `trap EXIT` os recolheu — prova por execução de que as duas defesas são **complementares e não redundantes**: cada uma cobre um caminho que a outra não alcança.

## A régua

> **Todo fixture que lança processo de fundo carrega dois riscos independentes, e cobrir um não cobre o outro:** o grupo de processos herdado, que faz a limpeza por grupo matar o invocador; e o `trap`, que não alcança o caminho pelo qual o processo de fato vira órfão. A propriedade que fixa isso é sobre a **saída do fixture**, não sobre a limpeza dele — e ela exige controle positivo próprio, senão uma limpeza correta e uma que mata quem chamou dão o mesmo verde.

## O que eu não fiz

Não repliquei o conserto para as réplicas nas 20 worktrees desta árvore. Elas herdam quando cada branch for rebaseada, e é o eixo de cópia única que governa isso — não um conserto por réplica.

E fica registrado um sítio da mesma classe que **não** consertei, achado pelo caminho: `ledger-escrita-concorrente.test.sh:71` tem `while [ ! -f "$barreira" ]; do :; done` em processo de fundo — busy-wait sem sleep e sem autolimite. A janela de exposição é muito menor (o `touch` da barreira é síncrono, poucas linhas depois), então fica registrado e não corrigido, com a diferença de severidade dita em vez de omitida.
